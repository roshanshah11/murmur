import XCTest
@testable import FlowLite

final class ConfigTests: XCTestCase {
    func testDefaultConfigHasSensiblePaths() {
        let cfg = Config.defaultConfig()
        let home = NSHomeDirectory()
        XCTAssertTrue(
            cfg.whisperBinaryPath.hasPrefix(home),
            "whisper binary should live under the user's home dir, got: \(cfg.whisperBinaryPath)"
        )
        XCTAssertTrue(
            cfg.modelPath.hasPrefix(home),
            "model path should live under the user's home dir, got: \(cfg.modelPath)"
        )
        XCTAssertTrue(
            cfg.whisperBinaryPath.hasSuffix("whisper-cli"),
            "binary path should end with whisper-cli, got: \(cfg.whisperBinaryPath)"
        )
        XCTAssertTrue(
            cfg.modelPath.hasSuffix("ggml-small.en-q5_1.bin"),
            "model path should end with ggml-small.en-q5_1.bin, got: \(cfg.modelPath)"
        )
        XCTAssertFalse(
            cfg.whisperBinaryPath.hasPrefix("/Users/roshan/"),
            "default config should not contain hardcoded /Users/roshan path"
        )
    }

    func testDecodeFromMinimalJSON() throws {
        let json = """
        {
          "whisperBinaryPath": "/tmp/x",
          "modelPath": "/tmp/y"
        }
        """.data(using: .utf8)!

        let cfg = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(cfg.whisperBinaryPath, "/tmp/x")
        XCTAssertEqual(cfg.modelPath, "/tmp/y")
        XCTAssertEqual(cfg.language, "en")
        XCTAssertEqual(cfg.pasteDelayMs, 50)
        XCTAssertEqual(cfg.errorAutoClearSeconds, 3)
        XCTAssertEqual(cfg.transcriptionTimeoutSeconds, 60)
        XCTAssertEqual(cfg.clipboardRestoreDelayMs, 1500)
        XCTAssertFalse(cfg.rawTranscriptMode)
        XCTAssertTrue(cfg.deleteTempAudio)
        XCTAssertFalse(cfg.debugRetainAudio)
        XCTAssertFalse(cfg.restoreClipboardAfterPaste)
        XCTAssertNil(cfg.whisperThreads)
        // Default vocabulary carries some seeded entries.
        XCTAssertEqual(cfg.customVocabulary["caju ai"], "Caju.ai")
    }

    func testDecodeFromCompleteJSON() throws {
        let original = Config.defaultConfig()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)

        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.whisperBinaryPath, original.whisperBinaryPath)
        XCTAssertEqual(decoded.modelPath, original.modelPath)
        XCTAssertEqual(decoded.language, original.language)
        XCTAssertEqual(decoded.rawTranscriptMode, original.rawTranscriptMode)
        XCTAssertEqual(decoded.restoreClipboardAfterPaste, original.restoreClipboardAfterPaste)
        XCTAssertEqual(decoded.clipboardRestoreDelayMs, original.clipboardRestoreDelayMs)
        XCTAssertEqual(decoded.deleteTempAudio, original.deleteTempAudio)
        XCTAssertEqual(decoded.debugRetainAudio, original.debugRetainAudio)
        XCTAssertEqual(decoded.transcriptionTimeoutSeconds, original.transcriptionTimeoutSeconds)
        XCTAssertEqual(decoded.whisperThreads, original.whisperThreads)
        XCTAssertEqual(decoded.pasteDelayMs, original.pasteDelayMs)
        XCTAssertEqual(decoded.errorAutoClearSeconds, original.errorAutoClearSeconds)
        XCTAssertEqual(decoded.customVocabulary, original.customVocabulary)
    }

    func testTempDirectoryUnderCaches() {
        let path = Config.tempDirectoryURL().path
        XCTAssertTrue(
            path.contains("Library/Caches/FlowLite/temp"),
            "temp dir should sit under Library/Caches/FlowLite/temp, got: \(path)"
        )
    }

    func testLogsDirectoryUnderFlowLite() {
        let path = Config.logsDirectoryURL().path
        XCTAssertTrue(
            path.contains(".flow-lite/logs"),
            "logs dir should sit under .flow-lite/logs, got: \(path)"
        )
    }
}
