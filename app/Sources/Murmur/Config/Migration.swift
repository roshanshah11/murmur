// swiftlint:disable banned_flowlite
// legitimate legacy ~/.flow-lite migration path (mirrors the CI grep allowlist)
// One-time copy of legacy ~/.flow-lite contents into the Murmur app-support directory.
import Foundation

public enum ConfigMigration {
    public static func migrate(legacy: URL, destination: URL) throws {
        let fm = FileManager.default
        let legacyConfig = legacy.appendingPathComponent("config.json")
        guard fm.fileExists(atPath: legacyConfig.path) else { return }
        let destConfig = destination.appendingPathComponent("config.json")
        if fm.fileExists(atPath: destConfig.path) { return }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in ["config.json", "history.jsonl"] {
            let src = legacy.appendingPathComponent(name)
            let dst = destination.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: dst)
            }
        }
        let modelsSrc = legacy.appendingPathComponent("models", isDirectory: true)
        let modelsDst = destination.appendingPathComponent("Models", isDirectory: true)
        if fm.fileExists(atPath: modelsSrc.path), !fm.fileExists(atPath: modelsDst.path) {
            try fm.copyItem(at: modelsSrc, to: modelsDst)
        }
        let marker = legacy.appendingPathComponent(".migrated")
        try Data(Date().description.utf8).write(to: marker)
    }

    public static func runDefaultMigration() {
        do {
            try AppPaths.ensureDirectoriesExist()
            try migrate(legacy: AppPaths.legacyFlowLiteDirectory,
                        destination: AppPaths.appSupportDirectory)
        } catch {
            Log.error("config migration failed: \(error)")
        }
    }
}
// swiftlint:enable banned_flowlite
