@testable import Murmur
import XCTest

/// Decision logic of `OnboardingWindowController.shouldShow(for:)`. The
/// real `openIfNeeded()` is left untested because it has an AppKit side
/// effect (spawns a window) that's awkward to assert in a headless test
/// runner. The pure-decision helper covers the only logic that matters.
@MainActor
final class OnboardingWindowControllerTests: XCTestCase {
    func test_shouldShow_whenVersionMissing() {
        var config = Config.defaultConfig()
        config.onboardingCompletedVersion = nil
        XCTAssertTrue(OnboardingWindowController.shouldShow(for: config),
                      "first launch (no version stamp) must trigger the wizard")
    }

    func test_shouldShow_whenVersionMismatch() {
        var config = Config.defaultConfig()
        config.onboardingCompletedVersion = "0.9"
        XCTAssertTrue(OnboardingWindowController.shouldShow(for: config),
                      "outdated completion stamp must re-trigger the wizard")
    }

    func test_shouldNotShow_whenVersionMatches() {
        var config = Config.defaultConfig()
        config.onboardingCompletedVersion = OnboardingWindowController.currentVersion
        XCTAssertFalse(OnboardingWindowController.shouldShow(for: config),
                       "completed wizard must not re-open on subsequent launches")
    }

    func test_currentVersion_isOnePointZero() {
        // Locked because the gate decision in main.swift depends on this
        // exact string. Bumping it is intentional + must be a deliberate
        // change in this test.
        XCTAssertEqual(OnboardingWindowController.currentVersion, "1.0")
    }
}
