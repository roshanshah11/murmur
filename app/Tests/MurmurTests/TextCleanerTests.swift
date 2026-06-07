@testable import Murmur
import XCTest

/// Helper: build a Vocabulary from a `[from: to]` dictionary literal,
/// inserted in sorted-key order for deterministic substitution ordering.
private func vocabulary(_ entries: [String: String]) -> Vocabulary {
    var vocab = Vocabulary()
    for key in entries.keys.sorted() {
        vocab.upsert(from: key, to: entries[key] ?? "")
    }
    return vocab
}

final class TextCleanerTests: XCTestCase {
    func testRemovesBasicFillers() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(cleaner.clean("um I think this is good"), "I think this is good.")
    }

    func testAppliesCustomVocabulary() {
        let cleaner = TextCleaner(
            vocabulary: vocabulary([
                "caju dot ai": "Caju.ai",
                "cofounders capital": "Cofounders Capital"
            ]),
            profile: .casual
        )
        XCTAssertEqual(
            cleaner.clean("send this to caju dot ai and cofounders capital"),
            "Send this to Caju.ai and Cofounders Capital."
        )
    }

    func testRawProfileIsPassthrough() {
        // Raw profile no longer trims or strips fillers — true passthrough.
        // Vocabulary still applies after the (no-op) profile pass.
        let cleaner = TextCleaner(
            vocabulary: vocabulary(["caju dot ai": "Caju.ai"]),
            profile: .raw
        )
        XCTAssertEqual(
            cleaner.clean("  um send to caju dot ai  "),
            "  um send to Caju.ai  "
        )
    }

    func testDoesNotChangeNumbers() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(cleaner.clean("send 15 emails by 5 pm"), "Send 15 emails by 5 pm.")
    }

    func testKindOfPreserved() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(cleaner.clean("kind of nice and warm"), "Kind of nice and warm.")
    }

    func testSortOfPreserved() {
        // "sort of" must be preserved (carries meaning). Leading-"like" strip only
        // fires when "like" is at the very start of the input, so it does not apply
        // here — "sort" is first. Result keeps the full phrase verbatim.
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(
            cleaner.clean("sort of like a draft document"),
            "Sort of like a draft document."
        )
    }

    func testNoPunctuationForShortFragment() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(cleaner.clean("buy milk"), "Buy milk")
    }

    func testNoPunctuationWhenAlreadyHasOne() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .casual)
        XCTAssertEqual(cleaner.clean("is this working?"), "Is this working?")
    }

    func testVocabularyPreservesCase() {
        let cleaner = TextCleaner(
            vocabulary: vocabulary(["caju ai": "Caju.ai"]),
            profile: .casual
        )
        XCTAssertEqual(cleaner.clean("send caju ai a note"), "Send Caju.ai a note.")
    }

    func testFormalProfileExpandsContractions() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .formal)
        let out = cleaner.clean("i don't think it's working")
        XCTAssertTrue(out.hasPrefix("I"))
        XCTAssertTrue(out.contains("do not"))
        XCTAssertTrue(out.contains("it is"))
    }

    func testCodeProfileTranslatesOperators() {
        let cleaner = TextCleaner(vocabulary: Vocabulary(), profile: .code)
        let out = cleaner.clean("let x equals equals 5")
        XCTAssertTrue(out.contains("=="))
    }
}
