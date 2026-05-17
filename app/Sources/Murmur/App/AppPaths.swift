// Single source of truth for Murmur's filesystem layout.
import Foundation

public enum AppPaths {
    public static let appName = "Murmur"

    public static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appName, isDirectory: true)
    }
    public static var logsDirectory: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Logs", isDirectory: true)
                   .appendingPathComponent(appName, isDirectory: true)
    }
    public static var cachesDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appName, isDirectory: true)
    }
    public static var modelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Models", isDirectory: true)
    }
    public static var configFile: URL { appSupportDirectory.appendingPathComponent("config.json") }
    public static var historyFile: URL { appSupportDirectory.appendingPathComponent("history.jsonl") }
    public static var legacyFlowLiteDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flow-lite", isDirectory: true)
    }
    public static func ensureDirectoriesExist() throws {
        for dir in [appSupportDirectory, logsDirectory, cachesDirectory, modelsDirectory] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
