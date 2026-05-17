import Foundation

struct Config: Codable {
    var whisperBinaryPath: String
    var modelPath: String
    var language: String
    var rawTranscriptMode: Bool
    var restoreClipboardAfterPaste: Bool
    var clipboardRestoreDelayMs: Int
    var deleteTempAudio: Bool
    var debugRetainAudio: Bool
    var transcriptionTimeoutSeconds: Int
    var whisperThreads: Int?
    var pasteDelayMs: Int
    var errorAutoClearSeconds: Int
    var historyEnabled: Bool
    var historyMaxEntries: Int
    var customVocabulary: [String: String]

    static func defaultConfigURL() -> URL {
        baseDirectoryURL().appendingPathComponent("config.json")
    }

    static func baseDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flow-lite", isDirectory: true)
    }

    static func logsDirectoryURL() -> URL {
        baseDirectoryURL().appendingPathComponent("logs", isDirectory: true)
    }

    static func tempDirectoryURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("FlowLite", isDirectory: true)
            .appendingPathComponent("temp", isDirectory: true)
    }

    static func debugDirectoryURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("FlowLite", isDirectory: true)
            .appendingPathComponent("debug", isDirectory: true)
    }

    static func defaultConfig() -> Config {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let binary = home.appendingPathComponent("dev/whisper.cpp/build/bin/whisper-cli").path
        let model = home.appendingPathComponent("models/ggml-small.en-q5_1.bin").path
        return Config(
            whisperBinaryPath: binary,
            modelPath: model,
            language: "en",
            rawTranscriptMode: false,
            restoreClipboardAfterPaste: false,
            clipboardRestoreDelayMs: 1500,
            deleteTempAudio: true,
            debugRetainAudio: false,
            transcriptionTimeoutSeconds: 60,
            whisperThreads: nil,
            pasteDelayMs: 10,
            errorAutoClearSeconds: 3,
            historyEnabled: true,
            historyMaxEntries: 1000,
            customVocabulary: [
                "cofounders capital": "Cofounders Capital",
                "caju dot ai": "Caju.ai",
                "caju ai": "Caju.ai",
                "element four fifty one": "Element451",
                "kenan flagler": "Kenan-Flagler",
                "pmt": "PMT"
            ]
        )
    }

    init(
        whisperBinaryPath: String,
        modelPath: String,
        language: String,
        rawTranscriptMode: Bool,
        restoreClipboardAfterPaste: Bool,
        clipboardRestoreDelayMs: Int,
        deleteTempAudio: Bool,
        debugRetainAudio: Bool,
        transcriptionTimeoutSeconds: Int,
        whisperThreads: Int?,
        pasteDelayMs: Int,
        errorAutoClearSeconds: Int,
        historyEnabled: Bool,
        historyMaxEntries: Int,
        customVocabulary: [String: String]
    ) {
        self.whisperBinaryPath = whisperBinaryPath
        self.modelPath = modelPath
        self.language = language
        self.rawTranscriptMode = rawTranscriptMode
        self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
        self.clipboardRestoreDelayMs = clipboardRestoreDelayMs
        self.deleteTempAudio = deleteTempAudio
        self.debugRetainAudio = debugRetainAudio
        self.transcriptionTimeoutSeconds = transcriptionTimeoutSeconds
        self.whisperThreads = whisperThreads
        self.pasteDelayMs = pasteDelayMs
        self.errorAutoClearSeconds = errorAutoClearSeconds
        self.historyEnabled = historyEnabled
        self.historyMaxEntries = historyMaxEntries
        self.customVocabulary = customVocabulary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config.defaultConfig()
        self.whisperBinaryPath = try c.decodeIfPresent(String.self, forKey: .whisperBinaryPath) ?? d.whisperBinaryPath
        self.modelPath = try c.decodeIfPresent(String.self, forKey: .modelPath) ?? d.modelPath
        self.language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        self.rawTranscriptMode = try c.decodeIfPresent(Bool.self, forKey: .rawTranscriptMode) ?? d.rawTranscriptMode
        self.restoreClipboardAfterPaste = try c.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? d.restoreClipboardAfterPaste
        self.clipboardRestoreDelayMs = try c.decodeIfPresent(Int.self, forKey: .clipboardRestoreDelayMs) ?? d.clipboardRestoreDelayMs
        self.deleteTempAudio = try c.decodeIfPresent(Bool.self, forKey: .deleteTempAudio) ?? d.deleteTempAudio
        self.debugRetainAudio = try c.decodeIfPresent(Bool.self, forKey: .debugRetainAudio) ?? d.debugRetainAudio
        self.transcriptionTimeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .transcriptionTimeoutSeconds) ?? d.transcriptionTimeoutSeconds
        self.whisperThreads = try c.decodeIfPresent(Int.self, forKey: .whisperThreads) ?? d.whisperThreads
        self.pasteDelayMs = try c.decodeIfPresent(Int.self, forKey: .pasteDelayMs) ?? d.pasteDelayMs
        self.errorAutoClearSeconds = try c.decodeIfPresent(Int.self, forKey: .errorAutoClearSeconds) ?? d.errorAutoClearSeconds
        self.historyEnabled = try c.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? d.historyEnabled
        self.historyMaxEntries = try c.decodeIfPresent(Int.self, forKey: .historyMaxEntries) ?? d.historyMaxEntries
        self.customVocabulary = try c.decodeIfPresent([String: String].self, forKey: .customVocabulary) ?? d.customVocabulary
    }

    static func loadOrCreateDefault() -> Config {
        let fm = FileManager.default
        let configURL = defaultConfigURL()
        try? fm.createDirectory(at: baseDirectoryURL(), withIntermediateDirectories: true)
        try? fm.createDirectory(at: logsDirectoryURL(), withIntermediateDirectories: true)
        try? fm.createDirectory(at: tempDirectoryURL(), withIntermediateDirectories: true)

        guard fm.fileExists(atPath: configURL.path) else {
            let config = defaultConfig()
            do {
                let data = try JSONEncoder.pretty.encode(config)
                try data.write(to: configURL)
                Log.event(state: "config_created", fields: ["path": configURL.path])
            } catch {
                Log.error("failed to write default config: \(error)")
            }
            return config
        }

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            Log.error("failed to read config at \(configURL.path): \(error)")
            return defaultConfig()
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
