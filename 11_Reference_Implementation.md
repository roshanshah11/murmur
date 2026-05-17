# Embedded Reference Implementation

This file embeds the starter implementation files directly so the implementation can be reviewed without following GitHub links.


## `app/README.md`

```markdown
# FlowLite Starter Implementation

This is a starter Swift macOS implementation for the PRD bundle. It is intentionally small and local-first.

## What this implementation does

- Creates a macOS menubar utility.
- Records microphone audio to a temporary WAV file.
- Runs a local `whisper.cpp` CLI binary to transcribe the WAV.
- Applies conservative local text cleanup.
- Copies the final text to the clipboard.
- Simulates `Cmd+V` to paste into the active app.

## What this implementation does not do yet

- It does not bundle `whisper.cpp`.
- It does not include a polished `.app` packaging flow.
- It does not implement full Accessibility-tree context reading.
- It does not stream partial transcripts.
- It does not use a cloud LLM.
- It does not store dictation history.

## Setup

1. Build or install `whisper.cpp` locally.
2. Download a GGML model file.
3. Copy `Resources/config.example.json` to `~/.flow-lite/config.json`.
4. Edit paths in the config.
5. Build and run:

```bash
swift build
swift run FlowLite
```

## First smoke test

1. Launch the app with `swift run FlowLite`.
2. Open TextEdit.
3. Put your cursor in a blank document.
4. Press F6.
5. Speak: `testing one two three`.
6. Press F6 again.
7. The cleaned transcript should paste into TextEdit.

## Important permissions

macOS may require:

- Microphone permission for recording.
- Accessibility/Input Monitoring permission for global shortcut/paste behavior.

## File notes

- `AudioRecorder.swift`: captures audio.
- `WhisperRunner.swift`: calls local transcription binary.
- `TextCleaner.swift`: conservative local cleanup.
- `PasteboardInserter.swift`: clipboard plus simulated paste.
- `HotkeyMonitor.swift`: F6 toggle.
- `AppState.swift`: pipeline coordinator.
```


