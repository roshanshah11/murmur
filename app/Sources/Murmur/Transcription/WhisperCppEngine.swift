import Foundation

/// whisper.cpp engine: shells out to a bundled whisper-cli subprocess.
/// Out-of-process. Wraps WhisperRunner unchanged.
final class WhisperCppEngine: TranscriptionEngine {
    private let runner: WhisperRunner
    init(config: Config) { self.runner = WhisperRunner(config: config) }

    func prepare() async throws { try runner.validateSetup() }

    func transcribe(wavURL: URL, language: String?) async throws -> String {
        // Honor the protocol's language hint when provided; WhisperRunner falls
        // back to config.language when it's nil, preserving prior behavior.
        try runner.transcribe(audioURL: wavURL, language: language)
    }
}
