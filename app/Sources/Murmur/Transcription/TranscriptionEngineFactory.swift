import Foundation

/// Builds the active transcription engine from Config. Whisper-only for now;
/// a later task adds Parakeet selection based on a new Config field.
enum TranscriptionEngineFactory {
    static func make(config: Config) -> any TranscriptionEngine {
        WhisperCppEngine(config: config)
    }
}