## `app/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowLite",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowLite", targets: ["FlowLite"])
    ],
    targets: [
        .executableTarget(
            name: "FlowLite",
            path: "Sources/FlowLite"
        ),
        .testTarget(
            name: "FlowLiteTests",
            dependencies: ["FlowLite"],
            path: "Tests/FlowLiteTests"
        )
    ]
)
```


## `app/Sources/FlowLite/main.swift`

```swift
import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var appState: AppState!
    private var hotkeyMonitor: HotkeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let config = Config.loadOrCreateDefault()
        let recorder = AudioRecorder()
        let whisper = WhisperRunner(config: config)
        let cleaner = TextCleaner(config: config)
        let inserter = PasteboardInserter(config: config)

        appState = AppState(
            config: config,
            recorder: recorder,
            whisper: whisper,
            cleaner: cleaner,
            inserter: inserter,
            onStateChange: { [weak self] _ in
                DispatchQueue.main.async { self?.rebuildMenu() }
            }
        )

        setupStatusItem()
        rebuildMenu()

        hotkeyMonitor = HotkeyMonitor { [weak self] in
            self?.appState.toggleDictation()
        }
        hotkeyMonitor?.start()

        AudioRecorder.requestMicrophoneAccessIfNeeded()
        print("FlowLite launched. Press F6 to start/stop dictation.")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "FlowLite"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let stateTitle = "Flow Lite: \(appState.state.displayName)"
        let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())

        let toggleTitle = appState.state == .recording ? "Stop Dictation" : "Start Dictation"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleDictation), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let rawItem = NSMenuItem(title: "Raw Transcript Mode: \(appState.config.rawTranscriptMode ? "On" : "Off")", action: nil, keyEquivalent: "")
        rawItem.isEnabled = false
        menu.addItem(rawItem)

        let debugItem = NSMenuItem(title: "Debug Retain Audio: \(appState.config.debugRetainAudio ? "On" : "Off")", action: nil, keyEquivalent: "")
        debugItem.isEnabled = false
        menu.addItem(debugItem)

        menu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "Test Whisper Setup", action: #selector(testWhisperSetup), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let configItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)

        let logsItem = NSMenuItem(title: "Open Logs Folder", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = appState.state.shortTitle
    }

    @objc private func toggleDictation() {
        appState.toggleDictation()
    }

    @objc private func testWhisperSetup() {
        do {
            try appState.whisper.validateSetup()
            notify("FlowLite", "Whisper setup looks valid.")
        } catch {
            notify("FlowLite setup error", String(describing: error))
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(Config.defaultConfigURL())
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(Config.logsDirectoryURL())
    }

    @objc private func quit() {
        appState.cancelIfNeeded()
        NSApp.terminate(nil)
    }

    private func notify(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```


## `app/Sources/FlowLite/Config.swift`

```swift
import Foundation

struct Config: Codable {
    var whisperBinaryPath: String
    var modelPath: String
    var language: String
    var rawTranscriptMode: Bool
    var restoreClipboardAfterPaste: Bool
    var clipboardRestoreDelayMs: Int
    var deleteTempAudio: Bool
    var debugRetainAudio: Bool
    var transcriptionTimeoutSeconds: Int
    var customVocabulary: [String: String]

    static func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flow-lite", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    static func baseDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flow-lite", isDirectory: true)
    }

    static func logsDirectoryURL() -> URL {
        baseDirectoryURL().appendingPathComponent("logs", isDirectory: true)
    }

    static func tempDirectoryURL() -> URL {
        baseDirectoryURL().appendingPathComponent("temp", isDirectory: true)
    }

    static func defaultConfig() -> Config {
        Config(
            whisperBinaryPath: "/Users/roshan/dev/whisper.cpp/build/bin/whisper-cli",
            modelPath: "/Users/roshan/models/ggml-base.en.bin",
            language: "en",
            rawTranscriptMode: false,
            restoreClipboardAfterPaste: false,
            clipboardRestoreDelayMs: 1500,
            deleteTempAudio: true,
            debugRetainAudio: false,
            transcriptionTimeoutSeconds: 60,
            customVocabulary: [
                "cofounders capital": "Cofounders Capital",
                "caju dot ai": "Caju.ai",
                "caju ai": "Caju.ai",
                "element four fifty one": "Element451",
                "kenan flagler": "Kenan-Flagler",
                "pmt": "PMT"
            ]
        )
    }

    static func loadOrCreateDefault() -> Config {
        let fm = FileManager.default
        let configURL = defaultConfigURL()
        try? fm.createDirectory(at: baseDirectoryURL(), withIntermediateDirectories: true)
        try? fm.createDirectory(at: logsDirectoryURL(), withIntermediateDirectories: true)
        try? fm.createDirectory(at: tempDirectoryURL(), withIntermediateDirectories: true)

        guard fm.fileExists(atPath: configURL.path) else {
            let config = defaultConfig()
            do {
                let data = try JSONEncoder.pretty.encode(config)
                try data.write(to: configURL)
                print("Created default config at \(configURL.path)")
            } catch {
                print("Failed to write default config: \(error)")
            }
            return config
        }

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("Failed to read config at \(configURL.path): \(error)")
            print("Using in-memory default config.")
            return defaultConfig()
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
```


## `app/Sources/FlowLite/AppState.swift`

```swift
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

    private let onStateChange: (FlowLiteState) -> Void
    private let queue = DispatchQueue(label: "flowlite.pipeline", qos: .userInitiated)
    private var currentAudioURL: URL?

    private(set) var state: FlowLiteState = .idle {
        didSet {
            print("FlowLite state: \(state.displayName)")
            onStateChange(state)
        }
    }

    init(
        config: Config,
        recorder: AudioRecorder,
        whisper: WhisperRunner,
        cleaner: TextCleaner,
        inserter: PasteboardInserter,
        onStateChange: @escaping (FlowLiteState) -> Void
    ) {
        self.config = config
        self.recorder = recorder
        self.whisper = whisper
        self.cleaner = cleaner
        self.inserter = inserter
        self.onStateChange = onStateChange
    }

    func toggleDictation() {
        switch state {
        case .idle, .error:
            startDictation()
        case .recording:
            stopAndProcessDictation()
        case .transcribing, .pasting:
            print("FlowLite is busy; ignoring toggle.")
        }
    }

    func startDictation() {
        guard state != .recording else { return }
        do {
            let audioURL = try recorder.startRecording()
            currentAudioURL = audioURL
            state = .recording
        } catch {
            state = .error(String(describing: error))
        }
    }

    func stopAndProcessDictation() {
        guard state == .recording else { return }

        do {
            let audioURL = try recorder.stopRecording()
            currentAudioURL = audioURL
            state = .transcribing

            queue.async { [weak self] in
                self?.runPipeline(audioURL: audioURL)
            }
        } catch {
            state = .error(String(describing: error))
        }
    }

    private func runPipeline(audioURL: URL) {
        do {
            let rawTranscript = try whisper.transcribe(audioURL: audioURL)
            let cleaned = cleaner.clean(rawTranscript)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.state = .pasting
                self.inserter.paste(cleaned)
                self.cleanup(audioURL: audioURL)
                self.state = .idle
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.state = .error(String(describing: error))
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
        state = .idle
    }

    private func cleanup(audioURL: URL) {
        guard config.deleteTempAudio && !config.debugRetainAudio else { return }
        try? FileManager.default.removeItem(at: audioURL)
    }
}
```


## `app/Sources/FlowLite/AudioRecorder.swift`

```swift
import AVFoundation
import Foundation

enum AudioRecorderError: Error, CustomStringConvertible {
    case microphonePermissionDenied
    case failedToCreateRecorder(String)
    case recorderNotRunning
    case outputFileMissing

    var description: String {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission denied. Enable microphone access in System Settings."
        case .failedToCreateRecorder(let message):
            return "Failed to create audio recorder: \(message)"
        case .recorderNotRunning:
            return "Recorder is not running."
        case .outputFileMissing:
            return "Recording output file was not created."
        }
    }
}

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    static func requestMicrophoneAccessIfNeeded() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("FlowLite warning: microphone access was not granted.")
            }
        }
    }

    func startRecording() throws -> URL {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let tempDir = Config.tempDirectoryURL()
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent("dictation-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record()
            self.recorder = recorder
            self.currentURL = url
            print("Recording to \(url.path)")
            return url
        } catch {
            throw AudioRecorderError.failedToCreateRecorder(error.localizedDescription)
        }
    }

    func stopRecording() throws -> URL {
        guard let recorder else {
            throw AudioRecorderError.recorderNotRunning
        }
        recorder.stop()
        self.recorder = nil

        guard let url = currentURL else {
            throw AudioRecorderError.outputFileMissing
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioRecorderError.outputFileMissing
        }
        print("Stopped recording: \(url.path)")
        return url
    }
}
```


## `app/Sources/FlowLite/WhisperRunner.swift`

```swift
import Foundation

