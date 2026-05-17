import XCTest
@testable import Murmur

final class PromptLibraryTests: XCTestCase {
    func test_raw_returnsInputUntouched() {
        XCTAssertEqual(
            PromptLibrary.Profile.raw.apply(to: "  um like  hello "),
            "  um like  hello "
        )
    }

    func test_casual_stripsFillersAndAddsTerminalPunctuation() {
        let out = PromptLibrary.Profile.casual.apply(to: "um, like, hello there")
        XCTAssertFalse(out.contains("um"))
        XCTAssertFalse(out.contains("like"))
        XCTAssertEqual(out.last, ".")
    }

    func test_formal_expandsContractionsAndCapitalizes() {
        let out = PromptLibrary.Profile.formal.apply(to: "i don't know what they're doing")
        XCTAssertTrue(out.hasPrefix("I"))
        XCTAssertTrue(out.contains("do not"))
        XCTAssertTrue(out.contains("they are"))
    }

    func test_code_translatesSpokenOperators() {
        let out = PromptLibrary.Profile.code.apply(to: "let x equals equals 5")
        XCTAssertTrue(out.contains("=="))
    }

    func test_code_handlesArrowAndNotEquals() {
        let out = PromptLibrary.Profile.code.apply(to: "if x not equals y then arrow z")
        XCTAssertTrue(out.contains("!="))
        XCTAssertTrue(out.contains("->"))
    }
}
