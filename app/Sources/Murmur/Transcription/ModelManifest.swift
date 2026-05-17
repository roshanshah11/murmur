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

    /// Load the manifest from the app's resource bundle. Tries several
    /// known layouts so the same call works in three environments:
    ///   1. SwiftPM tests/dev — `Bundle.module` (the SPM accessor).
    ///   2. Built .app — `Bundle.main.url(forResource:withExtension:)`
    ///      finds it inside `Contents/Resources/`.
    ///   3. Fallback — sibling resource bundle SPM emits next to the
    ///      executable. Touching `Bundle.module` directly is unsafe
    ///      because its generated accessor `fatalError`s if the bundle
    ///      is missing, so we synthesize the same lookup ourselves.
    public static func bundled() throws -> ModelManifest {
        if let url = Bundle.main.url(forResource: "model-manifest", withExtension: "json") {
            return try decode(from: url)
        }
        // Mirror SPM's generated `Bundle.module` lookup without triggering
        // its fatalError on miss.
        let candidates: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent("Murmur_Murmur.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Murmur_Murmur.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/Murmur_Murmur.bundle")
        ]
        for url in candidates {
            if let bundle = Bundle(url: url),
               let res = bundle.url(forResource: "model-manifest", withExtension: "json") {
                return try decode(from: res)
            }
        }
        // Last-ditch: the SPM accessor (works in `swift test`).
        if let res = Bundle.module.url(forResource: "model-manifest", withExtension: "json") {
            return try decode(from: res)
        }
        throw ModelManagerError.manifestMissing
    }

    private static func decode(from url: URL) throws -> ModelManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ModelManifest.self, from: data)
    }
}

public enum ModelManagerError: Error, Equatable {
    case manifestMissing
    case unknownModel(String)
    case shaMismatch(expected: String, actual: String)
    case downloadFailed(String)
    case writeFailed(String)
}