enum WhisperRunnerError: Error, CustomStringConvertible {
    case missingBinary(String)
    case binaryNotExecutable(String)
    case missingModel(String)
    case missingAudio(String)
    case processFailed(Int32, String)
    case timedOut(Int)
    case outputMissing(String)
    case emptyTranscript

    var description: String {
        switch self {
        case .missingBinary(let path):
            return "Whisper binary not found at: \(path)"
        case .binaryNotExecutable(let path):
            return "Whisper binary is not executable: \(path)"
        case .missingModel(let path):
            return "Whisper model not found at: \(path)"
        case .missingAudio(let path):
            return "Audio file not found at: \(path)"
        case .processFailed(let code, let stderr):
            return "Whisper process failed with exit code \(code): \(stderr)"
        case .timedOut(let seconds):
            return "Whisper transcription timed out after \(seconds) seconds."
        case .outputMissing(let path):
            return "Whisper output file missing at: \(path)"
        case .emptyTranscript:
            return "Whisper returned an empty transcript."
        }
    }
}

final class WhisperRunner {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func validateSetup() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: config.whisperBinaryPath) else {
            throw WhisperRunnerError.missingBinary(config.whisperBinaryPath)
        }
        guard fm.isExecutableFile(atPath: config.whisperBinaryPath) else {
            throw WhisperRunnerError.binaryNotExecutable(config.whisperBinaryPath)
        }
        guard fm.fileExists(atPath: config.modelPath) else {
            throw WhisperRunnerError.missingModel(config.modelPath)
        }
    }

    func transcribe(audioURL: URL) throws -> String {
        try validateSetup()

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperRunnerError.missingAudio(audioURL.path)
        }

        let outputBase = Config.tempDirectoryURL().appendingPathComponent("transcript-\(UUID().uuidString)")
        let outputTXT = outputBase.appendingPathExtension("txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.whisperBinaryPath)
        process.arguments = [
            "-m", config.modelPath,
            "-f", audioURL.path,
            "-l", config.language,
            "-nt",
            "-otxt",
            "-of", outputBase.path
        ]

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        print("Starting local Whisper transcription.")
        try process.run()

        let timeoutSeconds = max(1, config.transcriptionTimeoutSeconds)
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        if process.isRunning {
            process.terminate()
            throw WhisperRunnerError.timedOut(timeoutSeconds)
        }

        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw WhisperRunnerError.processFailed(process.terminationStatus, stderr)
        }

        guard FileManager.default.fileExists(atPath: outputTXT.path) else {
            throw WhisperRunnerError.outputMissing(outputTXT.path)
        }

        let transcript = try String(contentsOf: outputTXT, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        if !config.debugRetainAudio {
            try? FileManager.default.removeItem(at: outputTXT)
        }

        guard !transcript.isEmpty else {
            throw WhisperRunnerError.emptyTranscript
        }

        print("Whisper transcription complete. Transcript length: \(transcript.count) characters. Content not logged.")
        return transcript
    }
}
```


## `app/Sources/FlowLite/TextCleaner.swift`

```swift
import Foundation

