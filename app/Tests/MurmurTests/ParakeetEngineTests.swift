import XCTest
import FluidAudio
@testable import Murmur

/// Unit tests for ParakeetEngine's pure language-code mapping. The model load
/// and transcription paths are network/disk-heavy and are intentionally NOT
/// exercised here; they are covered by a separate end-to-end verification task.
final class ParakeetEngineTests: XCTestCase {
    func testMapsKnownCodeToMatchingLanguage() {
        XCTAssertEqual(ParakeetEngine.mapLanguage("en")?.rawValue, "en")
        XCTAssertEqual(ParakeetEngine.mapLanguage("en"), .english)
    }

    func testMapsFrenchCode() {
        XCTAssertEqual(ParakeetEngine.mapLanguage("fr"), .french)
    }

    func testEmptyCodeMapsToNilForAutoDetect() {
        XCTAssertNil(ParakeetEngine.mapLanguage(""))
    }

    func testNilCodeMapsToNil() {
        XCTAssertNil(ParakeetEngine.mapLanguage(nil))
    }

    func testInvalidCodeMapsToNil() {
        XCTAssertNil(ParakeetEngine.mapLanguage("zz"))
    }
}
