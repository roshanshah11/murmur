import XCTest
@testable import Murmur

/// Coverage for the `--transcribe-only` argv parser. Each test feeds a
/// realistic argv (executable name in position 0 so `CLI.parse`'s
/// `dropFirst()` lines up) and asserts on the destructured `CLIMode`
/// associated values.
final class CLIParseTests: XCTestCase {

    // MARK: helpers

    /// Pull the five override slots out of a `CLIMode` we expect to be
    /// `.transcribeOnly`. Fails the test with a clear message otherwise so
    /// downstream assertions don't have to repeat the guard.
    private func unwrapTranscribeOnly(
        _ mode: CLIMode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (URL, PromptLibrary.Profile?, String?, String?, URL?)? {
        guard case let .transcribeOnly(wav, profile, language, modelName, vocabularyURL) = mode else {
            XCTFail("expected .transcribeOnly, got \(mode)", file: file, line: line)
            return nil
        }
        return (wav, profile, language, modelName, vocabularyURL)
    }

    // MARK: minimal invocation

    func test_transcribeOnly_minimal_wavOnly() throws {
        let mode = try CLI.parse(["Murmur", "--transcribe-only", "/tmp/foo.wav"])
        guard let (wav, profile, language, modelName, vocabularyURL) = unwrapTranscribeOnly(mode) else { return }
        XCTAssertEqual(wav.path, "/tmp/foo.wav")
        XCTAssertNil(profile)
        XCTAssertNil(language)
        XCTAssertNil(modelName)
        XCTAssertNil(vocabularyURL)
    }

    // MARK: individual flag plumbing

    func test_transcribeOnly_acceptsProfileFlag() throws {
        let mode = try CLI.parse([
            "Murmur", "--transcribe-only", "/tmp/foo.wav",
            "--profile", "code"
        ])
        guard let (_, profile, _, _, _) = unwrapTranscribeOnly(mode) else { return }
        XCTAssertEqual(profile, .code)
    }

    func test_transcribeOnly_acceptsLanguageFlag() throws {
        let mode = try CLI.parse([
            "Murmur", "--transcribe-only", "/tmp/foo.wav",
            "--language", "es"
        ])
        guard let (_, _, language, _, _) = unwrapTranscribeOnly(mode) else { return }
        XCTAssertEqual(language, "es")
    }

    func test_transcribeOnly_acceptsModelFlag() throws {
        let mode = try CLI.parse([
            "Murmur", "--transcribe-only", "/tmp/foo.wav",
            "--model", "ggml-base.en"
        ])
        guard let (_, _, _, modelName, _) = unwrapTranscribeOnly(mode) else { return }
        XCTAssertEqual(modelName, "ggml-base.en")
    }

    func test_transcribeOnly_acceptsVocabularyPath() throws {
        let mode = try CLI.parse([
            "Murmur", "--transcribe-only", "/tmp/foo.wav",
            "--vocabulary", "/tmp/v.json"
        ])
        guard let (_, _, _, _, vocabularyURL) = unwrapTranscribeOnly(mode) else { return }
        XCTAssertEqual(vocabularyURL?.path, "/tmp/v.json")
    }

    // MARK: error path

    func test_transcribeOnly_unknownFlag_throwsCLIError() {
        XCTAssertThrowsError(
            try CLI.parse(["Murmur", "--transcribe-only", "/tmp/foo.wav", "--bogus"])
        ) { error in
            guard let cliError = error as? CLIError else {
                XCTFail("expected CLIError, got \(type(of: error)): \(error)")
                return
            }
            XCTAssertEqual(cliError, .unknownFlag("--bogus"))
        }
    }

    // MARK: documentation

    /// The `--help` output is the only place users discover the new flags,
    /// so guard against silent drift between the implementation and the
    /// docstring shown via `Murmur --help`.
    func test_help_mentionsAllNewFlags() throws {
        let mode = try CLI.parse(["Murmur", "--help"])
        XCTAssertEqual(mode, .help)

        let help = CLI.helpText
        XCTAssertTrue(help.contains("--profile"),    "help text missing --profile: \(help)")
        XCTAssertTrue(help.contains("--language"),   "help text missing --language: \(help)")
        XCTAssertTrue(help.contains("--model"),      "help text missing --model: \(help)")
        XCTAssertTrue(help.contains("--vocabulary"), "help text missing --vocabulary: \(help)")
    }
}
