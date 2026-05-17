// Deterministic cleanup profiles. No LLM. Each profile = ordered transforms.
//
// - raw    : passthrough.
// - casual : strip unambiguous fillers (um/uh/er/ah anywhere; leading
//            like/you know), normalize whitespace, capitalize first letter,
//            append "." only when the input reads like a sentence
//            (≥3 whitespace-separated tokens, terminal alphanumeric).
// - formal : casual + contraction expansion.
// - code   : spoken-operator translation (no other cleanup).
import Foundation

public enum PromptLibrary {
    public enum Profile: String, CaseIterable, Codable, Identifiable {
        case raw, casual, formal, code

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .raw: return "Raw"
            case .casual: return "Casual"
            case .formal: return "Formal"
            case .code: return "Code"
            }
        }

        public func apply(to text: String) -> String {
            switch self {
            case .raw:    return text
            case .casual: return Casual.apply(to: text)
            case .formal: return Formal.apply(to: text)
            case .code:   return Code.apply(to: text)
            }
        }
    }

    enum Casual {
        // Unambiguous filler tokens — safe to strip anywhere.
        // "kind of" / "sort of" intentionally preserved (carry meaning).
        static let bodyFillerPattern = #"\b(um+|uh+|er+|ah+)\b,?\s*"#
        // Leading-only fillers — never strip mid-sentence to avoid changing meaning.
        static let leadingFillerPattern = #"^(like|you know),?\s+"#

        static func apply(to text: String) -> String {
            var out = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Token count of the *original* input — drives terminal-punctuation
            // decision so that filler-heavy short phrases ("um, like, hi there")
            // still get punctuated, while genuinely short fragments ("buy milk")
            // do not.
            let originalTokenCount = out.split(whereSeparator: { $0.isWhitespace }).count

            // Strip um/uh/er/ah anywhere.
            out = out.replacingOccurrences(
                of: bodyFillerPattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )

            // Iteratively strip leading like / you know — handles chains like
            // "um, like, hello" where removing "um" promotes "like" to leading.
            var changed = true
            while changed {
                let before = out
                out = out.replacingOccurrences(
                    of: leadingFillerPattern,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                out = out.trimmingCharacters(in: .whitespacesAndNewlines)
                // Also strip leading punctuation crumbs left over from stripped fillers
                // (e.g. ", hello there" → "hello there").
                out = out.replacingOccurrences(
                    of: #"^[,\.\s]+"#,
                    with: "",
                    options: .regularExpression
                )
                changed = (out != before)
            }

            // Collapse internal whitespace.
            out = out.replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            out = out.replacingOccurrences(of: " ,", with: ",")
            out = out.replacingOccurrences(of: " .", with: ".")
            out = out.trimmingCharacters(in: .whitespacesAndNewlines)

            out = capitalizeFirst(out)
            out = addTerminalPunctuationIfNeeded(out, originalTokenCount: originalTokenCount)
            return out
        }

        static func capitalizeFirst(_ text: String) -> String {
            guard let first = text.first else { return text }
            return String(first).uppercased() + text.dropFirst()
        }

        // Only punctuate when the text reads like a sentence.
        // Requirements: ≥3 whitespace-separated tokens in the *original* input
        // (before filler removal) AND last char is alphanumeric.
        static func addTerminalPunctuationIfNeeded(_ text: String, originalTokenCount: Int) -> String {
            guard let last = text.last else { return text }
            if [".", "?", "!", ":", ";"].contains(String(last)) { return text }
            guard last.isLetter || last.isNumber else { return text }
            guard originalTokenCount >= 3 else { return text }
            return text + "."
        }
    }

    enum Formal {
        static let contractions: [(String, String)] = [
            ("don't", "do not"),
            ("won't", "will not"),
            ("can't", "cannot"),
            ("it's", "it is"),
            ("i'm", "I am"),
            ("you're", "you are"),
            ("they're", "they are"),
            ("we're", "we are"),
            ("isn't", "is not"),
            ("aren't", "are not"),
            ("doesn't", "does not")
        ]

        static func apply(to text: String) -> String {
            var out = Casual.apply(to: text)
            for (k, v) in contractions {
                let pattern = NSRegularExpression.escapedPattern(for: k)
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let range = NSRange(out.startIndex..., in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: v)
                )
            }
            // Re-capitalize after substitutions (e.g. "i" → "I am" handled above,
            // but a lowercased lead survives if no contraction was the head).
            if let first = out.first, first.isLowercase {
                let upper = String(first).uppercased()
                out.replaceSubrange(out.startIndex...out.startIndex, with: upper)
            }
            return out
        }
    }

    enum Code {
        // Longest phrases first so multi-word operators win against single-word
        // substrings (e.g. "not equals" must match before standalone "equals").
        // \b-wrapped to avoid accidental hits inside identifiers like "colonel".
        static let operators: [(String, String)] = [
            ("greater than or equal", ">="),
            ("less than or equal", "<="),
            ("equals equals", "=="),
            ("not equals", "!="),
            ("double colon", "::"),
            ("question mark", "?"),
            ("arrow", "->"),
            ("colon", ":")
        ]

        static func apply(to text: String) -> String {
            var out = text
            for (k, v) in operators {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let range = NSRange(out.startIndex..., in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: v)
                )
            }
            return out
        }
    }
}
