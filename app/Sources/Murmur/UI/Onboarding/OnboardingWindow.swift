// SwiftUI root + step views for the first-launch wizard.
//
// The window is sized 640×520 and non-resizable (style mask in
// `OnboardingWindowController` enforces that). Layout is split into three
// horizontal bands: a header with the step indicator, a flex-height body
// holding the current step's view, and a footer with Back / Skip / Next
// buttons. Each step has its own subview so the body can swap content
// without disturbing the chrome.
//
// Permission polling for the accessibility step uses a Timer scheduled on
// the SwiftUI view lifecycle. We cancel on `.onDisappear` so dismissing
// the window mid-wizard doesn't leak a tick. AVCaptureDevice's prompt is
// async so the microphone step uses `Task { @MainActor in }`.
import AppKit
import Combine
import SwiftUI

// MARK: - Root

struct OnboardingRoot: View {
    @StateObject private var model = OnboardingModel()

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(current: model.step)
                .padding(.top, 18)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

            Divider()

            Group {
                switch model.step {
                case .welcome:       WelcomeStepView(model: model)
                case .howItWorks:    HowItWorksStepView(model: model)
                case .microphone:    MicrophoneStepView(model: model)
                case .accessibility: AccessibilityStepView(model: model)
                case .model:         ModelStepView(model: model)
                case .test:          TestDictationStepView(model: model)
                case .done:          DoneStepView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)

            Divider()

            OnboardingFooter(model: model)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: - View model

@MainActor
final class OnboardingModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var selectedModelName: String? = nil
    @Published var modelDownloadInFlight: Bool = false
    @Published var modelDownloadProgress: Double = 0
    @Published var lastDictationText: String = ""
    @Published var dictationConfirmed: Bool = false

    let modelManager = ModelManager()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Read current values so the wizard reflects whatever the user has
        // already granted (matters most when they reopen via the About tab).
        self.microphoneStatus = PermissionsProbe.microphone()
        self.accessibilityStatus = PermissionsProbe.accessibility()
        // Default selection to Base.en — the recommended balance.
        self.selectedModelName = modelManager.manifest
            .entry(named: "ggml-base.en")?.name

        // Bridge nested ObservableObject changes upstream. Without this,
        // SwiftUI views observing OnboardingModel won't re-render when
        // ModelManager publishes a download progress tick or finishes
        // installation — meaning the "Continue" button on the model step
        // would stay disabled even after the download lands.
        modelManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func goNext() {
        if let next = step.next() {
            step = next
        }
    }

    func goBack() {
        if let prev = step.previous() {
            step = prev
        }
    }

    func skip() {
        guard step.isSkippable else { return }
        goNext()
    }

    /// Whether the "Next" / primary button on the current step should be
    /// enabled. Most steps gate on nothing; the model step requires a
    /// completed download.
    var canAdvance: Bool {
        switch step {
        case .model:
            guard let name = selectedModelName else { return false }
            return modelManager.isInstalled(name) && !modelDownloadInFlight
        default:
            return true
        }
    }

    func finish() {
        OnboardingWindowController.markComplete()
        OnboardingWindowController.shared.close()
    }
}

// MARK: - Header (progress indicator)

private struct OnboardingHeader: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(OnboardingStep.visibleSteps.enumerated()), id: \.element) { idx, step in
                Capsule()
                    .fill(color(for: step))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        if step == current {
                            Capsule().fill(.white.opacity(0.0))
                        }
                    }
                    .accessibilityLabel("Step \(idx + 1) of \(OnboardingStep.visibleSteps.count): \(step.title)")
            }
        }
    }

    private func color(for step: OnboardingStep) -> Color {
        if step == current                 { return .accentColor }
        if step.ordinal < current.ordinal { return .accentColor.opacity(0.5) }
        return Color.secondary.opacity(0.25)
    }
}

// MARK: - Footer (Back / Skip / Next)

