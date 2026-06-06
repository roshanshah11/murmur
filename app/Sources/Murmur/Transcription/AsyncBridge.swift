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
        switch box.result {
        case .success(let value): return value
        case .failure(let error): throw error
        case nil: preconditionFailure("AsyncBridge: Task exited without setting a result — programmer error")
        }
    }
}

/// Access is serialized by the semaphore: the Task writes `result` before
/// `signal()`, and the caller reads it only after `wait()` returns. No
/// concurrent access is possible, so `@unchecked Sendable` is sound here.
private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
