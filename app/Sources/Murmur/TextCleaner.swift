// Profile-aware text cleaner. Applies a PromptLibrary profile then user
// vocabulary substitutions. The profile decides general cleanup (raw,
// casual, formal, code); vocabulary applies user-specific find/replace
// after the profile so substitutions land on the cleaned text.
import Foundation

public struct TextCleaner {
    public var vocabulary: Vocabulary
    public var profile: PromptLibrary.Profile

    public init(vocabulary: Vocabulary = .init(), profile: PromptLibrary.Profile = .casual) {
        self.vocabulary = vocabulary
        self.profile = profile
    }

    public func clean(_ text: String) -> String {
        let profiled = profile.apply(to: text)
        return vocabulary.apply(to: profiled)
    }
}