private struct OnboardingFooter: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        HStack {
            if model.step != .welcome && model.step != .done {
                Button("Back") { model.goBack() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            if model.step.isSkippable && model.step != .welcome && model.step != .done {
                Button("Skip") { model.skip() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            if model.step == .done {
                Button("Open Murmur") { model.finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(primaryTitle) { model.goNext() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canAdvance)
            }
        }
    }

    private var primaryTitle: String {
        switch model.step {
        case .welcome: return "Begin"
        case .test:    return "Continue"
        case .model:   return "Continue"
        default:       return "Next"
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Murmur")
                        .font(.system(size: 38, weight: .bold))
                    Text("Local-first voice typing for the Mac")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Murmur listens, transcribes, and pastes — all on this Mac. Nothing ever leaves the machine. Set it up once and double-tap fn to dictate into any app.")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                BulletRow(icon: "lock.fill",      text: "100% offline — no cloud, no telemetry")
                BulletRow(icon: "keyboard",       text: "Hold-to-talk hotkey works in every app")
                BulletRow(icon: "speaker.wave.2", text: "Music auto-mutes while you dictate")
            }

            Spacer()
        }
    }
}

private struct BulletRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.tint)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

// MARK: - Step 2: How it works

private struct HowItWorksStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works")
                .font(.title2).bold()
            Text("Three beats, every time you dictate.")
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 18) {
                ActCard(numeral: "I", title: "Trigger",
                        copy: "Double-tap fn. The notch pulses red. Music ducks to a whisper.")
                ActCard(numeral: "II", title: "Speak",
                        copy: "Say what you mean. Audio never leaves your Mac.")
                ActCard(numeral: "III", title: "Land",
                        copy: "Stop with fn again. Murmur pastes clean text into the focused app.")
            }

            Spacer()
        }
    }
}

private struct ActCard: View {
    let numeral: String
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(numeral)
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text(copy)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Step 3: Microphone

private struct MicrophoneStepView: View {
    @ObservedObject var model: OnboardingModel
    @State private var requestInFlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Microphone access")
                .font(.title2).bold()
            Text("Murmur needs the microphone to capture your voice. Audio stays local — it's transcribed on this Mac and discarded.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statusPill
                Spacer()
                actionButton
            }

            if model.microphoneStatus == .denied {
                Text("If you previously declined, open System Settings → Privacy & Security → Microphone and toggle Murmur back on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Microphone settings") {
                    PermissionsProbe.openMicrophoneSettings()
                }
                .buttonStyle(.link)
            }

            Spacer()
        }
        .onAppear { model.microphoneStatus = PermissionsProbe.microphone() }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.microphoneStatus {
        case .granted:
            StatusPill(text: "Granted", systemImage: "checkmark.seal.fill", color: .green)
        case .denied:
            StatusPill(text: "Denied",  systemImage: "xmark.seal.fill",     color: .red)
        case .notDetermined:
            StatusPill(text: "Not granted", systemImage: "circle.dashed",  color: .secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if model.microphoneStatus == .granted {
            EmptyView()
        } else {
            Button(action: requestMic) {
                if requestInFlight {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("Enable microphone")
                }
            }
            .buttonStyle(.bordered)
            .disabled(requestInFlight)
        }
    }

    private func requestMic() {
        requestInFlight = true
        Task { @MainActor in
            let status = await PermissionsProbe.requestMicrophone()
            model.microphoneStatus = status
            requestInFlight = false
        }
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.callout)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - Step 4: Accessibility

private struct AccessibilityStepView: View {
    @ObservedObject var model: OnboardingModel
    @State private var pollTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Accessibility access")
                .font(.title2).bold()
            Text("Accessibility lets Murmur paste transcribed text into the app you're using. It's also how the global double-tap-fn hotkey works.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statusPill
                Spacer()
                if model.accessibilityStatus != .granted {
                    Button("Open System Settings") {
                        PermissionsProbe.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if model.accessibilityStatus != .granted {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In System Settings:")
                        .font(.footnote).bold()
                        .foregroundStyle(.secondary)
                    Text("1. Find “Murmur” in the list.")
                    Text("2. Toggle it on.")
                    Text("3. Return here — this screen advances automatically.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Spacer()
        }
        .onAppear(perform: startPolling)
        .onDisappear(perform: stopPolling)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.accessibilityStatus {
        case .granted:
            StatusPill(text: "Granted", systemImage: "checkmark.seal.fill", color: .green)
        case .denied:
            StatusPill(text: "Waiting…", systemImage: "hourglass",          color: .orange)
        case .notDetermined:
            StatusPill(text: "Not granted", systemImage: "circle.dashed",  color: .secondary)
        }
    }

    private func startPolling() {
        model.accessibilityStatus = PermissionsProbe.accessibility()
        guard model.accessibilityStatus != .granted else { return }
        // Capture once: the cosmetic "let them see the green tick" pause is
        // skipped under Reduce Motion — it's a flourish, not navigation.
        let skipBeat = reduceMotion
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                let status = PermissionsProbe.accessibility()
                model.accessibilityStatus = status
                if status == .granted {
                    stopPolling()
                    // Brief beat so the user sees the green tick before we
                    // advance to the next step.
                    if !skipBeat {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                    }
                    model.goNext()
                }
            }
        }
        if let t = pollTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - Step 5: Pick a model

private struct ModelStepView: View {
    @ObservedObject var model: OnboardingModel
    @State private var downloadError: String?

    /// The three curated picks for first-launch. Power users can install the
    /// other manifest entries from Settings → Models afterward.
    private let curatedNames = ["ggml-tiny.en", "ggml-base.en", "ggml-small.en"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a model")
                .font(.title2).bold()
            Text("Choose the Whisper model that best matches your Mac. Bigger is more accurate; smaller is faster. You can change this later in Settings → Models.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(curatedEntries, id: \.name) { entry in
                    ModelCard(
                        entry: entry,
                        isSelected: model.selectedModelName == entry.name,
                        isInstalled: model.modelManager.isInstalled(entry.name),
                        progress: model.modelManager.downloads[entry.name],
                        onSelect: {
                            model.selectedModelName = entry.name
                            persistSelection(name: entry.name)
                        },
                        onDownload: { Task { await downloadAction(entry) } }
                    )
                }
            }

            if let error = downloadError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }

            Text("Models live in ~/Library/Application Support/Murmur/Models/.")
                .font(.footnote).foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var curatedEntries: [ModelManifest.Entry] {
        curatedNames.compactMap { model.modelManager.manifest.entry(named: $0) }
    }

    private func downloadAction(_ entry: ModelManifest.Entry) async {
        downloadError = nil
        model.modelDownloadInFlight = true
        defer { model.modelDownloadInFlight = false }
        do {
            try await model.modelManager.download(entry)
            model.selectedModelName = entry.name
            persistSelection(name: entry.name)
            // Mirror the existing ModelsTab behavior so the notch overlay
            // can clear its progress bar.
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: entry.name)
        } catch {
            downloadError = "Download failed: \(error)"
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: entry.name)
        }
    }

    private func persistSelection(name: String) {
        do {
            var cfg = Config.loadOrCreateDefault()
            let path = AppPaths.modelsDirectory
                .appendingPathComponent("\(name).bin").path
            cfg.modelPath = path
            try cfg.save()
            // Also nudge AppStorage so the Settings → Models tab reflects
            // the wizard's pick without a relaunch.
            UserDefaults.standard.set(name, forKey: "settings.selectedModelName")
        } catch {
            downloadError = "Couldn't save selection: \(error)"
        }
    }
}

private struct ModelCard: View {
    let entry: ModelManifest.Entry
    let isSelected: Bool
    let isInstalled: Bool
    let progress: Double?
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName).font(.body).bold()
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(entry.sizeMB) MB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            controls
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { if isInstalled { onSelect() } }
    }

