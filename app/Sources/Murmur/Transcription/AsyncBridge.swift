import Foundation

/// Runs an async operation to completion from a synchronous context, blocking
/// the CURRENT thread until it finishes. MUST NOT be called on the main thread
/// (it would block the UI). Safe to call from a background DispatchQueue worker
/// thread — those are not Swift-concurrency cooperative threads, so blocking one
/// does not starve the concurrency pool. Used by AppState.runPipeline (already
/// on a background queue) and the headless CLI path.
enum AsyncBridge {
    static func runBlocking<T>(_ operation: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task {
            do { box.result = .success(try await operation()) }
            catch { box.result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.result!.get()
    }
}

private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
