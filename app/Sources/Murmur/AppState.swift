import Foundation

public enum MurmurState: Equatable {
    case idle
    case recording
    case transcribing
    case pasting
    case downloadingModel(progress: Double)
    case error(String)

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording…"
        case .transcribing: return "Transcribing…"
        case .pasting: return "Pasting…"
        case .downloadingModel(let progress):
            return "Downloading model — \(Int((progress * 100).rounded()))%"
        case .error(let message): return "Error — \(message)"
        }
    }

    var shortTitle: String {
        switch self {
        case .idle: return "Murmur"
        case .recording: return "● Murmur"
        case .transcribing: return "… Murmur"
        case .pasting: return "↪ Murmur"
        case .downloadingModel(let progress):
            return "⤓ Murmur \(Int((progress * 100).rounded()))%"
        case .error: return "! Murmur"
        }
    }
}

final class AppState {
    /// `var` (not `let`) so live toggles in Settings → General (e.g. the
    /// history opt-in) take effect on the *next* dictation without a full
    /// app restart. main.swift listens for `.murmurHistoryToggleChanged` and
    /// updates `config.historyEnabled` in place. Without this, the gate
    /// would read a captured-at-launch value and continue recording history
    /// after the user toggled it off — a privacy regression.
    var config: Config
    let recorder: AudioRecorder
    let whisper: WhisperRunner
    let cleaner: TextCleaner
    let inserter: PasteboardInserter
    let history: HistoryStore
    let volume: VolumeController

    private let onStateChange: (MurmurState) -> Void
    /// Fired on the main thread immediately after a paste completes,
    /// with the actual `PasteResult`. Lets the UI show a contextual
    /// success message ("Pasted into TextEdit") instead of a generic
    /// one driven by the state machine.
    var onPasteResult: ((PasteResult) -> Void)?
    private let queue = DispatchQueue(label: "flowlite.pipeline", qos: .userInitiated)
    private var currentAudioURL: URL?
    private var recordingStartedAt: Date?
    private var transcribingStartedAt: Date?

    var recordingElapsedSeconds: TimeInterval? {
        recordingStartedAt.map { Date().timeIntervalSince($0) }
    }

    var transcribingElapsedSeconds: TimeInterval? {
        transcribingStartedAt.map { Date().timeIntervalSince($0) }
    }
    private var recordingContext: AppContext?
    private var errorClearWorkItem: DispatchWorkItem?

    private(set) var state: MurmurState = .idle {
        didSet {
            Log.event(state: "state_transition", fields: [
                "from": String(describing: oldValue),
                "to": String(describing: state)
            ])
            onStateChange(state)
        }
    }

    init(
        config: Config,
        recorder: AudioRecorder,
        whisper: WhisperRunner,
        cleaner: TextCleaner,
        inserter: PasteboardInserter,
        history: HistoryStore,
        volume: VolumeController,
        onStateChange: @escaping (MurmurState) -> Void
    ) {
        self.config = config
        self.recorder = recorder
        self.whisper = whisper
        self.cleaner = cleaner
        self.inserter = inserter
        self.history = history
        self.volume = volume
        self.onStateChange = onStateChange
    }

    func toggleDictation() {
        switch state {
        case .idle, .error:
            startDictation()
        case .recording:
            stopAndProcessDictation()
        case .transcribing, .pasting, .downloadingModel:
            Log.event(state: "toggle_ignored_busy")
        }
    }

    // MARK: - Model download bridge

    /// Called by the Models settings tab while a download is in flight.
    /// Drives the notch overlay's `.downloadingModel` UI through the same
    /// `onStateChange` callback as every other state transition.
    func setDownloadingModel(progress: Double) {
        // Don't clobber an active dictation pipeline.
        switch state {
        case .recording, .transcribing, .pasting:
            return
        default:
            break
        }
        state = .downloadingModel(progress: max(0, min(1, progress)))
    }

    /// Clears the `.downloadingModel` state if the manager is currently
    /// showing one. No-op otherwise so we don't trample dictation state.
    func clearDownloadingModel() {
        if case .downloadingModel = state {
            state = .idle
        }
    }

    func startDictation() {
        guard state != .recording else { return }
        cancelErrorClear()
        do {
            recordingContext = AppContext.capture()
            volume.captureAndMute()
            let audioURL = try recorder.startRecording()
            currentAudioURL = audioURL
            recordingStartedAt = Date()
            state = .recording
        } catch {
            volume.restore()
            setError(error)
        }
    }

