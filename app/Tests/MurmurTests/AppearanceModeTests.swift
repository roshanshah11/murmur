import AppKit
import XCTest
@testable import Murmur

final class AppearanceModeTests: XCTestCase {
    func test_nsAppearance_mapping() {
        XCTAssertNil(AppearanceMode.auto.nsAppearance, "auto must follow the system (nil)")
        XCTAssertEqual(AppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppearanceMode.dark.nsAppearance?.name, .darkAqua)
    }

    func test_allCases_andLabels() {
        XCTAssertEqual(AppearanceMode.allCases, [.auto, .light, .dark])
        XCTAssertEqual(AppearanceMode.auto.label, "Auto")
        XCTAssertEqual(AppearanceMode.light.label, "Light")
        XCTAssertEqual(AppearanceMode.dark.label, "Dark")
    }

    func test_defaultConfig_appearanceIsAuto() {
        XCTAssertEqual(Config.defaultConfig().appearance, .auto)
    }

    func test_config_roundTripsAppearance() throws {
        var cfg = Config.defaultConfig()
        cfg.appearance = .dark
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.appearance, .dark)
    }

    /// Backward-compat guard: a config written before the `appearance` key
    /// existed must decode to `.auto`, not fail. Mirrors the
    /// transcriptionEngine missing-key test.
    func test_appearance_defaultsToAuto_whenKeyMissing() throws {
        let fullData = try JSONEncoder().encode(Config.defaultConfig())
        var dict = try JSONSerialization.jsonObject(with: fullData) as! [String: Any]
        dict.removeValue(forKey: "appearance")
        let stripped = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(Config.self, from: stripped)
        XCTAssertEqual(decoded.appearance, .auto, "missing appearance key must decode to .auto")
    }
}
