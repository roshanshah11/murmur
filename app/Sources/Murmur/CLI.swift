import Foundation

enum CLIMode: Equatable {
    case ui
    case transcribeOnly(wavURL: URL, profile: PromptLibrary.Profile?, language: String?, modelName: String?, vocabularyURL: URL?)
    case recordOnce
    case help
    case version
}

public enum CLIError: Error, LocalizedError, Equatable {
    case unknownFlag(String)
    case missingValue(String)
    case unknownProfile(String)

    public var errorDescription: String? {
        switch self {
        case .unknownFlag(let flag):
            return "Unknown flag: \(flag)"
        case .missingValue(let flag):
            return "Missing value for flag: \(flag)"
        case .unknownProfile(let raw):
            return "Unknown profile '\(raw)'. Valid values: raw, casual, formal, code."
        }
    }
}

enum CLI {
    /// Help text shown for `--help`. Exposed as a static constant so tests
    /// can assert that documentation for new flags is present without
    /// having to capture stdout.
    static let helpText: String = """
    Murmur — local-first macOS dictation utility.

    Usage:
      Murmur                            Launch menubar UI (default).
      Murmur --transcribe-only <wav> [--profile P] [--language L] [--model M] [--vocabulary V]
          Headless transcribe. Optional overrides skip the on-disk Config:
            --profile     raw | casual | formal | code
            --language    BCP-47 code (e.g. en, es) or "auto"
            --model       installed model name (e.g. ggml-base.en)
            --vocabulary  path to a Vocabulary JSON file
      Murmur --record-once              Launch UI, exit after one dictation completes.
      Murmur --help                     Show this help.
      Murmur --version                  Print version.

    Trigger:
      Double-tap the fn key to start/stop dictation.
      Disable macOS built-in Dictation in System Settings → Keyboard
      (Dictation shortcut → Off) to avoid collision.

    Config:
      ~/Library/Application Support/Murmur/config.json
    Logs:
      ~/Library/Application Support/Murmur/logs/murmur-YYYY-MM-DD.log
    """

    static func parse(_ args: [String]) throws -> CLIMode {
        let tail = Array(args.dropFirst())
        guard !tail.isEmpty else { return .ui }

        var i = 0
        while i < tail.count {
            let a = tail[i]
            switch a {
            case "--help", "-h":
                return .help
            case "--version", "-v":
                return .version
            case "--record-once":
                return .recordOnce
            case "--transcribe-only":
                guard i + 1 < tail.count else { return .help }
                let path = (tail[i + 1] as NSString).expandingTildeInPath
                let wavURL = URL(fileURLWithPath: path)
                let overrides = try parseTranscribeOnlyOverrides(Array(tail.suffix(from: i + 2)))
                return .transcribeOnly(
                    wavURL: wavURL,
                    profile: overrides.profile,
                    language: overrides.language,
                    modelName: overrides.modelName,
                    vocabularyURL: overrides.vocabularyURL
                )
            default:
                i += 1
            }
        }
        return .ui
    }

    private struct TranscribeOverrides {
        var profile: PromptLibrary.Profile?
        var language: String?
        var modelName: String?
        var vocabularyURL: URL?
    }

    /// Strict walker for the override flags that may follow `--transcribe-only <wav>`.
    /// Throws `CLIError.unknownFlag` for anything it doesn't recognise so the
    /// caller can fail fast rather than silently dropping arguments.
    private static func parseTranscribeOnlyOverrides(_ args: [String]) throws -> TranscribeOverrides {
        var out = TranscribeOverrides()
        var i = 0
        while i < args.count {
            let flag = args[i]
            switch flag {
            case "--profile":
                guard i + 1 < args.count else { throw CLIError.missingValue(flag) }
                let raw = args[i + 1]
                guard let profile = PromptLibrary.Profile(rawValue: raw) else {
                    throw CLIError.unknownProfile(raw)
                }
                out.profile = profile
                i += 2
            case "--language":
                guard i + 1 < args.count else { throw CLIError.missingValue(flag) }
                out.language = args[i + 1]
                i += 2
            case "--model":
                guard i + 1 < args.count else { throw CLIError.missingValue(flag) }
                out.modelName = args[i + 1]
                i += 2
            case "--vocabulary":
                guard i + 1 < args.count else { throw CLIError.missingValue(flag) }
                let path = (args[i + 1] as NSString).expandingTildeInPath
                out.vocabularyURL = URL(fileURLWithPath: path)
                i += 2
            default:
                throw CLIError.unknownFlag(flag)
            }
        }
        return out
    }

    static func runHelp() {
        FileHandle.standardOutput.write(Data(helpText.utf8))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    static func runVersion() {
        FileHandle.standardOutput.write(Data("Murmur v0\n".utf8))
    }

    /// Headless transcribe + cleanup for smoke tests and scripting.
    static func runTranscribeOnly(_ wav: URL) -> Int32 {
        let config = Config.loadOrCreateDefault()
        let whisper = WhisperRunner(config: config)
        let cleaner = TextCleaner(vocabulary: config.vocabulary, profile: config.activeProfile)
        do {
            let raw = try whisper.transcribe(audioURL: wav)
            let cleaned = cleaner.clean(raw)
            FileHandle.standardOutput.write(Data((cleaned + "\n").utf8))
            return 0
        } catch {
            let msg = "Murmur error: \(error)\n"
            FileHandle.standardError.write(Data(msg.utf8))
            return 1
        }
    }
}
