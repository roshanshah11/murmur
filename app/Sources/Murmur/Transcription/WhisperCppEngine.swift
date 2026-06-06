import Foundation

/// whisper.cpp engine: shells out to a bundled whisper-cli subprocess.
/// Out-of-process. Wraps WhisperRunner unchanged.
final class WhisperCppEngine: TranscriptionEngine {
    private let runner: WhisperRunner
    init(config: Config) { self.runner = WhisperRunner(config: config) }

    func prepare() async throws { try runner.validateSetup() }

    func transcribe(wavURL: URL, language: String?) async throws -> String {
        // language is intentionally ignored: WhisperRunner reads config.language,
        // preserving the pre-refactor behavior verbatim.
        try runner.transcribe(audioURL: wavURL)
    }
}
