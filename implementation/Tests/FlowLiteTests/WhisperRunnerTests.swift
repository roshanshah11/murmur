import XCTest
@testable import FlowLite

final class WhisperRunnerTests: XCTestCase {
    private var scratchDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Per-test scratch dir to avoid cross-test interference.
        scratchDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FlowLiteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)
        // WhisperRunner.transcribe writes its output file into Config.tempDirectoryURL().
        // That dir is normally created by Config.loadOrCreateDefault(); make sure it exists for tests.
        try FileManager.default.createDirectory(
            at: Config.tempDirectoryURL(),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let scratchDir, FileManager.default.fileExists(atPath: scratchDir.path) {
            try? FileManager.default.removeItem(at: scratchDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeConfig(
        binaryPath: String,
        modelPath: String,
        timeoutSeconds: Int = 10
    ) -> Config {
        Config(
            whisperBinaryPath: binaryPath,
            modelPath: modelPath,
            language: "en",
            rawTranscriptMode: false,
            restoreClipboardAfterPaste: false,
            clipboardRestoreDelayMs: 1500,
            deleteTempAudio: true,
            debugRetainAudio: false,
            transcriptionTimeoutSeconds: timeoutSeconds,
            whisperThreads: 1,
            pasteDelayMs: 50,
            errorAutoClearSeconds: 3,
            customVocabulary: [:]
        )
    }

    private func makeFakeBinary(contents: String, executable: Bool) throws -> String {
        let path = scratchDir.appendingPathComponent("fake-whisper-\(UUID().uuidString).sh").path
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        } else {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path)
        }
        return path
    }

    private func makeFakeModel() throws -> String {
        let path = scratchDir.appendingPathComponent("fake-model-\(UUID().uuidString).bin").path
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: URL(fileURLWithPath: path))
        return path
    }

    private func makeFakeWAV() throws -> URL {
        let url = scratchDir.appendingPathComponent("fake-audio-\(UUID().uuidString).wav")
        // Minimal RIFF/WAVE-shaped header — enough for an "exists" check; the fake
        // binary never actually parses the audio.
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: [0x24, 0x00, 0x00, 0x00]) // chunk size
        data.append(contentsOf: Array("WAVE".utf8))
        // Pad to a few bytes so the file is non-trivial.
        data.append(Data(count: 16))
        try data.write(to: url)
        return url
    }

    // MARK: - validateSetup

    func testMissingBinaryThrows() throws {
        let cfg = makeConfig(
            binaryPath: "/nonexistent/path/whisper-cli",
            modelPath: try makeFakeModel()
        )
        let runner = WhisperRunner(config: cfg)

        XCTAssertThrowsError(try runner.validateSetup()) { error in
            guard let err = error as? WhisperRunnerError else {
                XCTFail("expected WhisperRunnerError, got \(error)")
                return
            }
            switch err {
            case .missingBinary:
                break
            default:
                XCTFail("expected .missingBinary, got \(err)")
            }
        }
    }

    func testBinaryNotExecutableThrows() throws {
        let binaryPath = try makeFakeBinary(contents: "#!/bin/sh\nexit 0\n", executable: false)
        let cfg = makeConfig(binaryPath: binaryPath, modelPath: try makeFakeModel())
        let runner = WhisperRunner(config: cfg)

        XCTAssertThrowsError(try runner.validateSetup()) { error in
            guard let err = error as? WhisperRunnerError else {
                XCTFail("expected WhisperRunnerError, got \(error)")
                return
            }
            switch err {
            case .binaryNotExecutable:
                break
            default:
                XCTFail("expected .binaryNotExecutable, got \(err)")
            }
        }
    }

    func testMissingModelThrows() throws {
        let binaryPath = try makeFakeBinary(contents: "#!/bin/sh\nexit 0\n", executable: true)
        let cfg = makeConfig(
            binaryPath: binaryPath,
            modelPath: "/nonexistent/path/ggml-model.bin"
        )
        let runner = WhisperRunner(config: cfg)

        XCTAssertThrowsError(try runner.validateSetup()) { error in
            guard let err = error as? WhisperRunnerError else {
                XCTFail("expected WhisperRunnerError, got \(error)")
                return
            }
            switch err {
            case .missingModel:
                break
            default:
                XCTFail("expected .missingModel, got \(err)")
            }
        }
    }

    // MARK: - transcribe

    func testEmptyTranscriptThrows() throws {
        // Fake binary parses -of and produces an EMPTY output file at "<base>.txt".
        let script = """
        #!/bin/sh
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -of) shift; : > "$1.txt"; shift ;;
            *) shift ;;
          esac
        done
        exit 0
        """
        let binaryPath = try makeFakeBinary(contents: script, executable: true)
        let cfg = makeConfig(binaryPath: binaryPath, modelPath: try makeFakeModel())
        let runner = WhisperRunner(config: cfg)
        let audioURL = try makeFakeWAV()

        XCTAssertThrowsError(try runner.transcribe(audioURL: audioURL)) { error in
            guard let err = error as? WhisperRunnerError else {
                XCTFail("expected WhisperRunnerError, got \(error)")
                return
            }
            switch err {
            case .emptyTranscript:
                break
            default:
                XCTFail("expected .emptyTranscript, got \(err)")
            }
        }
    }

    func testHappyPathReturnsTranscript() throws {
        // Fake binary writes "hello world\n" to "<base>.txt"; the runner should
        // trim and return "hello world".
        let script = """
        #!/bin/sh
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -of) shift; printf 'hello world\\n' > "$1.txt"; shift ;;
            *) shift ;;
          esac
        done
        exit 0
        """
        let binaryPath = try makeFakeBinary(contents: script, executable: true)
        let cfg = makeConfig(binaryPath: binaryPath, modelPath: try makeFakeModel())
        let runner = WhisperRunner(config: cfg)
        let audioURL = try makeFakeWAV()

        let transcript = try runner.transcribe(audioURL: audioURL)
        XCTAssertEqual(transcript, "hello world")
    }
}
