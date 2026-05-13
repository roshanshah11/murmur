import Foundation

struct HistoryEntry: Codable {
    let id: String
    let ts: String
    let cleaned: String
    let raw: String
    let targetApp: String
    let targetBundle: String
    let durationMs: Int
    let result: String

    enum CodingKeys: String, CodingKey {
        case id, ts, cleaned, raw
        case targetApp = "target_app"
        case targetBundle = "target_bundle"
        case durationMs = "duration_ms"
        case result
    }
}

final class HistoryStore {
    private let queue = DispatchQueue(label: "flowlite.history")
    private let fileURL: URL
    private let maxEntries: Int
    private let enabled: Bool

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
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

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    var fileURLPublic: URL { fileURL }

    private static func trimIfNeeded(fileURL: URL, maxEntries: Int) {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else { return }
        let lines = content.split(whereSeparator: { $0.isNewline })
        guard lines.count > maxEntries else { return }
        let trimmed = lines.suffix(maxEntries).joined(separator: "\n") + "\n"
        try? trimmed.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
}
