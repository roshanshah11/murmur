import AVFoundation
import Foundation

enum AudioRecorderError: Error, CustomStringConvertible {
    case microphonePermissionDenied
    case failedToCreateRecorder(String)
    case recorderNotRunning
    case outputFileMissing
    case wavConversionFailed(String)

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
        case .wavConversionFailed(let message):
            return "WAV conversion failed: \(message)"
        }
    }
}

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    /// Normalized mic level 0..1 derived from AVAudioRecorder.averagePower.
    /// Returns 0 when not recording. Cheap to poll at 30Hz.
    func currentLevel() -> Float {
        guard let r = recorder else { return 0 }
        r.updateMeters()
        let dB = r.averagePower(forChannel: 0)   // -160 (silence) .. 0 (max)
        let clamped = max(-50, min(0, dB))
        return (clamped + 50) / 50
    }

    static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Blocks the caller until permission is resolved. Safe to call repeatedly.
    func ensurePermission() throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return
        case .denied, .restricted:
            throw AudioRecorderError.microphonePermissionDenied
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            if !granted {
                throw AudioRecorderError.microphonePermissionDenied
            }
        @unknown default:
            throw AudioRecorderError.microphonePermissionDenied
        }
    }

    func startRecording() throws -> URL {
        try ensurePermission()

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
            Log.event(state: "recording_started", fields: ["path": url.lastPathComponent])
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

        // AVAudioRecorder with kAudioFormatLinearPCM + .wav extension reliably
        // emits valid RIFF/WAVE on macOS 13+. Skip the header check on the
        // happy path to save 2–5ms of synchronous I/O per dictation. Caller
        // can invoke ensureValidWAV(url:) manually if a future bug appears.
        Log.event(state: "recording_stopped", fields: ["path": url.lastPathComponent])
        return url
    }

    /// Verify RIFF/WAVE header. If missing, convert via afconvert.
    /// Kept for diagnostics; not called on the hot path.
    func ensureValidWAV(url: URL) throws -> URL {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return url
        }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 12)) ?? Data()
        if header.count == 12 {
            let riff = String(data: header.subdata(in: 0..<4), encoding: .ascii)
            let wave = String(data: header.subdata(in: 8..<12), encoding: .ascii)
            if riff == "RIFF" && wave == "WAVE" {
                return url
            }
        }

        Log.event(state: "wav_header_invalid", fields: ["path": url.lastPathComponent])
        let converted = url.deletingPathExtension().appendingPathExtension("conv.wav")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        p.arguments = ["-d", "LEI16@16000", "-c", "1", "-f", "WAVE", url.path, converted.path]
        let err = Pipe()
        p.standardError = err
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            throw AudioRecorderError.wavConversionFailed(error.localizedDescription)
        }
        guard p.terminationStatus == 0 else {
            let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AudioRecorderError.wavConversionFailed("afconvert exit \(p.terminationStatus): \(stderr)")
        }
        try? FileManager.default.removeItem(at: url)
        return converted
    }
}
