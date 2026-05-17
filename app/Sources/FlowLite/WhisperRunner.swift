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

    var shortMessage: String {
        switch self {
        case .missingBinary: return "Whisper binary not found"
        case .binaryNotExecutable: return "Whisper binary not executable"
        case .missingModel: return "Whisper model missing"
        case .missingAudio: return "Audio file missing"
        case .processFailed: return "Whisper failed"
        case .timedOut: return "Whisper timed out"
        case .outputMissing: return "Whisper output missing"
        case .emptyTranscript: return "Empty transcript"
        }
    }
}

final class WhisperRunner {
    private let config: Config
    private var cachedBinaryPath: String?
    private var cachedModelPath: String?
    private static let cachedThreads: Int = WhisperRunner.computeDefaultThreads()

    init(config: Config) {
        self.config = config
    }

    /// Validate paths and cache them so subsequent calls skip the four stat
    /// syscalls on the hot path. Caller should run this once at startup.
    func validateSetup() throws {
        let fm = FileManager.default
        let binaryPath = expand(config.whisperBinaryPath)
        let modelPath = expand(config.modelPath)
        guard fm.fileExists(atPath: binaryPath) else {
            throw WhisperRunnerError.missingBinary(binaryPath)
        }
        guard fm.isExecutableFile(atPath: binaryPath) else {
            throw WhisperRunnerError.binaryNotExecutable(binaryPath)
        }
        guard fm.fileExists(atPath: modelPath) else {
            throw WhisperRunnerError.missingModel(modelPath)
        }
        cachedBinaryPath = binaryPath
        cachedModelPath = modelPath
    }

    func transcribe(audioURL: URL) throws -> String {
        // Use cached validated paths if available — avoids 4 stat syscalls per
        // dictation. Falls back to a fresh validate on first call.
        if cachedBinaryPath == nil || cachedModelPath == nil {
            try validateSetup()
        }
        guard let binaryPath = cachedBinaryPath, let modelPath = cachedModelPath else {
            throw WhisperRunnerError.missingBinary(config.whisperBinaryPath)
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperRunnerError.missingAudio(audioURL.path)
        }

        let outputBase = Config.tempDirectoryURL().appendingPathComponent("transcript-\(UUID().uuidString)")
        let outputTXT = outputBase.appendingPathExtension("txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)

        var args = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-l", config.language,
            "-nt",
            "-bs", "1",
            "-bo", "1",
            "-np",
            "-otxt",
            "-of", outputBase.path
        ]
        let threads = config.whisperThreads ?? Self.cachedThreads
        args.append(contentsOf: ["-t", String(threads)])

        process.arguments = args

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        // T4: async drain to prevent pipe buffer deadlock.
        let stderrBuffer = SyncBuffer()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stderrBuffer.append(data)
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            }
        }

        // Dynamic timeout: floor at config value, but scale up for long
        // recordings so multi-minute audio doesn't get killed mid-decode.
        // WAV at 16 kHz mono 16-bit = 32 KB/sec → audio_sec ≈ bytes / 32_000.
        // Allow ~4x realtime as a generous ceiling, plus 10s startup slack.
        let audioBytes = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        let audioSec = max(1, audioBytes / 32_000)
        let dynamicTimeout = audioSec * 4 + 10
        let timeoutSeconds = max(max(1, config.transcriptionTimeoutSeconds), dynamicTimeout)
        let timeoutItem = DispatchWorkItem { [weak process] in
            if process?.isRunning == true {
                process?.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(timeoutSeconds), execute: timeoutItem)

        let startedAt = Date()
        Log.event(state: "transcription_started", fields: [
            "model": (expand(config.modelPath) as NSString).lastPathComponent,
            "threads": String(threads)
        ])

        do {
            try process.run()
        } catch {
            timeoutItem.cancel()
            throw WhisperRunnerError.processFailed(-1, error.localizedDescription)
        }

        process.waitUntilExit()
        let didTimeout = timeoutItem.isCancelled == false && process.terminationReason == .uncaughtSignal
        timeoutItem.cancel()

        // Drain any remaining buffered data.
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        let remainingErr = stderrPipe.fileHandleForReading.availableData
        if !remainingErr.isEmpty { stderrBuffer.append(remainingErr) }
        _ = stdoutPipe.fileHandleForReading.availableData

        let stderr = String(data: stderrBuffer.snapshot(), encoding: .utf8) ?? ""

        if didTimeout {
            throw WhisperRunnerError.timedOut(timeoutSeconds)
        }

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

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        Log.event(state: "transcription_completed", fields: [
            "transcription_ms": String(elapsedMs),
            "chars": String(transcript.count)
        ])
        return transcript
    }

    private func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    /// Public accessor for tests / debugging. Use the static cache on hot path.
    static func defaultThreads() -> Int { cachedThreads }

    private static func computeDefaultThreads() -> Int {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        p.arguments = ["-n", "hw.perflevel0.physicalcpu"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let n = Int(s), n > 0 {
                return min(n, 8)
            }
        } catch {}
        return max(2, min(ProcessInfo.processInfo.activeProcessorCount / 2, 8))
    }
}

/// Thread-safe append-only data buffer for async pipe draining.
private final class SyncBuffer {
    private let queue = DispatchQueue(label: "flowlite.whisper.buffer")
    private var data = Data()
    func append(_ bytes: Data) { queue.sync { data.append(bytes) } }
    func snapshot() -> Data { queue.sync { data } }
}
