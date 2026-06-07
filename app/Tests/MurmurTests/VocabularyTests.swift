@testable import Murmur
import XCTest

final class VocabularyTests: XCTestCase {
    func test_apply_replacesPhraseCaseInsensitively() {
        var vocab = Vocabulary()
        vocab.upsert(from: "API", to: "A P I")
        XCTAssertEqual(vocab.apply(to: "We hit the api endpoint."), "We hit the A P I endpoint.")
    }

    func test_apply_preservesNonMatchingText() {
        var vocab = Vocabulary()
        vocab.upsert(from: "foo", to: "bar")
        XCTAssertEqual(vocab.apply(to: "nothing here"), "nothing here")
    }

    func test_remove_dropsEntry() {
        var vocab = Vocabulary()
        vocab.upsert(from: "x", to: "y")
        vocab.remove(from: "x")
        XCTAssertEqual(vocab.entries.count, 0)
    }

    func test_upsert_overwritesExisting() {
        var vocab = Vocabulary()
        vocab.upsert(from: "API", to: "A P I")
        vocab.upsert(from: "api", to: "AY PEE EYE")
        XCTAssertEqual(vocab.entries.count, 1)
        XCTAssertEqual(vocab.apply(to: "the API"), "the AY PEE EYE")
    }

    func test_jsonRoundTrip() throws {
        var vocab = Vocabulary()
        vocab.upsert(from: "hi", to: "hello")
        vocab.upsert(from: "API", to: "A P I")
        let data = try JSONEncoder().encode(vocab)
        let restored = try JSONDecoder().decode(Vocabulary.self, from: data)
        XCTAssertEqual(restored.entries.count, 2)
        XCTAssertEqual(restored.apply(to: "say hi to the API."), "say hello to the A P I.")
    }
}
