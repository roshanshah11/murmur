import XCTest
@testable import Murmur

final class ModelManifestTests: XCTestCase {
    func test_bundled_decodesWithoutErrors() throws {
        let m = try ModelManifest.bundled()
        XCTAssertGreaterThan(m.entries.count, 0)
    }

    func test_everyEntryHasNonEmptyURLAndName() throws {
        let m = try ModelManifest.bundled()
        for e in m.entries {
            XCTAssertFalse(e.name.isEmpty, "name empty for \(e)")
            XCTAssertFalse(e.url.absoluteString.isEmpty, "url empty for \(e.name)")
            XCTAssertFalse(e.displayName.isEmpty, "displayName empty for \(e.name)")
            XCTAssertFalse(e.language.isEmpty, "language empty for \(e.name)")
            XCTAssertGreaterThan(e.sizeMB, 0, "sizeMB not positive for \(e.name)")
        }
    }

    func test_namesAreUnique() throws {
        let m = try ModelManifest.bundled()
        XCTAssertEqual(Set(m.entries.map(\.name)).count, m.entries.count)
    }

    func test_entry_named_returnsMatchingEntry() throws {
        let m = try ModelManifest.bundled()
        guard let first = m.entries.first else { return XCTFail("no entries") }
        XCTAssertEqual(m.entry(named: first.name)?.name, first.name)
        XCTAssertNil(m.entry(named: "does-not-exist"))
    }

    func test_bundled_includesBaseEnglish() throws {
        // Sanity: the seeded manifest ships ggml-base.en as the recommended default.
        let m = try ModelManifest.bundled()
        XCTAssertNotNil(m.entry(named: "ggml-base.en"))
    }
}