    func stopAndProcessDictation() {
        guard state == .recording else { return }

        do {
            let audioURL = try recorder.stopRecording()
            currentAudioURL = audioURL
            transcribingStartedAt = Date()
            state = .transcribing

            let context = recordingContext ?? AppContext.capture()
            let recordedMs = recordingStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            Log.event(state: "pipeline_started", fields: [
                "frontmost_app": context.name,
                "frontmost_bundle": context.bundleID,
                "recorded_ms": String(recordedMs)
            ])

            queue.async { [weak self] in
                self?.runPipeline(audioURL: audioURL, context: context)
            }
        } catch {
            setError(error)
        }
    }

    private func runPipeline(audioURL: URL, context: AppContext) {
        let pipelineStart = Date()
        do {
            let rawTranscript = try whisper.transcribe(audioURL: audioURL)
            let cleaned = cleaner.clean(rawTranscript)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.state = .pasting
                let result = self.inserter.paste(cleaned)
                let resultLabel: String
                switch result {
                case .pasted(let target):
                    resultLabel = "pasted:" + target.bundleID
                    Notifier.success("Pasted into \(target.name)")
                case .copiedOnly(let reason):
                    resultLabel = "copied_only"
                    Notifier.warn("Copied to clipboard — \(reason)")
                }
                self.onPasteResult?(result)
                let totalMs = Int(Date().timeIntervalSince(pipelineStart) * 1000)
                // Phase 5: history is opt-in. The HistoryStore itself also
                // honors `enabled` (defense in depth), but the AppState gate
                // here is the source of truth at the call site.
                self.appendHistoryIfEnabled(
                    cleaned: cleaned,
                    raw: rawTranscript,
                    target: context,
                    durationMs: totalMs,
                    result: resultLabel
                )
                self.cleanup(audioURL: audioURL)
                self.volume.restore()
                self.state = .idle
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.cleanup(audioURL: audioURL)
                self?.volume.restore()
                self?.setError(error)
            }
        }
    }

    /// Single decision point for whether a successful dictation result is
    /// appended to history. Centralized so HistoryGateTests can exercise the
    /// gate without standing up the full whisper + paste pipeline.
    func appendHistoryIfEnabled(
        cleaned: String,
        raw: String,
        target: AppContext,
        durationMs: Int,
        result: String
    ) {
        guard config.historyEnabled else { return }
        history.append(
            cleaned: cleaned,
            raw: raw,
            target: target,
            durationMs: durationMs,
            result: result
        )
    }

    func cancelIfNeeded() {
        if state == .recording {
            _ = try? recorder.stopRecording()
        }
        if let currentAudioURL, !config.debugRetainAudio {
            try? FileManager.default.removeItem(at: currentAudioURL)
        }
        volume.restore()
        cancelErrorClear()
        state = .idle
    }

    private func cleanup(audioURL: URL) {
        recordingStartedAt = nil
        transcribingStartedAt = nil
        guard config.deleteTempAudio && !config.debugRetainAudio else { return }
        try? FileManager.default.removeItem(at: audioURL)
    }

    private func setError(_ error: Error) {
        let short = shortErrorMessage(error)
        Log.error(String(describing: error), fields: ["short": short])
        state = .error(short)
        scheduleErrorClear()
        Notifier.warn(short)
    }

    private func shortErrorMessage(_ error: Error) -> String {
        if let w = error as? WhisperRunnerError { return w.shortMessage }
        if let a = error as? AudioRecorderError {
            switch a {
            case .microphonePermissionDenied: return "Mic permission denied"
            case .failedToCreateRecorder: return "Recorder failed"
            case .recorderNotRunning: return "Recorder not running"
            case .outputFileMissing: return "Audio file missing"
            case .wavConversionFailed: return "WAV conversion failed"
            }
        }
        return String(describing: error).split(separator: ".").first.map(String.init) ?? "Error"
    }

    private func scheduleErrorClear() {
        cancelErrorClear()
        let seconds = max(1, config.errorAutoClearSeconds)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .error = self.state {
                self.state = .idle
            }
        }
        errorClearWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: work)
    }

    private func cancelErrorClear() {
        errorClearWorkItem?.cancel()
        errorClearWorkItem = nil
    }
}
