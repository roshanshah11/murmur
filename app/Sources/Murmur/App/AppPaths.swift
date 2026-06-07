// swiftlint:disable banned_flowlite
// legitimate legacy ~/.flow-lite migration path (mirrors the CI grep allowlist)
// Single source of truth for Murmur's filesystem layout.
import Foundation

public enum AppPaths {
    public static let appName = "Murmur"

    public static var appSupportDirectory: URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support directory is always present on macOS")
        }
        return base.appendingPathComponent(appName, isDirectory: true)
    }
    public static var logsDirectory: URL {
        guard let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            preconditionFailure("Library directory is always present on macOS")
        }
        return base.appendingPathComponent("Logs", isDirectory: true)
                   .appendingPathComponent(appName, isDirectory: true)
    }
    public static var cachesDirectory: URL {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            preconditionFailure("Caches directory is always present on macOS")
        }
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
// swiftlint:enable banned_flowlite