public struct TextCleaner {
    private let rawTranscriptMode: Bool
    private let customVocabulary: [String: String]

    init(config: Config) {
        self.rawTranscriptMode = config.rawTranscriptMode
        self.customVocabulary = config.customVocabulary
    }

    init(rawTranscriptMode: Bool, customVocabulary: [String: String]) {
        self.rawTranscriptMode = rawTranscriptMode
        self.customVocabulary = customVocabulary
    }

    public func clean(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawTranscriptMode {
            return text
        }

        text = normalizeWhitespace(text)
        text = removeConservativeFillers(text)
        text = applyVocabulary(text)
        text = normalizeWhitespace(text)
        text = capitalizeFirstLetter(text)
        text = addTerminalPunctuationIfNeeded(text)

        return text
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeConservativeFillers(_ text: String) -> String {
        var output = text

        let fillerPatterns = [
            #"\b(um+|uh+|er+|ah+)\b,?\s*"#,
            #"\bkind of\b,?\s*"#,
            #"\bsort of\b,?\s*"#
        ]

        for pattern in fillerPatterns {
            output = output.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Keep this conservative. "Like" can be a verb/preposition, so do not remove it globally.
        output = output.replacingOccurrences(
            of: #"^(like|you know),?\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return output
    }

    private func applyVocabulary(_ text: String) -> String {
        var output = text

        for (phrase, replacement) in customVocabulary {
            let escaped = NSRegularExpression.escapedPattern(for: phrase)
            let pattern = #"\b"# + escaped + #"\b"#
            output = output.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return output
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private func addTerminalPunctuationIfNeeded(_ text: String) -> String {
        guard let last = text.last else { return text }
        if [".", "?", "!", ":", ";"].contains(String(last)) {
            return text
        }
        return text + "."
    }
}
```


## `app/Sources/FlowLite/PasteboardInserter.swift`

```swift
import AppKit
import Foundation

final class PasteboardInserter {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func paste(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previousString = config.restoreClipboardAfterPaste ? pasteboard.string(forType: .string) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateCommandV()

        if config.restoreClipboardAfterPaste, let previousString {
            let delay = Double(config.clipboardRestoreDelayMs) / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                pasteboard.clearContents()
                pasteboard.setString(previousString, forType: .string)
            }
        }
    }

    private func simulateCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
```


## `app/Sources/FlowLite/HotkeyMonitor.swift`

```swift
import AppKit
import Foundation

final class HotkeyMonitor {
    private let onToggle: () -> Void
    private var monitor: Any?
    private var lastToggleAt = Date.distantPast

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    func start() {
        // v0 uses a simple passive global monitor for F6.
        // For a production app, replace this with a more robust registered global shortcut.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 97 else { return } // F6 on many Apple keyboards.
            self?.debouncedToggle()
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func debouncedToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleAt) > 0.5 else { return }
        lastToggleAt = now
        DispatchQueue.main.async { [onToggle] in
            onToggle()
        }
    }
}
```


## `app/Resources/config.example.json`

```json
{
  "whisperBinaryPath": "/Users/roshan/dev/whisper.cpp/build/bin/whisper-cli",
  "modelPath": "/Users/roshan/models/ggml-base.en.bin",
  "language": "en",
  "rawTranscriptMode": false,
  "restoreClipboardAfterPaste": false,
  "clipboardRestoreDelayMs": 1500,
  "deleteTempAudio": true,
  "debugRetainAudio": false,
  "transcriptionTimeoutSeconds": 60,
  "customVocabulary": {
    "cofounders capital": "Cofounders Capital",
    "caju dot ai": "Caju.ai",
    "caju ai": "Caju.ai",
    "element four fifty one": "Element451",
    "kenan flagler": "Kenan-Flagler",
    "pmt": "PMT"
  }
}
```


## `app/Scripts/bootstrap_whisper_cpp.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Bootstrap helper for local development.
# This script intentionally clones/builds whisper.cpp as a local sidecar.
# The FlowLite app itself does not use network calls during dictation.

DEV_DIR="${HOME}/dev"
WHISPER_DIR="${DEV_DIR}/whisper.cpp"
MODEL_DIR="${HOME}/models"
MODEL_NAME="base.en"

mkdir -p "$DEV_DIR" "$MODEL_DIR"

if [ ! -d "$WHISPER_DIR" ]; then
  git clone https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
fi

cd "$WHISPER_DIR"
cmake -B build
cmake --build build -j

# Model download helper from whisper.cpp repository.
bash ./models/download-ggml-model.sh "$MODEL_NAME"
cp "models/ggml-${MODEL_NAME}.bin" "$MODEL_DIR/ggml-${MODEL_NAME}.bin"

cat <<EOF

whisper.cpp built.
Binary path:
  ${WHISPER_DIR}/build/bin/whisper-cli

Model path:
  ${MODEL_DIR}/ggml-${MODEL_NAME}.bin

Update ~/.flow-lite/config.json with these paths.
EOF
```


## `app/Scripts/run_local_smoke_test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${HOME}/.flow-lite/config.json"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Missing config: $CONFIG_PATH"
  echo "Run FlowLite once or copy Resources/config.example.json to this path."
  exit 1
fi

echo "Building FlowLite..."
swift build

echo "Launching FlowLite. Open TextEdit, place cursor in a document, then press F6."
swift run FlowLite
```


## `app/Tests/FlowLiteTests/TextCleanerTests.swift`

```swift
import XCTest
@testable import FlowLite

final class TextCleanerTests: XCTestCase {
    func testRemovesBasicFillers() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("um I think this is good"), "I think this is good.")
    }

    func testAppliesCustomVocabulary() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [
            "caju dot ai": "Caju.ai",
            "cofounders capital": "Cofounders Capital"
        ])
        XCTAssertEqual(cleaner.clean("send this to caju dot ai and cofounders capital"), "Send this to Caju.ai and Cofounders Capital.")
    }

    func testRawModeOnlyTrims() {
        let cleaner = TextCleaner(rawTranscriptMode: true, customVocabulary: ["caju dot ai": "Caju.ai"])
        XCTAssertEqual(cleaner.clean("  um send to caju dot ai  "), "um send to caju dot ai")
    }

    func testDoesNotChangeNumbers() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("send 15 emails by 5 pm"), "Send 15 emails by 5 pm.")
    }
}
```
