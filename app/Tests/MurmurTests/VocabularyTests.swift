import XCTest
@testable import Murmur

final class VocabularyTests: XCTestCase {
    func test_apply_replacesPhraseCaseInsensitively() {
        var v = Vocabulary()
        v.upsert(from: "API", to: "A P I")
        XCTAssertEqual(v.apply(to: "We hit the api endpoint."), "We hit the A P I endpoint.")
    }

    func test_apply_preservesNonMatchingText() {
        var v = Vocabulary()
        v.upsert(from: "foo", to: "bar")
        XCTAssertEqual(v.apply(to: "nothing here"), "nothing here")
    }

    func test_remove_dropsEntry() {
        var v = Vocabulary()
        v.upsert(from: "x", to: "y")
        v.remove(from: "x")
        XCTAssertEqual(v.entries.count, 0)
    }

    func test_upsert_overwritesExisting() {
        var v = Vocabulary()
        v.upsert(from: "API", to: "A P I")
        v.upsert(from: "api", to: "AY PEE EYE")
        XCTAssertEqual(v.entries.count, 1)
        XCTAssertEqual(v.apply(to: "the API"), "the AY PEE EYE")
    }

    func test_jsonRoundTrip() throws {
        var v = Vocabulary()
        v.upsert(from: "hi", to: "hello")
        v.upsert(from: "API", to: "A P I")
        let data = try JSONEncoder().encode(v)
        let restored = try JSONDecoder().decode(Vocabulary.self, from: data)
        XCTAssertEqual(restored.entries.count, 2)
        XCTAssertEqual(restored.apply(to: "say hi to the API."), "say hello to the A P I.")
    }
}
