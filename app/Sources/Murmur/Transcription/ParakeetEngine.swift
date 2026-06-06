import Foundation
import FluidAudio

/// NVIDIA Parakeet (parakeet-tdt-0.6b-v3) via FluidAudio. In-process Core ML,
/// runs on the Apple Neural Engine. Loads the AsrManager once and reuses it.
actor ParakeetEngine: TranscriptionEngine {
    private var manager: AsrManager?
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

    /// Loads + caches the AsrManager on first use. The actor serializes calls,
    /// so models load exactly once even under concurrent first-use.
    private func ensureLoaded() async throws -> AsrManager {
        if let manager { return manager }
        let models = try await AsrModels.downloadAndLoad(version: version) { [onDownloadProgress] progress in
            onDownloadProgress?(progress.fractionCompleted)
        }
        let asr = AsrManager(config: .default)
        try await asr.loadModels(models)
        manager = asr
        return asr
    }

    /// Maps Murmur's language code (whisper-style; "" means auto) to FluidAudio's
    /// `Language?`. Returns nil for empty/unknown codes so Parakeet auto-detects.
    static func mapLanguage(_ code: String?) -> Language? {
        guard let code, !code.isEmpty else { return nil }
        return Language(rawValue: code)
    }
}
