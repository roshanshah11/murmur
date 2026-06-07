import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let ts: String
    let cleaned: String
    let raw: String
    let targetApp: String
    let targetBundle: String
    let durationMs: Int
    let result: String
    /// Optional, decoded with a default of `false` so entries written before
    /// Phase 5 (which added the favorite feature) keep decoding cleanly.
    var favorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, ts, cleaned, raw
        case targetApp = "target_app"
        case targetBundle = "target_bundle"
        case durationMs = "duration_ms"
        case result
        case favorite
    }

    init(
        id: String,
        ts: String,
        cleaned: String,
        raw: String,
        targetApp: String,
        targetBundle: String,
        durationMs: Int,
        result: String,
        favorite: Bool = false
    ) {
        self.id = id
        self.ts = ts
        self.cleaned = cleaned
        self.raw = raw
        self.targetApp = targetApp
        self.targetBundle = targetBundle
        self.durationMs = durationMs
        self.result = result
        self.favorite = favorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.ts = try container.decode(String.self, forKey: .ts)
        self.cleaned = try container.decode(String.self, forKey: .cleaned)
        self.raw = try container.decode(String.self, forKey: .raw)
        self.targetApp = try container.decode(String.self, forKey: .targetApp)
        self.targetBundle = try container.decode(String.self, forKey: .targetBundle)
        self.durationMs = try container.decode(Int.self, forKey: .durationMs)
        self.result = try container.decode(String.self, forKey: .result)
        // Defaults to false so pre-Phase-5 entries on disk decode without error.
        self.favorite = try container.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
    }
}

final class HistoryStore {
    private let queue = DispatchQueue(label: "flowlite.history")
    private let fileURL: URL
    private let maxEntries: Int
    private let enabled: Bool

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(enabled: Bool, maxEntries: Int, fileURL: URL = HistoryStore.defaultURL()) {
        self.enabled = enabled
        self.maxEntries = max(1, maxEntries)
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        Config.baseDirectoryURL().appendingPathComponent("history.jsonl")
    }

    func append(cleaned: String, raw: String, target: AppContext, durationMs: Int, result: String) {
        guard enabled else { return }
        let entry = HistoryEntry(
            id: UUID().uuidString,
            ts: Self.iso.string(from: Date()),
            cleaned: cleaned,
            raw: raw,
            targetApp: target.name,
            targetBundle: target.bundleID,
            durationMs: durationMs,
            result: result
        )
        queue.async { [fileURL, maxEntries] in
            let fm = FileManager.default
            try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: fileURL.path) {
                fm.createFile(atPath: fileURL.path, contents: nil)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let line = try? encoder.encode(entry),
                  let lineString = String(data: line, encoding: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data((lineString + "\n").utf8))
            }
            HistoryStore.trimIfNeeded(fileURL: fileURL, maxEntries: maxEntries)
        }
    }

    func loadRecent(limit: Int) -> [HistoryEntry] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { return [] }
            let decoder = JSONDecoder()
            let lines = content.split(whereSeparator: { $0.isNewline })
            let tail = lines.suffix(limit)
            var entries: [HistoryEntry] = []
            for line in tail {
                if let lineData = String(line).data(using: .utf8),
                   let entry = try? decoder.decode(HistoryEntry.self, from: lineData) {
                    entries.append(entry)
                }
            }
            return entries.reversed()
        }
    }

    /// Loads every persisted entry, newest first. Used by the History window
    /// so users can search/scroll the full file (subject to `maxEntries`).
    func loadAll() -> [HistoryEntry] {
        loadRecent(limit: Int.max)
    }

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Removes a single entry by id and atomically rewrites the file. No-op
    /// if the id isn't found. Returns true if a row was deleted.
    @discardableResult
    func delete(id: String) -> Bool {
        queue.sync {
            var entries = readAllUnlocked()
            let before = entries.count
            entries.removeAll { $0.id == id }
            guard entries.count != before else { return false }
            writeAllUnlocked(entries)
            return true
        }
    }

    /// Toggles or sets a row's favorite flag. Atomic rewrite. Returns true
    /// if the row was found.
    @discardableResult
    func setFavorite(id: String, _ value: Bool) -> Bool {
        queue.sync {
            var entries = readAllUnlocked()
            guard let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
            entries[idx].favorite = value
            writeAllUnlocked(entries)
            return true
        }
    }

    var fileURLPublic: URL { fileURL }

    /// True if the on-disk file exists AND contains at least one decodable
    /// entry. Used by the General settings tab to enable the "Clear now"
    /// button only when there's something to clear.
    func hasEntries() -> Bool {
        !loadRecent(limit: 1).isEmpty
    }

    // MARK: - Private file IO (called inside `queue` only)

    /// Caller must already be on `queue`. Returns entries in file order
    /// (oldest first) so writes preserve the ordering convention.
    private func readAllUnlocked() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let lines = content.split(whereSeparator: { $0.isNewline })
        var entries: [HistoryEntry] = []
        for line in lines {
            if let lineData = String(line).data(using: .utf8),
               let entry = try? decoder.decode(HistoryEntry.self, from: lineData) {
                entries.append(entry)
            }
        }
        return entries
    }

    /// Caller must already be on `queue`. Writes atomically — temp file +
    /// replace — to avoid partial truncations on crash mid-write.
    private func writeAllUnlocked(_ entries: [HistoryEntry]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var buf = Data()
        for entry in entries {
            guard let line = try? encoder.encode(entry) else { continue }
            buf.append(line)
            buf.append(0x0A)  // \n
        }
        try? buf.write(to: fileURL, options: .atomic)
    }

    private static func trimIfNeeded(fileURL: URL, maxEntries: Int) {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else { return }
        let lines = content.split(whereSeparator: { $0.isNewline })
        guard lines.count > maxEntries else { return }
        let trimmed = lines.suffix(maxEntries).joined(separator: "\n") + "\n"
        try? trimmed.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
}
