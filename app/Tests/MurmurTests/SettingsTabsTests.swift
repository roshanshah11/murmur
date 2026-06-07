@testable import Murmur
import XCTest

final class SettingsTabsTests: XCTestCase {
    func test_allTabsHaveDistinctSystemImages() {
        let images = SettingsTab.allCases.map(\.systemImage)
        XCTAssertEqual(Set(images).count, SettingsTab.allCases.count)
    }

    func test_allTabsHaveRawValueMatchingId() {
        for tab in SettingsTab.allCases {
            XCTAssertEqual(tab.id, tab.rawValue)
        }
    }

    func test_settingsTabRawValueRoundTrip() {
        for tab in SettingsTab.allCases {
            XCTAssertEqual(SettingsTab(rawValue: tab.rawValue), tab)
        }
    }
}
