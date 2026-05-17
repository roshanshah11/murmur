import Foundation

public struct TextCleaner {
    private let rawTranscriptMode: Bool
    private let customVocabulary: [String: String]

    init(config: Config) {
        self.rawTranscriptMode = config.rawTranscriptMode
        self.customVocabulary = config.customVocabulary
    }

    public init(rawTranscriptMode: Bool, customVocabulary: [String: String]) {
        self.rawTranscriptMode = rawTranscriptMode
        self.customVocabulary = customVocabulary
    }

    public func clean(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawTranscriptMode {
            return text
        }

        text = normalizeWhitespace(text)
        text = removeConservativeFillers(text)
        text = applyVocabulary(text)
        text = normalizeWhitespace(text)
        text = capitalizeFirstLetter(text)
        text = addTerminalPunctuationIfNeeded(text)

        return text
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeConservativeFillers(_ text: String) -> String {
        var output = text
        // Strict filler-only patterns. "kind of"/"sort of" intentionally preserved
        // (they carry meaning; PRD §06 forbids changing meaning).
        let fillerPatterns = [
            #"\b(um+|uh+|er+|ah+)\b,?\s*"#
        ]
        for pattern in fillerPatterns {
            output = output.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Leading "like, " or "you know, " only (avoid changing meaning mid-sentence).
        output = output.replacingOccurrences(
            of: #"^(like|you know),?\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return output
    }

    private func applyVocabulary(_ text: String) -> String {
        var output = text
        for (phrase, replacement) in customVocabulary {
            let escaped = NSRegularExpression.escapedPattern(for: phrase)
            let pattern = #"\b"# + escaped + #"\b"#
            output = output.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return output
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    /// T10: only punctuate when the text reads like a sentence.
    /// Requirements: ≥3 whitespace-separated tokens AND last char is alphanumeric.
    private func addTerminalPunctuationIfNeeded(_ text: String) -> String {
        guard let last = text.last else { return text }
        if [".", "?", "!", ":", ";"].contains(String(last)) {
            return text
        }
        guard last.isLetter || last.isNumber else { return text }
        let tokenCount = text.split(whereSeparator: { $0.isWhitespace }).count
        guard tokenCount >= 3 else { return text }
        return text + "."
    }
}
