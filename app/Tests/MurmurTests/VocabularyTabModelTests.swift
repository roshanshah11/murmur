import XCTest
@testable import Murmur

@MainActor
final class VocabularyTabModelTests: XCTestCase {
    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-vocab-\(UUID().uuidString).json")
    }

    private func makeModel() -> (VocabularyTabModel, SettingsStore) {
        let store = SettingsStore(configURL: tempURL(), debounceMs: 30)
        // Start from a known empty vocab so seed entries don't pollute
        // index-based assertions.
        store.mutate { $0.vocabulary = Vocabulary() }
        store.flushNow()
        let model = VocabularyTabModel(store: store)
        return (model, store)
    }

    func test_addEntry_appendsToConfig() {
        let (model, store) = makeModel()
        XCTAssertEqual(model.entries.count, 0)
        model.addEntry(from: "api", to: "A P I")
        XCTAssertEqual(model.entries.count, 1)
        XCTAssertEqual(model.entries.first?.from, "api")
        XCTAssertEqual(model.entries.first?.to, "A P I")
        store.flushNow()
        XCTAssertEqual(store.config.vocabulary.entries.count, 1)
    }

    func test_removeEntry_dropsFromConfig() {
        let (model, store) = makeModel()
        model.addEntry(from: "api", to: "A P I")
        model.addEntry(from: "gpt", to: "ChatGPT")
        XCTAssertEqual(model.entries.count, 2)
        model.removeEntries(ids: [model.entries[0].id])
        XCTAssertEqual(model.entries.count, 1)
        XCTAssertEqual(model.entries.first?.from, "gpt")
        store.flushNow()
        XCTAssertEqual(store.config.vocabulary.entries.count, 1)
    }

    func test_importJSON_replacesEntries() throws {
        let (model, store) = makeModel()
        model.addEntry(from: "old", to: "stale")

        let importPayload = """
        {"entries":[{"from":"api","to":"A P I"},{"from":"gpt","to":"ChatGPT"}]}
        """.data(using: .utf8)!
        try model.importJSON(data: importPayload)

        XCTAssertEqual(model.entries.count, 2, "import should fully replace existing entries")
        XCTAssertEqual(model.entries.map(\.from), ["api", "gpt"])

        store.flushNow()
        XCTAssertEqual(store.config.vocabulary.entries.count, 2)
    }

    func test_importJSON_acceptsLegacyDictionaryShape() throws {
        let (model, _) = makeModel()
        // Legacy customVocabulary shape — must still import for users who
        // exported during the dict-only era.
        let legacy = #"{"API":"A P I","ChatGPT":"chat gee pee tee"}"#.data(using: .utf8)!
        try model.importJSON(data: legacy)
        XCTAssertEqual(model.entries.count, 2)
        XCTAssertTrue(model.entries.contains { $0.from == "API" && $0.to == "A P I" })
    }

    func test_exportJSON_roundTrips() throws {
        let (model, _) = makeModel()
        model.addEntry(from: "api", to: "A P I")
        model.addEntry(from: "gpt", to: "ChatGPT")

        let exported = try model.exportJSON()
        let decoded = try JSONDecoder().decode(Vocabulary.self, from: exported)
        XCTAssertEqual(decoded.entries.count, 2)
        XCTAssertEqual(decoded.apply(to: "the api is gpt"), "the A P I is ChatGPT")
    }

    func test_resetToDefaults_restoresSeed() {
        let (model, store) = makeModel()
        model.addEntry(from: "scratch", to: "noise")
        model.resetToDefaults()
        store.flushNow()
        // Seed contains "caju ai" → "Caju.ai" (see Config.defaultVocabularySeed).
        XCTAssertTrue(
            store.config.vocabulary.entries.contains { $0.from.lowercased() == "caju ai" },
            "resetToDefaults must restore the seeded entries"
        )
        XCTAssertFalse(
            store.config.vocabulary.entries.contains { $0.from == "scratch" },
            "resetToDefaults must drop user-added entries"
        )
    }
}
