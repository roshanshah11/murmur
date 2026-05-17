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
    var vocabulary: Vocabulary
    var activeProfile: PromptLibrary.Profile
    /// Phase 6: stamped to "1.0" once the user finishes the onboarding
    /// wizard. `nil` (the default) means the wizard has never completed
    /// successfully, so the next launch will reopen it. Stored as a
    /// version string (not a bool) so future onboarding refreshes can
    /// re-prompt only users whose previous completion is older than the
    /// new revision.
    var onboardingCompletedVersion: String?

    static func defaultConfigURL() -> URL {
        AppPaths.configFile
    }

    static func baseDirectoryURL() -> URL {
        AppPaths.appSupportDirectory
    }

    static func logsDirectoryURL() -> URL {
        AppPaths.logsDirectory
    }

    static func tempDirectoryURL() -> URL {
        AppPaths.cachesDirectory.appendingPathComponent("temp", isDirectory: true)
    }

    static func debugDirectoryURL() -> URL {
        AppPaths.cachesDirectory.appendingPathComponent("debug", isDirectory: true)
    }

    /// Seed entries shipped with every fresh install. Preserved verbatim from
    /// the pre-Vocabulary `customVocabulary` defaults so installer behavior
    /// does not regress when the schema rolls forward.
    private static let defaultVocabularySeed: [(String, String)] = [
        ("cofounders capital", "Cofounders Capital"),
        ("caju dot ai", "Caju.ai"),
        ("caju ai", "Caju.ai"),
        ("element four fifty one", "Element451"),
        ("kenan flagler", "Kenan-Flagler"),
        ("pmt", "PMT")
    ]

    static func defaultVocabulary() -> Vocabulary {
        var v = Vocabulary()
        for (from, to) in defaultVocabularySeed {
            v.upsert(from: from, to: to)
        }
        return v
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
            // Privacy-first: history is OFF by default. Users opt in via
            // Settings → General. Decoding a config that pre-dates this key
            // also defaults to false (see init(from:) below).
            historyEnabled: false,
            historyMaxEntries: 1000,
            vocabulary: defaultVocabulary(),
            activeProfile: .casual,
            onboardingCompletedVersion: nil
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
        vocabulary: Vocabulary,
        activeProfile: PromptLibrary.Profile,
        onboardingCompletedVersion: String? = nil
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
        self.vocabulary = vocabulary
        self.activeProfile = activeProfile
        self.onboardingCompletedVersion = onboardingCompletedVersion
    }

    /// Coding keys are listed explicitly so we can decode the legacy
    /// `customVocabulary: [String: String]` field even though it is no
    /// longer a stored property on Config.
    private enum CodingKeys: String, CodingKey {
        case whisperBinaryPath
        case modelPath
        case language
        case rawTranscriptMode
        case restoreClipboardAfterPaste
        case clipboardRestoreDelayMs
        case deleteTempAudio
        case debugRetainAudio
        case transcriptionTimeoutSeconds
        case whisperThreads
        case pasteDelayMs
        case errorAutoClearSeconds
        case historyEnabled
        case historyMaxEntries
        case vocabulary
        case activeProfile
        case onboardingCompletedVersion
        case customVocabulary  // legacy — migrated into `vocabulary`
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
        self.activeProfile = try c.decodeIfPresent(PromptLibrary.Profile.self, forKey: .activeProfile) ?? d.activeProfile
        self.onboardingCompletedVersion = try c.decodeIfPresent(String.self, forKey: .onboardingCompletedVersion)

        // Vocabulary precedence: modern `vocabulary` key wins. If absent, fall
        // back to legacy `customVocabulary: [String: String]` (sorted-key order
        // for deterministic migration). If both absent, use defaults.
        if let modern = try c.decodeIfPresent(Vocabulary.self, forKey: .vocabulary) {
            self.vocabulary = modern
        } else if let legacy = try c.decodeIfPresent([String: String].self, forKey: .customVocabulary) {
            var v = Vocabulary()
            for key in legacy.keys.sorted() {
                v.upsert(from: key, to: legacy[key]!)
            }
            self.vocabulary = v
        } else {
            self.vocabulary = d.vocabulary
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(whisperBinaryPath, forKey: .whisperBinaryPath)
        try c.encode(modelPath, forKey: .modelPath)
        try c.encode(language, forKey: .language)
        try c.encode(rawTranscriptMode, forKey: .rawTranscriptMode)
        try c.encode(restoreClipboardAfterPaste, forKey: .restoreClipboardAfterPaste)
        try c.encode(clipboardRestoreDelayMs, forKey: .clipboardRestoreDelayMs)
        try c.encode(deleteTempAudio, forKey: .deleteTempAudio)
        try c.encode(debugRetainAudio, forKey: .debugRetainAudio)
        try c.encode(transcriptionTimeoutSeconds, forKey: .transcriptionTimeoutSeconds)
        try c.encodeIfPresent(whisperThreads, forKey: .whisperThreads)
        try c.encode(pasteDelayMs, forKey: .pasteDelayMs)
        try c.encode(errorAutoClearSeconds, forKey: .errorAutoClearSeconds)
        try c.encode(historyEnabled, forKey: .historyEnabled)
        try c.encode(historyMaxEntries, forKey: .historyMaxEntries)
        try c.encode(vocabulary, forKey: .vocabulary)
        try c.encode(activeProfile, forKey: .activeProfile)
        try c.encodeIfPresent(onboardingCompletedVersion, forKey: .onboardingCompletedVersion)
        // Deliberately do not emit `customVocabulary` — the field is decode-only
        // for legacy migration.
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

    /// Persist the current config to `AppPaths.configFile`. The in-memory
    /// AppState copy is not mutated; callers that need a live refresh must
    /// reload (a full app restart is fine for v1 — model selection takes
    /// effect on the next dictation pipeline run regardless).
    func save() throws {
        let url = Self.defaultConfigURL()
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory,
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(self)
        try data.write(to: url, options: .atomic)
        Log.event(state: "config_saved", fields: ["path": url.path])
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
