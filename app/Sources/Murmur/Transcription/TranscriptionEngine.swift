import Foundation

/// A pluggable speech-to-text backend. Implementations encapsulate ALL
/// engine-specific logic (subprocess management, model loading, etc.); the
/// dictation pipeline only ever sees the returned String.
protocol TranscriptionEngine {
    /// Transcribe a 16 kHz mono WAV file to text.
    /// - Parameter language: BCP-47-ish hint (e.g. "en"); nil = auto / engine default.
    func transcribe(wavURL: URL, language: String?) async throws -> String
    /// Preload models / validate setup once at launch or first use. Default no-op.
    func prepare() async throws
}

extension TranscriptionEngine {
    func prepare() async throws {}
}
