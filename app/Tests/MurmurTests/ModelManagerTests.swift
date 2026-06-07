import CryptoKit
@testable import Murmur
import XCTest

@MainActor
final class ModelManagerTests: XCTestCase {
    private func makeEntry(name: String = "ggml-base.en",
                           sha256: String = "PENDING") throws -> ModelManifest.Entry {
        ModelManifest.Entry(
            name: name,
            displayName: "Base",
            sizeMB: 142,
            url: try XCTUnwrap(URL(string: "https://example.com/\(name).bin")),
            sha256: sha256,
            language: "en",
            notes: "",
            recommendedFor: []
        )
    }

    func test_isInstalled_returnsFalse_whenModelMissing() throws {
        let manager = ModelManager(manifest: ModelManifest(entries: []))
        XCTAssertFalse(manager.isInstalled("does-not-exist"))
    }

    func test_localURL_isUnderAppSupportModels() throws {
        let manager = ModelManager(manifest: ModelManifest(entries: []))
        let entry = try makeEntry()
        let url = manager.localURL(for: entry)
        XCTAssertTrue(
            url.path.contains("Application Support/Murmur/Models"),
            "expected models path under App Support; got \(url.path)"
        )
        XCTAssertEqual(url.lastPathComponent, "ggml-base.en.bin")
    }

    func test_refreshInstalled_findsPlacedFiles() throws {
        let dir = AppPaths.modelsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fake = dir.appendingPathComponent("ggml-test-fake.bin")
        try Data().write(to: fake)
        defer { try? FileManager.default.removeItem(at: fake) }

        let manager = ModelManager(manifest: ModelManifest(entries: []))
        XCTAssertTrue(manager.installed.contains("ggml-test-fake"))
    }

    func test_delete_removesFileAndUpdatesInstalled() throws {
        let dir = AppPaths.modelsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let entry = try makeEntry(name: "ggml-test-delete")
        let fake = dir.appendingPathComponent("\(entry.name).bin")
        try Data().write(to: fake)
        defer { try? FileManager.default.removeItem(at: fake) }

        let manager = ModelManager(manifest: ModelManifest(entries: [entry]))
        XCTAssertTrue(manager.isInstalled(entry.name))
        try manager.delete(entry)
        XCTAssertFalse(manager.isInstalled(entry.name))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fake.path))
    }

    func test_sha256Hex_matchesCryptoKit() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-sha-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let payload = Data("hello murmur".utf8)
        try payload.write(to: tmp)

        let expected = SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(try ModelManager.sha256Hex(of: tmp), expected)
    }

    // MARK: - download() with stub

    private struct StubDownloader: ModelDownloading {
        let payload: Data
        let progressSteps: [Double]
        func download(from url: URL,
                      progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            for step in progressSteps { progress(step) }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("stub-\(UUID().uuidString).bin")
            try payload.write(to: tmp)
            return tmp
        }
    }

    func test_download_movesFileIntoModelsDirectory_andMarksInstalled() async throws {
        // Use a unique entry name so we don't collide with real installed models.
        let entry = try makeEntry(name: "ggml-test-download-\(UUID().uuidString.prefix(8))")
        let manager = ModelManager(manifest: ModelManifest(entries: [entry]))
        let stub = StubDownloader(payload: Data("fake model bytes".utf8),
                                  progressSteps: [0.25, 0.5, 1.0])

        try await manager.download(entry, downloader: stub)
        defer { try? manager.delete(entry) }

        XCTAssertTrue(manager.isInstalled(entry.name))
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.localURL(for: entry).path))
        XCTAssertNil(manager.downloads[entry.name], "progress entry should be cleared after completion")
    }

    func test_download_shaMismatch_deletesTempAndThrows() async throws {
        let entry = try makeEntry(
            name: "ggml-test-sha-\(UUID().uuidString.prefix(8))",
            sha256: "00000000000000000000000000000000000000000000000000000000deadbeef"
        )
        let manager = ModelManager(manifest: ModelManifest(entries: [entry]))
        let stub = StubDownloader(payload: Data("wrong bytes".utf8), progressSteps: [1.0])

        do {
            try await manager.download(entry, downloader: stub)
            XCTFail("expected SHA mismatch to throw")
        } catch ModelManagerError.shaMismatch {
            // expected
        } catch {
            XCTFail("expected shaMismatch, got \(error)")
        }
        XCTAssertFalse(manager.isInstalled(entry.name))
    }
}
