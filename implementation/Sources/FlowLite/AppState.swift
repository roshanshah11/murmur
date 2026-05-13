import Foundation

public enum FlowLiteState: Equatable {
    case idle
    case recording
    case transcribing
    case pasting
    case error(String)

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording…"
        case .transcribing: return "Transcribing…"
        case .pasting: return "Pasting…"
        case .error(let message): return "Error — \(message)"
        }
    }

    var shortTitle: String {
        switch self {
        case .idle: return "FlowLite"
        case .recording: return "● FlowLite"
        case .transcribing: return "… FlowLite"
        case .pasting: return "↪ FlowLite"
        case .error: return "! FlowLite"
        }
    }
}

final class AppState {
    let config: Config
    let recorder: AudioRecorder
    let whisper: WhisperRunner
    let cleaner: TextCleaner
    let inserter: PasteboardInserter
    let history: HistoryStore

    private let onStateChange: (FlowLiteState) -> Void
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

    private(set) var state: FlowLiteState = .idle {
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
        onStateChange: @escaping (FlowLiteState) -> Void
    ) {
        self.config = config
        self.recorder = recorder
        self.whisper = whisper
        self.cleaner = cleaner
        self.inserter = inserter
        self.history = history
        self.onStateChange = onStateChange
    }

    func toggleDictation() {
        switch state {
        case .idle, .error:
            startDictation()
        case .recording:
            stopAndProcessDictation()
        case .transcribing, .pasting:
            Log.event(state: "toggle_ignored_busy")
        }
    }

    func startDictation() {
        guard state != .recording else { return }
        cancelErrorClear()
        do {
            recordingContext = AppContext.capture()
            let audioURL = try recorder.startRecording()
            currentAudioURL = audioURL
            recordingStartedAt = Date()
            state = .recording
        } catch {
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
                let totalMs = Int(Date().timeIntervalSince(pipelineStart) * 1000)
                self.history.append(
                    cleaned: cleaned,
                    raw: rawTranscript,
                    target: context,
                    durationMs: totalMs,
                    result: resultLabel
                )
                self.cleanup(audioURL: audioURL)
                self.state = .idle
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.cleanup(audioURL: audioURL)
                self?.setError(error)
            }
        }
    }

    func cancelIfNeeded() {
        if state == .recording {
            _ = try? recorder.stopRecording()
        }
        if let currentAudioURL, !config.debugRetainAudio {
            try? FileManager.default.removeItem(at: currentAudioURL)
        }
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
