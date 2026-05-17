import XCTest
@testable import Murmur

@MainActor
final class PromptsTabModelTests: XCTestCase {
    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-prompts-\(UUID().uuidString).json")
    }

    private func makeModel(sample: String? = nil) -> (PromptsTabModel, SettingsStore) {
        let store = SettingsStore(configURL: tempURL(), debounceMs: 30)
        // Make sure vocab doesn't influence preview outputs.
        store.mutate { $0.vocabulary = Vocabulary() }
        store.flushNow()
        let model: PromptsTabModel
        if let sample {
            model = PromptsTabModel(store: store, defaultSample: sample)
        } else {
            model = PromptsTabModel(store: store)
        }
        return (model, store)
    }

    func test_setProfile_updatesConfigAndCleanedOutputChanges() {
        let (model, store) = makeModel(sample: "the api equals equals null")
        XCTAssertEqual(model.activeProfile, .casual)

        model.selectProfile(.code)
        XCTAssertEqual(model.activeProfile, .code)
        store.flushNow()
        XCTAssertEqual(store.config.activeProfile, .code,
                       "selectProfile must persist via SettingsStore")

        // The cleaned output for the "Code" profile must translate the
        // spoken operator; "Casual" must leave it alone (or strip
        // surrounding fillers).
        let codeOut = model.output(for: .code)
        XCTAssertTrue(codeOut.contains("=="),
                      "Code profile should translate 'equals equals' → '==', got \(codeOut)")
        let casualOut = model.output(for: .casual)
        XCTAssertFalse(casualOut.contains("=="),
                       "Casual profile must not run the Code operator pass")
    }

    func test_preview_appliesProfileToSample() {
        // Single sample, exercise all four profiles. The expected outputs
        // pin down the per-profile contract so regressions in PromptLibrary
        // can't silently change what the user sees in this tab.
        let (model, _) = makeModel(sample: "um, like, i don't know")

        XCTAssertEqual(model.output(for: .raw), "um, like, i don't know",
                       "Raw must passthrough the sample verbatim")

        let casual = model.output(for: .casual)
        XCTAssertFalse(casual.lowercased().contains("um,"),
                       "Casual must strip 'um' filler, got: \(casual)")
        XCTAssertFalse(casual.hasPrefix("like"),
                       "Casual must strip leading 'like' filler, got: \(casual)")

        let formal = model.output(for: .formal)
        XCTAssertTrue(formal.contains("do not"),
                      "Formal must expand 'don't' → 'do not', got: \(formal)")

        // Code profile leaves spoken-language fillers alone — it only
        // touches the operator list. Confirm it does not crash and
        // returns *something* containing the bulk of the input.
        let code = model.output(for: .code)
        XCTAssertTrue(code.contains("don't"),
                      "Code profile shouldn't expand contractions, got: \(code)")
    }
}
