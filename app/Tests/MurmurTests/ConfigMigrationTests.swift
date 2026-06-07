// swiftlint:disable banned_flowlite
// legitimate legacy ~/.flow-lite migration path (mirrors the CI grep allowlist)
@testable import Murmur
import XCTest

final class ConfigMigrationTests: XCTestCase {
    var sandbox: URL!
    var legacyDir: URL!
    var newDir: URL!

    override func setUp() {
        super.setUp()
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-migration-\(UUID().uuidString)")
        legacyDir = sandbox.appendingPathComponent(".flow-lite")
        newDir = sandbox.appendingPathComponent("AppSupport/Murmur")
        try? FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: sandbox)
        super.tearDown()
    }

    func test_migrate_copiesConfigAndHistory_whenLegacyExistsAndNewDoesNot() throws {
        let configData = Data(#"{"version":1}"#.utf8)
        let historyData = Data("{\"ts\":1,\"text\":\"hello\"}\n".utf8)
        try configData.write(to: legacyDir.appendingPathComponent("config.json"))
        try historyData.write(to: legacyDir.appendingPathComponent("history.jsonl"))
        try ConfigMigration.migrate(legacy: legacyDir, destination: newDir)
        XCTAssertEqual(try Data(contentsOf: newDir.appendingPathComponent("config.json")), configData)
        XCTAssertEqual(try Data(contentsOf: newDir.appendingPathComponent("history.jsonl")), historyData)
    }

    func test_migrate_writesMarkerInLegacyDirectory() throws {
        try Data().write(to: legacyDir.appendingPathComponent("config.json"))
        try ConfigMigration.migrate(legacy: legacyDir, destination: newDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            legacyDir.appendingPathComponent(".migrated").path))
    }

    func test_migrate_isNoOp_whenDestinationAlreadyHasConfig() throws {
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        let existing = Data(#"{"version":2}"#.utf8)
        try existing.write(to: newDir.appendingPathComponent("config.json"))
        try Data(#"{"version":1}"#.utf8).write(to: legacyDir.appendingPathComponent("config.json"))
        try ConfigMigration.migrate(legacy: legacyDir, destination: newDir)
        XCTAssertEqual(try Data(contentsOf: newDir.appendingPathComponent("config.json")), existing)
    }
}
// swiftlint:enable banned_flowlite
