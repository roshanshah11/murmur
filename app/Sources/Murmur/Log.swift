import Foundation

enum Log {
    private static let queue = DispatchQueue(label: "murmur.log", qos: .utility)
    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var fileURL: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let stamp = dateFormatter.string(from: Date())
        return AppPaths.logsDirectory.appendingPathComponent("murmur-\(stamp).log")
    }

    static func event(state: String, fields: [String: String] = [:]) {
        let timestamp = iso.string(from: Date())
        var line: [String: String] = ["ts": timestamp, "state": state]
        for (key, value) in fields { line[key] = value }

        let json: String
        if let data = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            json = jsonString
        } else {
            json = "{\"ts\":\"\(timestamp)\",\"state\":\"\(state)\"}"
        }

        print(json)

        queue.async {
            let url = fileURL
            let fm = FileManager.default
            try? fm.createDirectory(at: AppPaths.logsDirectory, withIntermediateDirectories: true)

            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let data = (json + "\n").data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        }
    }

    static func error(_ message: String, fields: [String: String] = [:]) {
        var merged = fields
        merged["error"] = message
        event(state: "error", fields: merged)
    }
}
