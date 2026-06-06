import Foundation

/// Builds the active transcription engine from Config, selecting between the
/// in-process Parakeet (Core ML / Apple Neural Engine) and out-of-process
/// whisper.cpp backends based on `config.transcriptionEngine`.
enum TranscriptionEngineFactory {
    static func make(config: Config) -> any TranscriptionEngine {
        switch config.transcriptionEngine {
        case .parakeet:   return ParakeetEngine()
        case .whisperCpp: return WhisperCppEngine(config: config)
        }
    }
}
