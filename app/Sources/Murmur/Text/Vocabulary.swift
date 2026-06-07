// Case-insensitive find/replace dictionary with word-boundary matching,
// ordered for deterministic substitution.
import Foundation

public struct Vocabulary: Codable, Equatable {
    public struct Entry: Codable, Equatable, Identifiable {
        public var id: String { from.lowercased() }
        public var from: String
        public var to: String
        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    public private(set) var entries: [Entry] = []

    public init(_ entries: [Entry] = []) { self.entries = entries }

    public mutating func upsert(from: String, to: String) {
        let key = from.lowercased()
        if let idx = entries.firstIndex(where: { $0.from.lowercased() == key }) {
            entries[idx].to = to
        } else {
            entries.append(Entry(from: from, to: to))
        }
    }

    public mutating func remove(from: String) {
        let key = from.lowercased()
        entries.removeAll { $0.from.lowercased() == key }
    }

    public func apply(to text: String) -> String {
        var out = text
        for entry in entries {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.from) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(out.startIndex..., in: out)
            out = regex.stringByReplacingMatches(
                in: out,
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.to)
            )
        }
        return out
    }
}
