// Catalog of available Whisper models, bundled with the app.
//
// The manifest ships as a JSON resource (Resources/model-manifest.json) so
// non-engineers can edit it without recompiling. SHA-256 values are marked
// "PENDING" until release engineering pins them.
import Foundation

public struct ModelManifest: Codable, Equatable {
    public struct Entry: Codable, Equatable, Identifiable {
        public var id: String { name }
        public var name: String           // e.g. "ggml-base.en"
        public var displayName: String    // e.g. "Base (English)"
        public var sizeMB: Int            // approximate on-disk size
        public var url: URL               // download URL (Hugging Face)
        public var sha256: String         // hex digest or "PENDING"
        public var language: String       // "en" or "multilingual"
        public var notes: String          // short human description
        public var recommendedFor: [String] // e.g. ["Apple Silicon"]

        public init(
            name: String,
            displayName: String,
            sizeMB: Int,
            url: URL,
            sha256: String,
            language: String,
            notes: String,
            recommendedFor: [String]
        ) {
            self.name = name
            self.displayName = displayName
            self.sizeMB = sizeMB
            self.url = url
            self.sha256 = sha256
            self.language = language
            self.notes = notes
            self.recommendedFor = recommendedFor
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public func entry(named name: String) -> Entry? {
        entries.first(where: { $0.name == name })
    }

    /// Load the manifest from the app's resource bundle. Prefers `Bundle.module`
    /// (SwiftPM) but falls back to `Bundle.main` so the same code path works
    /// inside the built .app.
    public static func bundled() throws -> ModelManifest {
        let candidates: [Bundle] = [Bundle.module, Bundle.main]
        for bundle in candidates {
            if let url = bundle.url(forResource: "model-manifest", withExtension: "json") {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(ModelManifest.self, from: data)
            }
        }
        throw ModelManagerError.manifestMissing
    }
}

public enum ModelManagerError: Error, Equatable {
    case manifestMissing
    case unknownModel(String)
    case shaMismatch(expected: String, actual: String)
    case downloadFailed(String)
    case writeFailed(String)
}
