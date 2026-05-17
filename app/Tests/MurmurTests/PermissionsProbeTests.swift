import XCTest
@testable import Murmur

/// Permission probes are observational only — the tests can't assert that
/// the host's TCC database holds a particular value (CI runners vary, and
/// dev machines have whatever the engineer set up). Instead, each test
/// verifies the probe returns a well-formed value and doesn't crash.
@MainActor
final class PermissionsProbeTests: XCTestCase {
    func test_microphone_neverThrows_andReturnsKnownStatus() {
        let status = PermissionsProbe.microphone()
        XCTAssertTrue(
            [.notDetermined, .granted, .denied].contains(status),
            "microphone() returned an unexpected status: \(status)"
        )
    }

    func test_accessibility_returnsKnownStatus() {
        let status = PermissionsProbe.accessibility()
        // Test binary will almost always be `.denied` (AX isn't granted to
        // xctest), but we don't assert one or the other — only that the
        // raw value is well-formed and the probe terminated without
        // tripping the prompt sheet (which would require manual dismissal
        // on a developer machine).
        XCTAssertTrue(
            [.granted, .denied].contains(status),
            "accessibility() returned an unexpected status: \(status)"
        )
    }

    func test_openAccessibilitySettings_doesNotCrash() {
        // Smoke test only. NSWorkspace.open may or may not actually open
        // the pane under XCTest (xctest is not the foreground app and
        // System Settings may be sandboxed off), but it must not crash.
        PermissionsProbe.openAccessibilitySettings()
    }

    func test_permissionStatus_rawValuesAreStable() {
        // Lock the rawValues so future renames don't silently break any
        // log/event consumer reading `.rawValue`.
        XCTAssertEqual(PermissionStatus.notDetermined.rawValue, "notDetermined")
        XCTAssertEqual(PermissionStatus.granted.rawValue, "granted")
        XCTAssertEqual(PermissionStatus.denied.rawValue, "denied")
    }
}
