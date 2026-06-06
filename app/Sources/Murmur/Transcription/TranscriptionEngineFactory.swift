import Foundation

/// Builds the active transcription engine from Config, selecting between the
/// in-process Parakeet (Core ML / Apple Neural Engine) and out-of-process
/// whisper.cpp backends based on `config.transcriptionEngine`.
enum TranscriptionEngineFactory {
    /// - Parameter onModelDownloadProgress: optional sink for first-use model
    ///   download progress (0...1). Forwarded to `ParakeetEngine`; not applicable
    ///   to whisper.cpp (its model is managed separately).
    static func make(config: Config,
                     onModelDownloadProgress: (@Sendable (Double) -> Void)? = nil) -> any TranscriptionEngine {
        switch config.transcriptionEngine {
        case .parakeet:   return ParakeetEngine(onDownloadProgress: onModelDownloadProgress)
        case .whisperCpp: return WhisperCppEngine(config: config)
        }
    }
}
