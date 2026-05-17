import Foundation

enum CLIMode {
    case ui
    case transcribeOnly(URL)
    case recordOnce
    case help
    case version
}

enum CLI {
    static func parse(_ args: [String]) -> CLIMode {
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
                return .transcribeOnly(URL(fileURLWithPath: path))
            default:
                i += 1
            }
        }
        return .ui
    }

    static func runHelp() {
        let usage = """
        Murmur — local-first macOS dictation utility.

        Usage:
          Murmur                            Launch menubar UI (default).
          Murmur --transcribe-only <wav>    Transcribe one WAV file, print to stdout, exit.
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
        FileHandle.standardOutput.write(Data(usage.utf8))
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
