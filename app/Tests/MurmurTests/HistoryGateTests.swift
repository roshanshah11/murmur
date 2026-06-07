@testable import Murmur
// Phase 5: opt-in history. These tests exercise the `Config.historyEnabled`
// gate at the AppState call site and the round-trip of the new
// `HistoryEntry.favorite` field — without involving the whisper/paste
// pipeline (which can't run in a unit-test environment).
import XCTest

/// Stand-in engine for tests that exercise AppState's history gate without
/// running real transcription. Depends only on the protocol, so it's immune
/// to concrete engine init-signature changes.
private final class NullEngine: TranscriptionEngine {
    func transcribe(wavURL: URL, language: String?) async throws -> String { "" }
}

final class HistoryGateTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-history-gate-\(UUID().uuidString).jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    private func makeAppState(historyEnabled: Bool) -> (AppState, HistoryStore) {
        var cfg = Config.defaultConfig()
        cfg.historyEnabled = historyEnabled
        // HistoryStore.enabled MUST be true so the store itself doesn't block;
        // we're testing the AppState-level gate in isolation.
        let store = HistoryStore(enabled: true, maxEntries: 50, fileURL: tempURL)
        let recorder = AudioRecorder()
        let engine = NullEngine()
        let cleaner = TextCleaner(vocabulary: cfg.vocabulary, profile: cfg.activeProfile)
        let inserter = PasteboardInserter(config: cfg)
        let volume = VolumeController()
        let state = AppState(
            config: cfg,
            recorder: recorder,
            engine: engine,
            cleaner: cleaner,
            inserter: inserter,
            history: store,
            volume: volume,
            onStateChange: { _ in }
        )
        return (state, store)
    }

    private func ctx() -> AppContext {
        AppContext(name: "TextEdit", bundleID: "com.apple.TextEdit")
    }

    func test_historyDisabled_doesNotAppend() {
        let (state, store) = makeAppState(historyEnabled: false)
        state.appendHistoryIfEnabled(
            cleaned: "hello",
            raw: "hello",
            target: ctx(),
            durationMs: 100,
            result: "pasted:com.apple.TextEdit"
        )
        // The store would write asynchronously if called; give it a beat
        // to ensure the gate truly prevented enqueuing the write.
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(store.loadRecent(limit: 5).count, 0,
                       "history must be skipped when Config.historyEnabled == false")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path),
                       "no JSONL file should ever be created when history is off")
    }

    func test_historyEnabled_appendsAfterPasteSuccess() {
        let (state, store) = makeAppState(historyEnabled: true)
        state.appendHistoryIfEnabled(
            cleaned: "Hello, world.",
            raw: "hello world",
            target: ctx(),
            durationMs: 250,
            result: "pasted:com.apple.TextEdit"
        )
        // Async append → drain via a sync read.
        Thread.sleep(forTimeInterval: 0.1)
        let entries = store.loadRecent(limit: 5)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.cleaned, "Hello, world.")
        XCTAssertEqual(entries.first?.targetApp, "TextEdit")
        XCTAssertEqual(entries.first?.durationMs, 250)
        XCTAssertFalse(entries.first?.favorite ?? true,
                       "new entries default to favorite=false")
    }

    /// Privacy-critical: toggling history OFF mid-session must stop new
    /// dictations from being recorded. AppState.config is `var` and the
    /// menubar/notification wiring (in main.swift) mutates it in-place;
    /// this test exercises the gate after a runtime mutation.
    func test_historyToggle_takesEffectWithoutRestart() {
        let (state, store) = makeAppState(historyEnabled: true)
        state.appendHistoryIfEnabled(
            cleaned: "first",
            raw: "first",
            target: ctx(),
            durationMs: 1,
            result: "pasted"
        )
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(store.loadRecent(limit: 5).count, 1)

        // User toggles OFF in the live session.
        state.config.historyEnabled = false
        state.appendHistoryIfEnabled(
            cleaned: "second",
            raw: "second",
            target: ctx(),
            durationMs: 1,
            result: "pasted"
        )
        Thread.sleep(forTimeInterval: 0.1)
        let entries = store.loadRecent(limit: 5)
        XCTAssertEqual(entries.count, 1,
                       "toggling history OFF mid-session must block subsequent appends")
        XCTAssertEqual(entries.first?.cleaned, "first")
    }

    func test_historyEntry_favoriteFieldRoundTrips() throws {
        // Explicit value round-trips.
        let original = HistoryEntry(
            id: "abc",
            ts: "2026-05-17T12:00:00.000Z",
            cleaned: "starred",
            raw: "starred",
            targetApp: "TextEdit",
            targetBundle: "com.apple.TextEdit",
            durationMs: 10,
            result: "pasted",
            favorite: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        XCTAssertTrue(decoded.favorite, "favorite=true must round-trip through Codable")

        // Pre-Phase-5 JSON (no `favorite` key) must decode with favorite=false
        // so existing user history files keep working.
        let legacyJSON = Data("""
        {"id":"x","ts":"2026-05-17T12:00:00.000Z","cleaned":"old","raw":"old",
         "target_app":"TextEdit","target_bundle":"com.apple.TextEdit",
         "duration_ms":1,"result":"pasted"}
        """.utf8)
        let legacy = try JSONDecoder().decode(HistoryEntry.self, from: legacyJSON)
        XCTAssertFalse(legacy.favorite,
                       "missing favorite key must default to false for backward compat")

        // setFavorite end-to-end against the store.
        let store = HistoryStore(enabled: true, maxEntries: 10, fileURL: tempURL)
        store.append(
            cleaned: "to fav",
            raw: "to fav",
            target: ctx(),
            durationMs: 1,
            result: "pasted"
        )
        Thread.sleep(forTimeInterval: 0.1)
        guard let row = store.loadRecent(limit: 1).first else {
            return XCTFail("expected one entry")
        }
        XCTAssertTrue(store.setFavorite(id: row.id, true),
                      "setFavorite should report success for an existing id")
        let updated = store.loadRecent(limit: 1).first
        XCTAssertEqual(updated?.favorite, true,
                       "favorite flag must persist after setFavorite + reload")
    }
}
