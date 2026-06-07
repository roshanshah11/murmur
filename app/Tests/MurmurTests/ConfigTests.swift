@testable import Murmur
import XCTest

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
        let json = Data("""
        {
          "whisperBinaryPath": "/tmp/x",
          "modelPath": "/tmp/y"
        }
        """.utf8)

        let cfg = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(cfg.whisperBinaryPath, "/tmp/x")
        XCTAssertEqual(cfg.modelPath, "/tmp/y")
        XCTAssertEqual(cfg.language, "en")
        XCTAssertEqual(cfg.pasteDelayMs, 10)
        XCTAssertEqual(cfg.errorAutoClearSeconds, 3)
        XCTAssertEqual(cfg.transcriptionTimeoutSeconds, 60)
        XCTAssertEqual(cfg.clipboardRestoreDelayMs, 1500)
        XCTAssertFalse(cfg.rawTranscriptMode)
        XCTAssertTrue(cfg.deleteTempAudio)
        XCTAssertFalse(cfg.debugRetainAudio)
        XCTAssertFalse(cfg.restoreClipboardAfterPaste)
        XCTAssertNil(cfg.whisperThreads)
        XCTAssertFalse(
            cfg.historyEnabled,
            "history must default to OFF when key is missing (Phase 5 privacy carryover)"
        )
        // Default vocabulary carries some seeded entries.
        let cajuEntry = cfg.vocabulary.entries.first { $0.from.lowercased() == "caju ai" }
        XCTAssertEqual(cajuEntry?.to, "Caju.ai")
        XCTAssertEqual(cfg.activeProfile, .casual)
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
        XCTAssertEqual(decoded.vocabulary, original.vocabulary)
        XCTAssertEqual(decoded.activeProfile, original.activeProfile)
    }

    func test_legacyCustomVocabularyDecodesIntoVocabulary() throws {
        let legacyJSON = Data("""
        {"customVocabulary":{"API":"A P I","ChatGPT":"chat gee pee tee"}}
        """.utf8)
        let cfg = try JSONDecoder().decode(Config.self, from: legacyJSON)
        XCTAssertEqual(cfg.vocabulary.entries.count, 2)
        XCTAssertEqual(cfg.activeProfile, .casual)
    }

    func test_modernConfigDecodesIntactWithProfile() throws {
        var vocab = Vocabulary()
        vocab.upsert(from: "ok", to: "okay")
        var cfg = Config.defaultConfig()
        cfg.vocabulary = vocab
        cfg.activeProfile = .formal
        let data = try JSONEncoder().encode(cfg)
        let restored = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(restored.vocabulary.entries.count, 1)
        XCTAssertEqual(restored.activeProfile, .formal)
    }

    func test_historyEnabled_defaultsFalse_andRoundTrips() throws {
        // Default factory: opt-in only.
        XCTAssertFalse(Config.defaultConfig().historyEnabled,
                       "Phase 5 spec §7.2 — history must be OFF by default")

        // Missing key in JSON should decode to false (not the legacy true).
        let missing = Data("{}".utf8)
        let decodedMissing = try JSONDecoder().decode(Config.self, from: missing)
        XCTAssertFalse(decodedMissing.historyEnabled,
                       "missing historyEnabled key must default to false")

        // Explicit true round-trips intact.
        var cfg = Config.defaultConfig()
        cfg.historyEnabled = true
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertTrue(decoded.historyEnabled, "historyEnabled=true must round-trip")
    }

    func test_onboardingCompletedVersion_defaultsNil_andRoundTrips() throws {
        // Phase 6: default factory must leave the wizard "unfinished"
        // so the first launch reopens it.
        XCTAssertNil(Config.defaultConfig().onboardingCompletedVersion,
                     "onboardingCompletedVersion must default to nil so first launch shows the wizard")

        // Missing key in JSON should also decode to nil.
        let missing = Data("{}".utf8)
        let decodedMissing = try JSONDecoder().decode(Config.self, from: missing)
        XCTAssertNil(decodedMissing.onboardingCompletedVersion,
                     "missing onboardingCompletedVersion key must decode to nil")

        // Setting an explicit version round-trips.
        var cfg = Config.defaultConfig()
        cfg.onboardingCompletedVersion = "1.0"
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.onboardingCompletedVersion, "1.0",
                       "explicit onboardingCompletedVersion must round-trip")

        // And clearing it back to nil also persists across a round trip.
        cfg.onboardingCompletedVersion = nil
        let data2 = try JSONEncoder().encode(cfg)
        let decoded2 = try JSONDecoder().decode(Config.self, from: data2)
        XCTAssertNil(decoded2.onboardingCompletedVersion)
    }

    // MARK: - TranscriptionEngine tests (T4)

    func test_transcriptionEngine_roundTrips() throws {
        // Use .whisperCpp — a non-default value on Apple Silicon — so the test
        // is meaningful regardless of which architecture runs CI.
        var cfg = Config.defaultConfig()
        cfg.transcriptionEngine = .whisperCpp
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.transcriptionEngine, .whisperCpp,
                       "transcriptionEngine=.whisperCpp must survive a JSON round-trip")
    }

    func test_transcriptionEngine_defaultsToDeviceDefault_whenKeyMissing() throws {
        // Build a JSON blob that omits the transcriptionEngine key by encoding
        // a default config, parsing to a dictionary, stripping the key, and
        // re-serialising.
        let fullData = try JSONEncoder().encode(Config.defaultConfig())
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: fullData) as? [String: Any])
        dict.removeValue(forKey: "transcriptionEngine")
        let stripped = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(Config.self, from: stripped)
        XCTAssertEqual(decoded.transcriptionEngine, TranscriptionEngineKind.deviceDefault,
                       "missing transcriptionEngine key must decode to .deviceDefault")
    }

    func test_transcriptionEngineKind_deviceDefault_isArchDependent() {
        // On Apple Silicon the default should be .parakeet; on Intel .whisperCpp.
        let expected: TranscriptionEngineKind = TranscriptionEngineKind.isAppleSilicon ? .parakeet : .whisperCpp
        XCTAssertEqual(TranscriptionEngineKind.deviceDefault, expected)
    }

    func test_transcriptionEngineKind_allCasesAreRoundTrippable() throws {
        for kind in TranscriptionEngineKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(TranscriptionEngineKind.self, from: data)
            XCTAssertEqual(decoded, kind, "\(kind.rawValue) must round-trip through JSON")
        }
    }

    func testTempDirectoryUnderCaches() {
        let path = Config.tempDirectoryURL().path
        XCTAssertTrue(
            path.contains("Library/Caches/Murmur/temp"),
            "temp dir should sit under Library/Caches/Murmur/temp, got: \(path)"
        )
    }

    func testLogsDirectoryUnderMurmur() {
        let path = Config.logsDirectoryURL().path
        XCTAssertTrue(
            path.contains("Library/Logs/Murmur"),
            "logs dir should sit under Library/Logs/Murmur, got: \(path)"
        )
    }
}
