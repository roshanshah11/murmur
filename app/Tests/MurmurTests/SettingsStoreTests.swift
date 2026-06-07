import Combine
@testable import Murmur
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {
    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-settings-\(UUID().uuidString).json")
    }

    func test_load_initialisesFromDisk_orDefault() throws {
        // Case A: no file on disk → fall back to defaults.
        let url = tempURL()
        let store = SettingsStore(configURL: url, debounceMs: 50)
        XCTAssertEqual(store.config.activeProfile, Config.defaultConfig().activeProfile,
                       "missing file must yield default config")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "constructing the store must not write a file by itself")

        // Case B: a config file already exists → load it verbatim.
        var preexisting = Config.defaultConfig()
        preexisting.activeProfile = .formal
        preexisting.language = "es"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preexisting).write(to: url)

        let store2 = SettingsStore(configURL: url, debounceMs: 50)
        XCTAssertEqual(store2.config.activeProfile, .formal)
        XCTAssertEqual(store2.config.language, "es")
    }

    func test_update_debouncesWrites_thenPostsNotification() throws {
        let url = tempURL()
        let store = SettingsStore(configURL: url, debounceMs: 80)

        let saveExpectation = expectation(description: "save fires after debounce")
        store.onSave = { saveExpectation.fulfill() }

        let notifExpectation = expectation(description: "config-updated notification posts")
        let token = NotificationCenter.default.addObserver(
            forName: .murmurConfigUpdated, object: nil, queue: .main
        ) { _ in
            notifExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        store.update(\.activeProfile, to: .code)

        // Before debounce elapses the in-memory mirror should already
        // reflect the change.
        XCTAssertEqual(store.config.activeProfile, .code)

        wait(for: [saveExpectation, notifExpectation], timeout: 1.0)

        // Round-trip from disk to prove the write landed.
        let data = try Data(contentsOf: url)
        let onDisk = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(onDisk.activeProfile, .code)
    }

    func test_concurrentUpdates_collapseToOneSave() throws {
        let url = tempURL()
        let store = SettingsStore(configURL: url, debounceMs: 80)

        var saveCount = 0
        let done = expectation(description: "save fires once for a burst")
        done.assertForOverFulfill = false
        store.onSave = {
            saveCount += 1
            done.fulfill()
        }

        // Rapid burst — all five mutations must coalesce into one disk write.
        store.update(\.activeProfile, to: .casual)
        store.update(\.activeProfile, to: .formal)
        store.update(\.activeProfile, to: .code)
        store.update(\.language, to: "fr")
        store.update(\.activeProfile, to: .raw)

        wait(for: [done], timeout: 1.0)

        // Give the run loop one more tick to prove no extra save sneaks in.
        let settle = expectation(description: "post-burst quiet period")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { settle.fulfill() }
        wait(for: [settle], timeout: 0.5)

        XCTAssertEqual(saveCount, 1, "rapid updates must coalesce into a single save")

        let onDisk = try JSONDecoder().decode(Config.self, from: try Data(contentsOf: url))
        XCTAssertEqual(onDisk.activeProfile, .raw, "last write wins for the same key")
        XCTAssertEqual(onDisk.language, "fr")
    }
}
