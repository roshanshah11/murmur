import Foundation

/// Saves the user's current system output volume + mute state when dictation
/// starts, then restores both when it ends. Uses osascript for portability —
/// CoreAudio would be faster but each call here is only ~30ms and runs off
/// the paste-critical path.
final class VolumeController {
    private var savedMuted: Bool?
    private var savedVolume: Int?
    private var pausedSpotify = false
    private var pausedMusic = false
    private let queue = DispatchQueue(label: "flowlite.volume", qos: .utility)

    func captureAndMute() {
        queue.async { [weak self] in
            guard let self else { return }
            // Pause known music players first so the track doesn't keep
            // progressing while muted — user wants resume-where-they-left-off,
            // not a few seconds of silent playback they have to scrub back.
            self.pausedSpotify = self.pauseIfPlaying(app: "Spotify")
            self.pausedMusic = self.pauseIfPlaying(app: "Music")
            // Mute system volume to catch everything else (video, browser, notifications).
            self.savedMuted = self.runRead("output muted of (get volume settings)").flatMap(Bool.init(fromAppleScript:))
            self.savedVolume = self.runRead("output volume of (get volume settings)").flatMap(Int.init)
            self.run("set volume output muted true")
            Log.event(state: "volume_muted", fields: [
                "saved_muted": String(describing: self.savedMuted),
                "saved_volume": String(describing: self.savedVolume),
                "paused_spotify": String(self.pausedSpotify),
                "paused_music": String(self.pausedMusic)
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
            if self.pausedSpotify {
                self.resumeIfRunning(app: "Spotify")
            }
            if self.pausedMusic {
                self.resumeIfRunning(app: "Music")
            }
            Log.event(state: "volume_restored", fields: [
                "resumed_spotify": String(self.pausedSpotify),
                "resumed_music": String(self.pausedMusic)
            ])
            self.savedMuted = nil
            self.savedVolume = nil
            self.pausedSpotify = false
            self.pausedMusic = false
        }
    }

    /// Returns true iff the app was running, was playing, and we paused it.
    /// `is running` guard prevents AppleScript from launching the app.
    private func pauseIfPlaying(app: String) -> Bool {
        let script = """
        if application \"\(app)\" is running then
            tell application \"\(app)\"
                if player state is playing then
                    pause
                    return \"paused\"
                end if
            end tell
        end if
        return \"\"
        """
        return runRead(script) == "paused"
    }

    private func resumeIfRunning(app: String) {
        let script = "if application \"\(app)\" is running then tell application \"\(app)\" to play"
        run(script)
    }

    @discardableResult
    private func runRead(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let out = Pipe(); process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }
}

private extension Bool {
    init?(fromAppleScript script: String) {
        switch script.lowercased() {
        case "true": self = true
        case "false": self = false
        default: return nil
        }
    }
}
