import Foundation

/// Saves the user's current system output volume + mute state when dictation
/// starts, then restores both when it ends. Uses osascript for portability —
/// CoreAudio would be faster but each call here is only ~30ms and runs off
/// the paste-critical path.
final class VolumeController {
    private var savedMuted: Bool?
    private var savedVolume: Int?
    private let queue = DispatchQueue(label: "flowlite.volume", qos: .utility)

    func captureAndMute() {
        queue.async { [weak self] in
            guard let self else { return }
            self.savedMuted = self.runRead("output muted of (get volume settings)").flatMap(Bool.init(fromAppleScript:))
            self.savedVolume = self.runRead("output volume of (get volume settings)").flatMap(Int.init)
            self.run("set volume output muted true")
            Log.event(state: "volume_muted", fields: [
                "saved_muted": String(describing: self.savedMuted),
                "saved_volume": String(describing: self.savedVolume)
            ])
        }
    }

    func restore() {
        queue.async { [weak self] in
            guard let self else { return }
            if let volume = self.savedVolume {
                self.run("set volume output volume \(volume)")
            }
            if let muted = self.savedMuted {
                self.run("set volume output muted \(muted ? "true" : "false")")
            } else {
                // We don't know the prior mute state; assume not muted.
                self.run("set volume output muted false")
            }
            Log.event(state: "volume_restored")
            self.savedMuted = nil
            self.savedVolume = nil
        }
    }

    @discardableResult
    private func runRead(_ script: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let out = Pipe(); p.standardOutput = out
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
        } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ script: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
    }
}

private extension Bool {
    init?(fromAppleScript s: String) {
        switch s.lowercased() {
        case "true": self = true
        case "false": self = false
        default: return nil
        }
    }
}
