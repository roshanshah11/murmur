// Download + verify + select Whisper models.
//
// Downloads are persisted to AppPaths.modelsDirectory. SHA-256 verification
// is performed when a manifest entry pins a real digest (entries marked
// "PENDING" skip verification — placeholder for pre-launch).
//
// URLSession.download(from:) ships an async variant in Foundation, but it
// has no built-in progress callback. We use a small URLSessionDownloadDelegate
// adapter wrapped in a continuation to expose progress without leaking the
// delegate to callers.
import Foundation
import CryptoKit

@MainActor
public final class ModelManager: ObservableObject {
    @Published public private(set) var installed: Set<String> = []
    @Published public private(set) var downloads: [String: Double] = [:]   // name -> progress 0...1
    @Published public private(set) var lastError: String?

    public let manifest: ModelManifest

    public init(manifest: ModelManifest) {
        self.manifest = manifest
        self.refreshInstalled()
    }

    /// Convenience initializer that loads the manifest bundled with the app.
    /// Falls back to an empty manifest if the resource is missing rather than
    /// crashing the Settings UI; the failure is surfaced via `lastError`.
    public convenience init() {
        do {
            try self.init(manifest: ModelManifest.bundled())
        } catch {
            self.init(manifest: ModelManifest(entries: []))
            self.lastError = "Bundled manifest missing: \(error)"
        }
    }

    public func refreshInstalled() {
        let dir = AppPaths.modelsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        installed = Set(names.compactMap { name in
            name.hasSuffix(".bin") ? String(name.dropLast(4)) : nil
        })
    }

    public func localURL(for entry: ModelManifest.Entry) -> URL {
        AppPaths.modelsDirectory.appendingPathComponent("\(entry.name).bin")
    }

    public func isInstalled(_ name: String) -> Bool { installed.contains(name) }

    /// Download an entry into `AppPaths.modelsDirectory`. Updates `downloads[entry.name]`
    /// from 0...1 as bytes arrive, then verifies SHA-256 (when pinned) before
    /// atomically moving the file into place.
    public func download(_ entry: ModelManifest.Entry,
                          downloader: ModelDownloading = URLSessionModelDownloader(),
                          shaProvider: @escaping (URL) throws -> String = ModelManager.sha256Hex(of:)) async throws {
        downloads[entry.name] = 0
        defer { downloads.removeValue(forKey: entry.name) }

        let tempURL: URL
        do {
            tempURL = try await downloader.download(from: entry.url) { [weak self] progress in
                Task { @MainActor in self?.downloads[entry.name] = progress }
            }
        } catch {
            lastError = "Download failed: \(error)"
            throw ModelManagerError.downloadFailed(String(describing: error))
        }

        if entry.sha256 != "PENDING" {
            let actual: String
            do {
                actual = try shaProvider(tempURL)
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                throw ModelManagerError.writeFailed("hash compute failed: \(error)")
            }
            if actual.lowercased() != entry.sha256.lowercased() {
                try? FileManager.default.removeItem(at: tempURL)
                throw ModelManagerError.shaMismatch(expected: entry.sha256, actual: actual)
            }
        }

        let dest = localURL(for: entry)
        do {
            try FileManager.default.createDirectory(at: AppPaths.modelsDirectory,
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: tempURL, to: dest)
        } catch {
            throw ModelManagerError.writeFailed(String(describing: error))
        }
        refreshInstalled()
    }

    public func delete(_ entry: ModelManifest.Entry) throws {
        let url = localURL(for: entry)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        refreshInstalled()
    }

    /// Returns the lower-case hex SHA-256 digest of the file at `url`.
    /// Streams the file in chunks so multi-GB models don't blow the heap.
    /// `nonisolated` so callers off the main actor (the download adapter)
    /// can invoke it directly without an actor hop.
    public nonisolated static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunk = 1024 * 1024
        while autoreleasepool(invoking: { () -> Bool in
            let data = handle.readData(ofLength: chunk)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Download adapter

/// Abstraction over a single URL download with a progress callback. Lets the
/// download path be unit-tested with a stub.
public protocol ModelDownloading: Sendable {
    func download(from url: URL,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

/// URLSession-backed implementation. Bridges a `URLSessionDownloadDelegate`'s
/// progress callbacks into a single `async throws -> URL` so callers don't
/// have to manage delegate lifetimes.
public final class URLSessionModelDownloader: NSObject, ModelDownloading, URLSessionDownloadDelegate, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private var continuations: [Int: CheckedContinuation<URL, Error>] = [:]
    private var progressCallbacks: [Int: @Sendable (Double) -> Void] = [:]
    private let lock = NSLock()

    public init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    public func download(from url: URL,
                          progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        // A fresh session per download keeps delegate state simple and avoids
        // continuations leaking between concurrent downloads.
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let task = session.downloadTask(with: url)
            lock.lock()
            continuations[task.taskIdentifier] = cont
            progressCallbacks[task.taskIdentifier] = progress
            lock.unlock()
            task.resume()
        }
    }

    // MARK: URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didWriteData bytesWritten: Int64,
                            totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        lock.lock()
        let cb = progressCallbacks[downloadTask.taskIdentifier]
        lock.unlock()
        cb?(min(1.0, max(0.0, fraction)))
    }

    public func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didFinishDownloadingTo location: URL) {
        // Move the file out of the system temp dir; URLSession deletes the
        // original as soon as this delegate returns.
        let tmpDir = FileManager.default.temporaryDirectory
        let destination = tmpDir.appendingPathComponent("murmur-model-\(UUID().uuidString).bin")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            lock.lock()
            let cont = continuations.removeValue(forKey: downloadTask.taskIdentifier)
            progressCallbacks.removeValue(forKey: downloadTask.taskIdentifier)
            lock.unlock()
            cont?.resume(throwing: error)
            return
        }
        lock.lock()
        let cont = continuations.removeValue(forKey: downloadTask.taskIdentifier)
        progressCallbacks.removeValue(forKey: downloadTask.taskIdentifier)
        lock.unlock()
        cont?.resume(returning: destination)
    }

    public func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didCompleteWithError error: Error?) {
        guard let error else { return }
        lock.lock()
        let cont = continuations.removeValue(forKey: task.taskIdentifier)
        progressCallbacks.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        cont?.resume(throwing: error)
    }
}
