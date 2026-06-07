@testable import Murmur
import XCTest

final class ModelManifestTests: XCTestCase {
    func test_bundled_decodesWithoutErrors() throws {
        let manifest = try ModelManifest.bundled()
        XCTAssertGreaterThan(manifest.entries.count, 0)
    }

    func test_everyEntryHasNonEmptyURLAndName() throws {
        let manifest = try ModelManifest.bundled()
        for entry in manifest.entries {
            XCTAssertFalse(entry.name.isEmpty, "name empty for \(entry)")
            XCTAssertFalse(entry.url.absoluteString.isEmpty, "url empty for \(entry.name)")
            XCTAssertFalse(entry.displayName.isEmpty, "displayName empty for \(entry.name)")
            XCTAssertFalse(entry.language.isEmpty, "language empty for \(entry.name)")
            XCTAssertGreaterThan(entry.sizeMB, 0, "sizeMB not positive for \(entry.name)")
        }
    }

    func test_namesAreUnique() throws {
        let manifest = try ModelManifest.bundled()
        XCTAssertEqual(Set(manifest.entries.map(\.name)).count, manifest.entries.count)
    }

    func test_entry_named_returnsMatchingEntry() throws {
        let manifest = try ModelManifest.bundled()
        guard let first = manifest.entries.first else { return XCTFail("no entries") }
        XCTAssertEqual(manifest.entry(named: first.name)?.name, first.name)
        XCTAssertNil(manifest.entry(named: "does-not-exist"))
    }

    func test_bundled_includesBaseEnglish() throws {
        // Sanity: the seeded manifest ships ggml-base.en as the recommended default.
        let manifest = try ModelManifest.bundled()
        XCTAssertNotNil(manifest.entry(named: "ggml-base.en"))
    }
}