    @ViewBuilder
    private var controls: some View {
        if let p = progress {
            VStack(alignment: .trailing, spacing: 2) {
                ProgressView(value: p).frame(width: 100)
                Text("\(Int((p * 100).rounded()))%")
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        } else if isInstalled {
            Button(isSelected ? "Selected" : "Use") { onSelect() }
                .buttonStyle(.bordered)
                .disabled(isSelected)
        } else {
            Button("Download", action: onDownload).buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Step 6: Test dictation

private struct TestDictationStepView: View {
    @ObservedObject var model: OnboardingModel

    /// The prompt the user is asked to say. Comparison is case- and
    /// punctuation-insensitive so "Murmur is ready." matches "murmur is ready".
    private let promptText = "Murmur is ready"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test dictation")
                .font(.title2).bold()
            Text("Double-tap fn and say:")
                .foregroundStyle(.secondary)
            Text("“\(promptText)”")
                .font(.system(.title3, design: .serif).italic())
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text("What we heard")
                    .font(.caption).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    Text(model.lastDictationText.isEmpty
                         ? "Waiting for dictation…"
                         : model.lastDictationText)
                        .font(.body)
                        .foregroundStyle(model.lastDictationText.isEmpty ? .secondary : .primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 110)
            }

            if model.dictationConfirmed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Heard you loud and clear.").foregroundStyle(.green)
                }
                .font(.callout)
            }

            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .murmurDictationCleanedText)) { note in
            guard let text = note.object as? String else { return }
            model.lastDictationText = text
            if matchesPrompt(text) {
                model.dictationConfirmed = true
            }
        }
    }

    private func matchesPrompt(_ heard: String) -> Bool {
        let normalize: (String) -> String = { raw in
            raw.lowercased()
               .components(separatedBy: CharacterSet.alphanumerics.inverted)
               .filter { !$0.isEmpty }
               .joined(separator: " ")
        }
        return normalize(heard).contains(normalize(promptText))
    }
}

// MARK: - Step 7: Done

private struct DoneStepView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("You're all set.")
                .font(.title).bold()
            Text("Double-tap fn anywhere on your Mac to dictate. You can revisit this guide from Settings → About → Run setup again.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
