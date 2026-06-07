@testable import Murmur
import XCTest

final class HistoryStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("flowlite-history-\(UUID().uuidString).jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    private func makeStore(enabled: Bool = true, max: Int = 100) -> HistoryStore {
        HistoryStore(enabled: enabled, maxEntries: max, fileURL: tempURL)
    }

    private func ctx() -> AppContext {
        AppContext(name: "TextEdit", bundleID: "com.apple.TextEdit")
    }

    private func waitForWrites() {
        // HistoryStore writes asynchronously; flush by performing a sync read.
        _ = makeStore().loadRecent(limit: 1)
    }

    func testAppendThenLoadReturnsEntry() {
        let store = makeStore()
        store.append(
            cleaned: "Hello world.",
            raw: "hello world",
            target: ctx(),
            durationMs: 500,
            result: "pasted:com.apple.TextEdit"
        )
        // Allow async append to flush.
        Thread.sleep(forTimeInterval: 0.1)
        let entries = store.loadRecent(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cleaned, "Hello world.")
        XCTAssertEqual(entries[0].targetApp, "TextEdit")
        XCTAssertEqual(entries[0].durationMs, 500)
    }

    func testDisabledStoreSkipsWrites() {
        let store = makeStore(enabled: false)
        store.append(cleaned: "nope", raw: "nope", target: ctx(), durationMs: 1, result: "pasted")
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(store.loadRecent(limit: 5).count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }

    func testLoadRecentReturnsNewestFirst() {
        let store = makeStore()
        for idx in 1...3 {
            store.append(cleaned: "entry \(idx)", raw: "raw \(idx)", target: ctx(), durationMs: idx, result: "pasted")
            Thread.sleep(forTimeInterval: 0.05)
        }
        let entries = store.loadRecent(limit: 10)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].cleaned, "entry 3")
        XCTAssertEqual(entries[2].cleaned, "entry 1")
    }

    func testClearRemovesFile() {
        let store = makeStore()
        store.append(cleaned: "tmp", raw: "tmp", target: ctx(), durationMs: 1, result: "pasted")
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
        XCTAssertEqual(store.loadRecent(limit: 10).count, 0)
    }

    func testTrimEnforcesMaxEntries() {
        let store = makeStore(max: 3)
        for idx in 1...10 {
            store.append(cleaned: "e\(idx)", raw: "r\(idx)", target: ctx(), durationMs: idx, result: "pasted")
        }
        Thread.sleep(forTimeInterval: 0.3)
        let entries = store.loadRecent(limit: 100)
        XCTAssertLessThanOrEqual(entries.count, 3)
        // Most recent should be e10.
        XCTAssertEqual(entries[0].cleaned, "e10")
    }
}
