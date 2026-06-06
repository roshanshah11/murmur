import Foundation
import FluidAudio

/// NVIDIA Parakeet (parakeet-tdt-0.6b-v3) via FluidAudio. In-process Core ML,
/// runs on the Apple Neural Engine. Loads the AsrManager once and reuses it.
actor ParakeetEngine: TranscriptionEngine {
    private var manager: AsrManager?
    /// In-flight load, shared across concurrent first-use callers so the model
    /// loads exactly once. Actors are re-entrant across `await`, so a bare
    /// `if let manager` check is NOT enough: two callers (e.g. the launch
    /// preload racing the user's first dictation) could both pass it before
    /// either sets `manager`. Single-flighting through one Task closes that gap.
    private var loadTask: Task<AsrManager, Error>?
    private let version: AsrModelVersion = .v3
    /// Optional sink for model-download progress (0...1). Wired by the download
    /// UX layer; nil for headless/CLI use. Invoked on an arbitrary thread.
    private let onDownloadProgress: (@Sendable (Double) -> Void)?

    init(onDownloadProgress: (@Sendable (Double) -> Void)? = nil) {
        self.onDownloadProgress = onDownloadProgress
    }

    func prepare() async throws { _ = try await ensureLoaded() }

    func transcribe(wavURL: URL, language: String?) async throws -> String {
        let asr = try await ensureLoaded()
        var state = try TdtDecoderState()
        let result = try await asr.transcribe(wavURL, decoderState: &state,
                                              language: Self.mapLanguage(language))
        return result.text
    }

    /// Loads + caches the AsrManager on first use, single-flighted so concurrent
    /// first callers share one download+load. Subsequent calls return the cached
    /// manager immediately. On failure the in-flight task is cleared so the next
    /// call retries.
    private func ensureLoaded() async throws -> AsrManager {
        if let manager { return manager }
        if let loadTask { return try await loadTask.value }

        let version = self.version
        let onDownloadProgress = self.onDownloadProgress
        let task = Task { () throws -> AsrManager in
            let models = try await AsrModels.downloadAndLoad(version: version) { progress in
                onDownloadProgress?(progress.fractionCompleted)
            }
            let asr = AsrManager(config: .default)
            try await asr.loadModels(models)
            return asr
        }
        loadTask = task
        do {
            let asr = try await task.value
            manager = asr
            loadTask = nil
            return asr
        } catch {
            loadTask = nil
            throw error
        }
    }

    /// Maps Murmur's language code (whisper-style; "" means auto) to FluidAudio's
    /// `Language?`. Returns nil for empty/unknown codes so Parakeet auto-detects.
    static func mapLanguage(_ code: String?) -> Language? {
        guard let code, !code.isEmpty else { return nil }
        return Language(rawValue: code)
    }
}
