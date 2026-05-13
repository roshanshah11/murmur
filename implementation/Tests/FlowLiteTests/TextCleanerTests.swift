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

    func testKindOfPreserved() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("kind of nice and warm"), "Kind of nice and warm.")
    }

    func testSortOfPreserved() {
        // "sort of" must be preserved (carries meaning). Leading-"like" strip only
        // fires when "like" is at the very start of the input, so it does not apply
        // here — "sort" is first. Result keeps the full phrase verbatim.
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("sort of like a draft document"), "Sort of like a draft document.")
    }

    func testNoPunctuationForShortFragment() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("buy milk"), "Buy milk")
    }

    func testNoPunctuationWhenAlreadyHasOne() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [:])
        XCTAssertEqual(cleaner.clean("is this working?"), "Is this working?")
    }

    func testVocabularyPreservesCase() {
        let cleaner = TextCleaner(rawTranscriptMode: false, customVocabulary: [
            "caju ai": "Caju.ai"
        ])
        XCTAssertEqual(cleaner.clean("send caju ai a note"), "Send Caju.ai a note.")
    }
}
