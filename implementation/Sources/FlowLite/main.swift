import AppKit
import ApplicationServices
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var appState: AppState!
    private var hotkeyMonitor: HotkeyMonitor?
    private var exitAfterNextDictation = false
    private var durationTimer: Timer?
    private var stateItemRef: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let config = Config.loadOrCreateDefault()
        sweepStaleTemp(config: config)

        let recorder = AudioRecorder()
        let whisper = WhisperRunner(config: config)
        let cleaner = TextCleaner(config: config)
        let inserter = PasteboardInserter(config: config)
        let history = HistoryStore(enabled: config.historyEnabled, maxEntries: config.historyMaxEntries)

        appState = AppState(
            config: config,
            recorder: recorder,
            whisper: whisper,
            cleaner: cleaner,
            inserter: inserter,
            history: history,
            onStateChange: { [weak self] newState in
                DispatchQueue.main.async {
                    self?.rebuildMenu()
                    self?.refreshDurationTimer(state: newState)
                    self?.handlePostDictationExitIfNeeded(newState)
                }
            }
        )

        setupStatusItem()
        rebuildMenu()

        hotkeyMonitor = HotkeyMonitor { [weak self] in
            self?.appState.toggleDictation()
        }
        hotkeyMonitor?.start()

        Notifier.bootstrap()
        // Pre-warm mic permission without blocking the main thread.
        DispatchQueue.global(qos: .utility).async {
            try? AudioRecorder().ensurePermission()
        }

        Log.event(state: "launched", fields: [
            "ax_trusted": String(Self.isAXTrusted()),
            "mic_status": String(describing: AudioRecorder.authorizationStatus())
        ])

        if !Self.isAXTrusted() {
            Log.event(state: "ax_permission_missing")
        }
    }

    func enableRecordOnceMode() {
        exitAfterNextDictation = true
    }

    private func handlePostDictationExitIfNeeded(_ state: FlowLiteState) {
        guard exitAfterNextDictation else { return }
        if case .idle = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
        }
    }

    private func sweepStaleTemp(config: Config) {
        guard !config.debugRetainAudio else { return }
        let fm = FileManager.default
        let temp = Config.tempDirectoryURL()
        guard let entries = try? fm.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil) else { return }
        var removed = 0
        for url in entries {
            try? fm.removeItem(at: url)
            removed += 1
        }
        if removed > 0 {
            Log.event(state: "temp_swept", fields: ["count": String(removed)])
        }
    }

    static func isAXTrusted() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "FlowLite"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let stateTitle = "Flow Lite: \(appState.state.displayName)"
        let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())

        let toggleTitle = appState.state == .recording ? "Stop Dictation" : "Start Dictation"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleDictation), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let triggerHint = NSMenuItem(title: "Trigger: double-tap fn", action: nil, keyEquivalent: "")
        triggerHint.isEnabled = false
        menu.addItem(triggerHint)

        let rawItem = NSMenuItem(
            title: "Raw Transcript Mode: \(appState.config.rawTranscriptMode ? "On" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        rawItem.isEnabled = false
        menu.addItem(rawItem)

        let debugItem = NSMenuItem(
            title: "Debug Retain Audio: \(appState.config.debugRetainAudio ? "On" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        debugItem.isEnabled = false
        menu.addItem(debugItem)

        menu.addItem(NSMenuItem.separator())

        if !Self.isAXTrusted() {
            let warn = NSMenuItem(
                title: "⚠ Grant Accessibility Permission",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            warn.target = self
            menu.addItem(warn)
        }

        let testItem = NSMenuItem(title: "Test Whisper Setup", action: #selector(testWhisperSetup), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyItem.submenu = buildHistorySubmenu()
        menu.addItem(historyItem)

        let configItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)

        let logsItem = NSMenuItem(title: "Open Logs Folder", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        stateItemRef = stateItem
        applyLiveTitle()
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return String(format: "0:%02d", s) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func applyLiveTitle() {
        let base = appState.state.shortTitle
        let menuBarTitle: String
        let menuLabel: String
        switch appState.state {
        case .recording:
            let elapsed = appState.recordingElapsedSeconds ?? 0
            menuBarTitle = "● \(formatElapsed(elapsed))"
            menuLabel = "Flow Lite: Recording… \(formatElapsed(elapsed))"
        case .transcribing:
            let elapsed = appState.transcribingElapsedSeconds ?? 0
            let recorded = appState.recordingElapsedSeconds ?? 0
            menuBarTitle = "… \(formatElapsed(elapsed))"
            menuLabel = "Flow Lite: Transcribing… \(formatElapsed(elapsed))  (\(formatElapsed(recorded)) audio)"
        case .pasting, .idle, .error:
            menuBarTitle = base
            menuLabel = "Flow Lite: \(appState.state.displayName)"
        }
        statusItem.button?.title = menuBarTitle
        stateItemRef?.title = menuLabel
    }

    private func refreshDurationTimer(state: FlowLiteState) {
        let isActive: Bool
        switch state {
        case .recording, .transcribing: isActive = true
        default: isActive = false
        }
        if isActive {
            if durationTimer == nil {
                durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.applyLiveTitle()
                }
                if let t = durationTimer { RunLoop.main.add(t, forMode: .common) }
            }
        } else {
            durationTimer?.invalidate()
            durationTimer = nil
        }
        applyLiveTitle()
    }

    @objc private func toggleDictation() {
        appState.toggleDictation()
    }

    @objc private func testWhisperSetup() {
        do {
            try appState.whisper.validateSetup()
            Notifier.success("Whisper setup looks valid.")
        } catch {
            Notifier.warn(String(describing: error))
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(Config.defaultConfigURL())
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(Config.logsDirectoryURL())
    }

    private func buildHistorySubmenu() -> NSMenu {
        let submenu = NSMenu()
        let entries = appState.history.loadRecent(limit: 10)
        if entries.isEmpty {
            let empty = NSMenuItem(title: "(no transcriptions yet)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for (idx, entry) in entries.enumerated() {
                let preview = previewForEntry(entry)
                let item = NSMenuItem(title: preview, action: #selector(copyHistoryEntry(_:)), keyEquivalent: "")
                item.target = self
                item.tag = idx
                item.representedObject = entry.cleaned
                item.toolTip = "\(entry.ts) — \(entry.targetApp)\n\n\(entry.cleaned)"
                submenu.addItem(item)
            }
        }
        submenu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open Full History File…", action: #selector(openHistoryFile), keyEquivalent: "")
        openItem.target = self
        submenu.addItem(openItem)

        let clearItem = NSMenuItem(title: "Clear History…", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        submenu.addItem(clearItem)

        return submenu
    }

    private func previewForEntry(_ entry: HistoryEntry) -> String {
        let max = 48
        let oneLine = entry.cleaned.replacingOccurrences(of: "\n", with: " ")
        let truncated = oneLine.count > max ? String(oneLine.prefix(max)) + "…" : oneLine
        return "\(shortTimestamp(entry.ts))  \(truncated)"
    }

    private func shortTimestamp(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM d HH:mm"
        return display.string(from: date)
    }

    @objc private func copyHistoryEntry(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        Notifier.success("Copied to clipboard. Paste with Cmd+V in target app.")
    }

    @objc private func openHistoryFile() {
        let url = HistoryStore.defaultURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all history?"
        alert.informativeText = "This deletes \(HistoryStore.defaultURL().path)\nCannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            appState.history.clear()
            Notifier.success("History cleared.")
            rebuildMenu()
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        appState.cancelIfNeeded()
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

let mode = CLI.parse(CommandLine.arguments)
switch mode {
case .help:
    CLI.runHelp()
    exit(0)
case .version:
    CLI.runVersion()
    exit(0)
case .transcribeOnly(let wav):
    exit(CLI.runTranscribeOnly(wav))
case .recordOnce, .ui:
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    if case .recordOnce = mode {
        // Defer flag set until after launch.
        DispatchQueue.main.async { delegate.enableRecordOnceMode() }
    }
    app.run()
}
