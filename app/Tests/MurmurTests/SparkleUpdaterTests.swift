import XCTest
@testable import Murmur

@MainActor
final class SparkleUpdaterTests: XCTestCase {
    func test_sharedExists() {
        XCTAssertNotNil(SparkleUpdater.shared)
    }

    func test_automaticallyChecksForUpdates_canBeToggled() {
        let current = SparkleUpdater.shared.automaticallyChecksForUpdates
        SparkleUpdater.shared.automaticallyChecksForUpdates = !current
        XCTAssertEqual(SparkleUpdater.shared.automaticallyChecksForUpdates, !current)
        // restore
        SparkleUpdater.shared.automaticallyChecksForUpdates = current
    }
}
