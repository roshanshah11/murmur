// app entry point + menu wiring; the delegate is cohesive launch glue
// swiftlint:disable file_length
import AppKit
import ApplicationServices
import FluidAudio
import Foundation

// swiftlint:disable:next type_body_length
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var appState: AppState!
    private var hotkeyMonitor: HotkeyMonitor?
    private var exitAfterNextDictation = false
    private var durationTimer: Timer?
    private var stateItemRef: NSMenuItem?
    private let notch = NotchIndicator()
    private lazy var settingsWindow = SettingsWindowController()

    // launch wiring; splitting hurts readability of the startup sequence
    // swiftlint:disable:next function_body_length
    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigMigration.runDefaultMigration()
        // Touch the Sparkle adapter so SPUStandardUpdaterController initialises
        // and schedules its background appcast check before we return.
        _ = SparkleUpdater.shared
        NSApp.setActivationPolicy(.accessory)

        let config = Config.loadOrCreateDefault()
        // Apply the saved appearance (auto/light/dark) before any window shows.
        config.appearance.apply()
        sweepStaleTemp(config: config)

        let recorder = AudioRecorder()
        // First-run download gate: only mirror Parakeet download progress onto
        // the notch when the model is actually absent. FluidAudio fires
        // compile-phase progress callbacks even for a cached model, which would
        // otherwise flash the notch on every launch.
        let parakeetNeedsDownload = (config.transcriptionEngine == .parakeet)
            && !AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3), version: .v3)
        let engine = TranscriptionEngineFactory.make(config: config, onModelDownloadProgress: { fraction in
            guard parakeetNeedsDownload else { return }
            NotificationCenter.default.post(name: .murmurModelDownloadProgress, object: fraction)
        })
        let cleaner = TextCleaner(vocabulary: config.vocabulary, profile: config.activeProfile)
        let inserter = PasteboardInserter(config: config)
        // Pass enabled=true so the History window can always read/write
        // (delete, favorite-toggle, clear). AppState.appendHistoryIfEnabled
        // gates *writes from the dictation pipeline* on config.historyEnabled,
        // so the privacy guarantee is preserved at the call site.
        let history = HistoryStore(enabled: true, maxEntries: config.historyMaxEntries)
        let volume = VolumeController()

        // Phase 5: the History window is a process-singleton with one
        // HistoryStore reference. Wire it before any UI can open the window.
        HistoryWindowController.store = history
        HistoryWindowController.inserter = inserter

        // Pre-warm the engine once at launch: whisper validates its paths;
        // Parakeet loads (and on first run downloads ~470 MB) its Core ML model.
        // When a Parakeet download is needed, the notch shows progress (via the
        // sink wired above) and clears when prepare() returns. A fresh install
        // has no whisper model either, so there is intentionally no
        // fallback-to-whisper — a dictation issued before the model is ready
        // simply awaits the in-flight load.
        Task {
            try? await engine.prepare()
            if parakeetNeedsDownload {
                await MainActor.run {
                    NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: nil)
                }
            }
        }

        appState = AppState(
            config: config,
            recorder: recorder,
            engine: engine,
            cleaner: cleaner,
            inserter: inserter,
            history: history,
            volume: volume,
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

        // Strong-capture is intentional: AudioRecorder is owned by AppState
        // (which lives as long as the AppDelegate). A weak capture has been
        // observed dropping to nil immediately after launch on some macOS
        // builds, leaving the spectrum bars stuck at zero.
        let recorderRef = recorder
        notch.levelProvider = { recorderRef.currentLevel() }
        notch.onStopRequested = { [weak self] in
            self?.appState.stopAndProcessDictation()
        }
        notch.onCancelRequested = { [weak self] in
            self?.appState.cancelIfNeeded()
        }
        notch.onRetryRequested = { [weak self] in
            self?.appState.toggleDictation()
        }
        appState.onPasteResult = { [weak self] result in
            switch result {
            case .pasted(let target):
                self?.notch.setSuccess(label: "Pasted into \(target.name)")
            case .copiedOnly:
                self?.notch.setSuccess(label: "Copied to clipboard")
            }
        }

        Notifier.bootstrap()
        // Pre-warm mic permission without blocking the main thread.
        DispatchQueue.global(qos: .utility).async {
            try? AudioRecorder().ensurePermission()
        }

        // Bridge: ModelsTab posts progress notifications when downloading a
        // Whisper model; the AppState turns them into MurmurState transitions
        // so the notch overlay shows a download progress bar.
        NotificationCenter.default.addObserver(
            forName: .murmurModelDownloadProgress,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let progress = note.object as? Double else { return }
            self?.appState.setDownloadingModel(progress: progress)
        }
        NotificationCenter.default.addObserver(
            forName: .murmurModelDownloadFinished,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appState.clearDownloadingModel()
        }

        // Phase 5: when the user toggles history in Settings → General, the
        // tab posts a `.murmurHistoryToggleChanged` notification carrying
        // the new Bool. We mutate AppState.config in-place so the next
        // dictation's gate sees the fresh value, and rebuild the menubar
        // so the "History…" item's enable-state updates immediately.
        // Without the live mutate, toggling OFF would still record history
        // until the next app restart (privacy regression).
        NotificationCenter.default.addObserver(
            forName: .murmurHistoryToggleChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let newValue = note.object as? Bool {
                self?.appState.config.historyEnabled = newValue
            }
            self?.rebuildMenu()
        }

        // Live appearance switching: Settings → General posts the new mode;
        // applying it to NSApp re-themes every window without a relaunch.
        NotificationCenter.default.addObserver(
            forName: .murmurAppearanceChanged,
            object: nil,
            queue: .main
        ) { note in
            if let mode = note.object as? AppearanceMode {
                mode.apply()
            }
        }

        Log.event(state: "launched", fields: [
            "ax_trusted": String(Self.isAXTrusted()),
            "mic_status": String(describing: AudioRecorder.authorizationStatus())
        ])

        if !Self.isAXTrusted() {
            Log.event(state: "ax_permission_missing")
        }

        // Phase 6: open the onboarding wizard on first launch (or any
        // launch where the saved completion version doesn't match the
        // current schema). Deferred until after the hotkey monitor and
        // notification observers are live so the wizard's "Test
        // dictation" step actually works.
        OnboardingWindowController.openIfNeeded()
    }

    func enableRecordOnceMode() {
        exitAfterNextDictation = true
    }

    private func handlePostDictationExitIfNeeded(_ state: MurmurState) {
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
        if let button = statusItem.button {
            button.image = Self.statusSymbol(named: "waveform", recording: false)
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    /// Status-bar glyph for the current state. Idle / transcribing / downloading
    /// use a *template* image so AppKit tints it to match the menu bar in both
    /// light and dark appearances; recording uses a fixed red mic so "live"
    /// reads regardless of appearance. Always carries an accessibility
    /// description so VoiceOver still announces "Murmur" in the symbol-only
    /// idle state (replacing the old literal "Murmur" text title).
    private static func statusSymbol(named name: String, recording: Bool) -> NSImage? {
        let desc = recording ? "Murmur — recording" : "Murmur"
        let base = NSImage(systemSymbolName: name, accessibilityDescription: desc)
        let sized = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if recording {
            let red = sized.applying(NSImage.SymbolConfiguration(paletteColors: [.systemRed]))
            let img = base?.withSymbolConfiguration(red) ?? base
            img?.isTemplate = false
            img?.accessibilityDescription = desc
            return img
        }
        let img = base?.withSymbolConfiguration(sized) ?? base
        img?.isTemplate = true
        img?.accessibilityDescription = desc
        return img
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let stateTitle = "Murmur: \(appState.state.displayName)"
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

        menu.addItem(NSMenuItem.separator())

        // Persistent accessibility nudge — the only state-dependent top-level
        // item, kept prominent because paste and the global hotkey both depend
        // on it. (Diagnostics + read-only status moved to a submenu below.)
        if !Self.isAXTrusted() {
            let warn = NSMenuItem(
                title: "⚠ Grant Accessibility Permission",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            warn.target = self
            menu.addItem(warn)
        }

        // At-a-glance recent transcripts.
        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyItem.submenu = buildHistorySubmenu()
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Phase 5: the dedicated History window. Enabled only when the
        // opt-in toggle is on; otherwise visible but disabled with a tooltip
        // so first-time users discover where to flip it.
        let historyEnabled = Config.loadOrCreateDefault().historyEnabled
        let historyWindowItem = NSMenuItem(
            title: "History…",
            action: #selector(openHistoryWindow),
            keyEquivalent: ""
        )
        historyWindowItem.target = self
        historyWindowItem.isEnabled = historyEnabled
        if !historyEnabled {
            historyWindowItem.toolTip = "Enable history in Settings → General first."
        }
        menu.addItem(historyWindowItem)

        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        let diagnosticsItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        diagnosticsItem.submenu = buildDiagnosticsSubmenu()
        menu.addItem(diagnosticsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        stateItemRef = stateItem
        applyLiveTitle()
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let elapsed = max(0, Int(seconds))
        if elapsed < 60 { return String(format: "0:%02d", elapsed) }
        return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    private func applyLiveTitle() {
        let menuLabel: String
        // Status-bar presentation: an SF Symbol per state plus a compact
        // trailing timer / percent. Replaces the old literal "Murmur" /
        // "● 0:05" text title with a native menu-bar glyph.
        var symbolName = "waveform"
        var recording = false
        var trailing = ""
        switch appState.state {
        case .recording:
            let elapsed = appState.recordingElapsedSeconds ?? 0
            symbolName = "mic.fill"
            recording = true
            trailing = " " + formatElapsed(elapsed)
            menuLabel = "Murmur: Recording… \(formatElapsed(elapsed))"
            notch.setRecording()
        case .transcribing:
            let elapsed = appState.transcribingElapsedSeconds ?? 0
            let recorded = appState.recordingElapsedSeconds ?? 0
            symbolName = "waveform"
            trailing = " " + formatElapsed(elapsed)
            menuLabel = "Murmur: Transcribing… \(formatElapsed(elapsed))  (\(formatElapsed(recorded)) audio)"
            notch.setProcessing(label: "Transcribing…")
        case .pasting:
            // The contextual success message ("Pasted into TextEdit") is set
            // by AppState.onPasteResult once paste actually completes — see
            // wiring below in applicationDidFinishLaunching. Don't show a
            // generic "Inserted" here, because the result may be
            // copied-only and the message should match reality.
            menuLabel = "Murmur: \(appState.state.displayName)"
        case .idle:
            menuLabel = "Murmur: \(appState.state.displayName)"
            notch.hide()
        case .error(let message):
            menuLabel = "Murmur: \(appState.state.displayName)"
            notch.setError(label: message)
        case .downloadingModel(let progress):
            symbolName = "arrow.down.circle"
            trailing = " \(Int((progress * 100).rounded()))%"
            menuLabel = "Murmur: \(appState.state.displayName)"
            notch.setDownloading(progress: progress)
        }
        if let button = statusItem.button {
            button.image = Self.statusSymbol(named: symbolName, recording: recording)
            button.imagePosition = trailing.isEmpty ? .imageOnly : .imageLeading
            button.title = trailing
        }
        stateItemRef?.title = menuLabel
    }

    private func refreshDurationTimer(state: MurmurState) {
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
                if let timer = durationTimer { RunLoop.main.add(timer, forMode: .common) }
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
        Task {
            do {
                try await appState.engine.prepare()
                await MainActor.run { Notifier.success("Transcription setup looks valid.") }
            } catch {
                await MainActor.run { Notifier.warn(String(describing: error)) }
            }
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(Config.defaultConfigURL())
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(Config.logsDirectoryURL())
    }

    /// Gates menubar actions. Only `openHistoryWindow` has dynamic enable
    /// state today — every other selector returns true (matches default
    /// AppKit behavior). Called automatically by AppKit before the menu
    /// renders, which means the toggle in Settings → General takes effect
    /// the next time the user opens the menubar.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(openHistoryWindow) {
            return Config.loadOrCreateDefault().historyEnabled
        }
        return true
    }

    @objc private func openHistoryWindow() {
        HistoryWindowController.shared.showWindow(nil)
    }

    @objc func openSettings() {
        settingsWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func checkForUpdates() {
        MainActor.assumeIsolated {
            SparkleUpdater.shared.checkForUpdates()
        }
    }

    /// Developer / troubleshooting actions plus read-only config status,
    /// grouped out of the top-level menu so the menubar stays quiet and
    /// consumer-facing. Every action that used to live at the top level is
    /// preserved here verbatim.
    private func buildDiagnosticsSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let rawItem = NSMenuItem(
            title: "Raw Transcript Mode: \(appState.config.rawTranscriptMode ? "On" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        rawItem.isEnabled = false
        submenu.addItem(rawItem)

        let debugItem = NSMenuItem(
            title: "Debug Retain Audio: \(appState.config.debugRetainAudio ? "On" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        debugItem.isEnabled = false
        submenu.addItem(debugItem)

        submenu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "Test Setup", action: #selector(testWhisperSetup), keyEquivalent: "")
        testItem.target = self
        submenu.addItem(testItem)

        let configItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
        configItem.target = self
        submenu.addItem(configItem)

        let logsItem = NSMenuItem(title: "Open Logs Folder", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        submenu.addItem(logsItem)

        return submenu
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

        let openItem = NSMenuItem(
            title: "Open Full History File…",
            action: #selector(openHistoryFile),
            keyEquivalent: ""
        )
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

let mode: CLIMode
do {
    mode = try CLI.parse(CommandLine.arguments)
} catch {
    let msg = "Murmur error: \(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(msg.utf8))
    exit(2)
}
switch mode {
case .help:
    CLI.runHelp()
    exit(0)
case .version:
    CLI.runVersion()
    exit(0)
case .transcribeOnly(let wav, let profile, let language, let modelName, let vocabularyURL, let engine):
    exit(CLI.runTranscribeOnly(
        wav: wav,
        profile: profile,
        language: language,
        modelName: modelName,
        vocabularyURL: vocabularyURL,
        engine: engine
    ))
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
// swiftlint:enable file_length
