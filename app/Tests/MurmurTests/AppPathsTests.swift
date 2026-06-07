// swiftlint:disable banned_flowlite
// legitimate legacy ~/.flow-lite migration path (mirrors the CI grep allowlist)
@testable import Murmur
import XCTest

final class AppPathsTests: XCTestCase {
    func test_appSupportDirectory_isUnderLibrary() {
        let url = AppPaths.appSupportDirectory
        XCTAssertTrue(url.path.contains("Library/Application Support/Murmur"))
    }
    func test_logsDirectory_isUnderLibraryLogs() {
        XCTAssertTrue(AppPaths.logsDirectory.path.contains("Library/Logs/Murmur"))
    }
    func test_cachesDirectory_isUnderLibraryCaches() {
        XCTAssertTrue(AppPaths.cachesDirectory.path.contains("Library/Caches/Murmur"))
    }
    func test_modelsDirectory_isUnderAppSupport() {
        XCTAssertEqual(
            AppPaths.modelsDirectory.deletingLastPathComponent(),
            AppPaths.appSupportDirectory
        )
    }
    func test_legacyFlowLiteDirectory_pointsAtDotFlowLite() {
        XCTAssertTrue(AppPaths.legacyFlowLiteDirectory.path.hasSuffix("/.flow-lite"))
    }
}
// swiftlint:enable banned_flowlite
