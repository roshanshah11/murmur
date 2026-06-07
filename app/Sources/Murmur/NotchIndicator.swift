// self-contained notch overlay; splitting the view + animation helpers hurts readability
// swiftlint:disable file_length
import AppKit
import QuartzCore

/// macOS notch-style transcription overlay. Looks like a dark pill dripping
/// out of the camera notch. Internal layout morphs between several states:
/// idle, recording (with optional hover-revealed controls), processing,
/// success, error. The pill grows / shrinks via panel.setFrame animations
/// while subviews crossfade between state-specific layouts.
final class NotchIndicator {

    // MARK: - State

    enum State: Equatable {
        case hidden
        case idle
        case recording
        case processing(label: String)
        case downloading(progress: Double)
        case success(label: String)
        case error(label: String)
    }

    // External callbacks the menu app wires up.
    var onStopRequested: (() -> Void)?
    var onCancelRequested: (() -> Void)?
    var onRetryRequested: (() -> Void)?
    var levelProvider: (() -> Float)?

    // MARK: - Internal

    private var panel: NSPanel?
    private var pill: NotchPillView?
    private var visible = false
    private(set) var state: State = .hidden
    private var hovered = false
    private var elapsedTextTimer: Timer?
    private var levelPollTimer: Timer?
    private var recordingStartedAt: Date?
    private var dismissTimer: Timer?

    // Tunables shared with the pill view.
    private static let visibleHeight: CGFloat = 36
    private static let fallbackSafeTop: CGFloat = 32
    // M-series 14" / 16" MacBook notch is ~215pt wide. Used when
    // auxiliaryTop areas are unavailable.
    private static let fallbackNotchWidth: CGFloat = 215
    // Tight overhang so the pill reads as "the notch grew a little",
    // not as a separate widget floating below.
    private static let extraOverhang: CGFloat = 4
    private let openDuration: CFTimeInterval = 0.18
    private let closeDuration: CFTimeInterval = 0.14
    private let morphDuration: CFTimeInterval = 0.22
    private let springTiming = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.2, 1.0)
    private let easeInTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)

    // MARK: - Public API

    func setIdle() {
        ensureBuilt()
        applyState(.idle)
    }

    func setRecording() {
        ensureBuilt()
        // Idempotent: caller invokes this every menu-bar tick (~0.5s) while
        // recording, so only stamp the start time on transition in.
        if case .recording = state {
            applyState(.recording)
        } else {
            recordingStartedAt = Date()
            applyState(.recording)
        }
    }

    func setProcessing(label: String = "Transcribing…") {
        ensureBuilt()
        applyState(.processing(label: label))
    }

    /// Surface model-download progress (0…1) in place of the spectrum bars.
    /// Auto-clamped to the valid range so a transient overshoot from the
    /// download delegate doesn't violate the progress-bar invariant.
    func setDownloading(progress: Double) {
        ensureBuilt()
        let clamped = max(0.0, min(1.0, progress))
        applyState(.downloading(progress: clamped))
    }

    func setSuccess(label: String) {
        ensureBuilt()
        applyState(.success(label: label))
        // Hold long enough to actually read the confirmation; upstream
        // state machine may have already moved to .idle.
        scheduleDismiss(after: 1.6)
    }

    func setError(label: String) {
        ensureBuilt()
        applyState(.error(label: label))
        // Errors stay until user clicks Retry or the next state is set.
    }

    func hide() {
        guard visible else { return }
        // Don't let an upstream `idle` transition wipe out an active success
        // flash — the dismiss timer is the sole driver of success → hide.
        if case .success = state, dismissTimer != nil { return }
        applyState(.hidden)
    }

    // MARK: - State transitions

    private func applyState(_ next: State) {
        let prev = state
        state = next
        invalidateAutoDismissIfNotSuccess(next)
        switch next {
        case .hidden:
            stopElapsedTextTimer()
            stopLevelPoll()
            visible = false
            animateCollapsedAndHide()
        case .idle:
            pill?.applyState(.idle, hovered: false, recordingStartedAt: nil)
            startElapsedTextTimerIfNeeded()
            stopLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .idle, hovered: false) ?? 240)
        case .recording:
            pill?.applyState(.recording, hovered: hovered, recordingStartedAt: recordingStartedAt)
            startElapsedTextTimerIfNeeded()
            startLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .recording, hovered: hovered) ?? 280)
        case .processing(let label):
            pill?.processingLabel = label
            pill?.applyState(.processing(label: label), hovered: false, recordingStartedAt: recordingStartedAt)
            stopElapsedTextTimer()
            stopLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .processing(label: label), hovered: false) ?? 290)
        case .downloading(let progress):
            pill?.downloadProgress = progress
            pill?.applyState(.downloading(progress: progress), hovered: false, recordingStartedAt: nil)
            stopElapsedTextTimer()
            stopLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .downloading(progress: progress), hovered: false) ?? 320)
        case .success(let label):
            pill?.successLabel = label
            pill?.applyState(.success(label: label), hovered: false, recordingStartedAt: nil)
            stopElapsedTextTimer()
            stopLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .success(label: label), hovered: false) ?? 200)
        case .error(let label):
            pill?.errorLabel = label
            pill?.applyState(.error(label: label), hovered: false, recordingStartedAt: nil)
            stopElapsedTextTimer()
            stopLevelPoll()
            present(targetWidth: pill?.intrinsicWidth(for: .error(label: label), hovered: false) ?? 320)
        }
        if !next.isRecording { recordingStartedAt = nil }
        _ = prev
    }

    private func invalidateAutoDismissIfNotSuccess(_ next: State) {
        if case .success = next { return }
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Clear the timer BEFORE calling hide(), otherwise hide()'s
            // own guard ("don't dismiss while success timer is pending")
            // would block us from collapsing — exactly the dead end the
            // user reported.
            self.dismissTimer = nil
            self.applyState(.hidden)
        }
    }

    // MARK: - Geometry / animation

    private struct NotchGeometry {
        let screen: NSScreen
        let centerX: CGFloat   // notch horizontal midpoint, in global coords
        let topY: CGFloat      // screen.frame.maxY (top of physical screen)
        let safeTop: CGFloat   // notch height (or menu bar height on non-notch)
        let notchWidth: CGFloat
        let hasNotch: Bool
    }

    private func currentGeometry() -> NotchGeometry? {
        // Prefer the screen that physically has the notch. `NSScreen.screens.first`
        // is the LEFTMOST screen by arrangement, which on multi-monitor setups
        // is often an external display with no notch.
        let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        let screen = notched ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return nil }

        let safe = screen.safeAreaInsets.top
        let hasNotch = safe > 0

        var centerX = screen.frame.midX
        var notchW: CGFloat = hasNotch ? Self.fallbackNotchWidth : 160

        // macOS 12+ exposes the menu bar regions flanking the notch.
        if hasNotch {
            let aL = screen.auxiliaryTopLeftArea
            let aR = screen.auxiliaryTopRightArea
            if let aL, let aR {
                centerX = (aL.maxX + aR.minX) / 2
                notchW = max(80, aR.minX - aL.maxX)
            }
        }

        return NotchGeometry(
            screen: screen,
            centerX: centerX,
            topY: screen.frame.maxY,
            safeTop: hasNotch ? safe : Self.fallbackSafeTop,
            notchWidth: notchW,
            hasNotch: hasNotch
        )
    }

    private func expandedFrame(width: CGFloat, geo: NotchGeometry) -> NSRect {
        // Panel now covers ONLY the drip below the notch — height =
        // visibleHeight. Concave top corners (drawn at the panel's top
        // edge) sit exactly at the notch's bottom edge and visually mate
        // with the notch's outer curves.
        let panelWidth = max(geo.notchWidth + Self.extraOverhang * 2, width)
        return NSRect(
            x: geo.centerX - panelWidth / 2,
            y: geo.topY - geo.safeTop - Self.visibleHeight,
            width: panelWidth,
            height: Self.visibleHeight
        )
    }

    private func collapsedFrame(width: CGFloat, geo: NotchGeometry) -> NSRect {
        let panelWidth = max(geo.notchWidth + Self.extraOverhang * 2, width)
        return NSRect(
            x: geo.centerX - panelWidth / 2,
            y: geo.topY - geo.safeTop,
            width: panelWidth,
            height: 0
        )
    }

    private func present(targetWidth: CGFloat) {
        guard let panel, let geo = currentGeometry() else { return }
        let target = expandedFrame(width: targetWidth, geo: geo)
        if !visible {
            panel.setFrame(collapsedFrame(width: targetWidth, geo: geo), display: false)
            panel.orderFrontRegardless()
            visible = true
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = openDuration
                ctx.timingFunction = springTiming
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }, completionHandler: nil)
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = morphDuration
                ctx.timingFunction = springTiming
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }, completionHandler: nil)
        }
    }

    private func animateCollapsedAndHide() {
        guard let panel, let geo = currentGeometry() else { return }
        let target = collapsedFrame(width: pill?.frame.width ?? 240, geo: geo)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = closeDuration
            ctx.timingFunction = easeInTiming
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    // MARK: - Live updates

    private func startElapsedTextTimerIfNeeded() {
        if elapsedTextTimer != nil { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pill?.refreshLiveText(recordingStartedAt: self?.recordingStartedAt)
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTextTimer = timer
    }

    private func stopElapsedTextTimer() {
        elapsedTextTimer?.invalidate()
        elapsedTextTimer = nil
    }

    private func startLevelPoll() {
        if levelPollTimer != nil { return }
        // SpectrumBarsView has its own 30Hz tick; we just need to feed it the
        // current mic level. 30Hz is plenty.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let lvl = self.levelProvider?() ?? 0
            self.pill?.updateLevel(lvl)
        }
        RunLoop.main.add(timer, forMode: .common)
        levelPollTimer = timer
        pill?.startBars()
    }

    private func stopLevelPoll() {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
    }

    // MARK: - Hover handling

    fileprivate func setHovered(_ isHovered: Bool) {
        guard hovered != isHovered else { return }
        hovered = isHovered
        guard case .recording = state else { return }
        // Re-apply recording state with new hover flag so layout + width change.
        applyState(.recording)
    }

    // MARK: - Build

    private func ensureBuilt() {
        guard panel == nil else { return }
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        newPanel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.ignoresMouseEvents = false   // need hover detection
        newPanel.isMovable = false
        newPanel.animationBehavior = .none

        let view = NotchPillView()
        view.visibleHeight = Self.visibleHeight
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.width, .height]
        view.frame = NSRect(origin: .zero, size: newPanel.frame.size)
        view.onHover = { [weak self] isHovered in self?.setHovered(isHovered) }
        view.onStop = { [weak self] in self?.onStopRequested?() }
        view.onCancel = { [weak self] in self?.onCancelRequested?() }
        view.onRetry = { [weak self] in self?.onRetryRequested?() }
        newPanel.contentView = view
        self.panel = newPanel
        self.pill = view
    }
}

private extension NotchIndicator.State {
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

// MARK: - NotchPillView

// cohesive notch pill view; the layout/state logic belongs together
// swiftlint:disable:next type_body_length
final class NotchPillView: NSView {

    // External hooks
    var onHover: ((Bool) -> Void)?
    var onStop: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?

    // Layout config
    var visibleHeight: CGFloat = 38

    // Mutable per-state labels
    var processingLabel: String = "Transcribing…"
    var successLabel: String = "Inserted"
    var errorLabel: String = "Couldn't transcribe"
    /// Current model-download progress (0…1) for `.downloading` state.
    /// Stored so `layout()` can size the progress fill without re-receiving
    /// the value through `applyState`.
    var downloadProgress: Double = 0 {
        didSet { needsLayout = true }
    }

    // State-dependent intrinsic widths for the morph animation.
    func intrinsicWidth(for state: NotchIndicator.State, hovered: Bool) -> CGFloat {
        switch state {
        case .hidden:
            return 230
        case .idle:
            return 260
        case .recording:
            return hovered ? 400 : 300
        case .processing:
            return 300
        case .downloading:
            return 320
        case .success(let label):
            return max(220, 110 + estimatedWidth(label))
        case .error(let label):
            return max(280, 140 + estimatedWidth(label))
        }
    }

    private func estimatedWidth(_ text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]
        return (text as NSString).size(withAttributes: attrs).width
    }

    // MARK: - Subviews

    private let micIcon = NSImageView()
    private let primaryLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    private let timerLabel = NSTextField(labelWithString: "")
    private let bars = SpectrumBarsView()
    private let stopButton = NotchPillButton(title: "Stop")
    private let cancelButton = NotchPillButton(title: "Cancel")
    private let retryButton = NotchPillButton(title: "Retry")
    private let glowLayer = CALayer()
    /// Subtle rim highlight tracing the pill silhouette — a faint glassy lip
    /// that gives the notch a more dimensional, "premium panel" feel. Drawn
    /// with the SAME path as the mask, so it can never read as a misaligned
    /// rectangle along the concave top corners.
    private let rimHighlight = CAShapeLayer()
    /// Track + fill views for the model-download progress bar. Two flat
    /// NSViews so they can be alpha-crossfaded by the existing helper.
    private let progressTrack = NSView()
    private let progressFill = NSView()
    private var trackingArea: NSTrackingArea?
    private var currentState: NotchIndicator.State = .hidden
    private var hoveredNow = false

    private static let primaryTextColor = NSColor(white: 1.0, alpha: 0.96)
    private static let secondaryTextColor = NSColor(white: 1.0, alpha: 0.58)
    private static let recColor = NSColor.systemRed
    private static let successColor = NSColor(srgbRed: 0.32, green: 0.86, blue: 0.55, alpha: 1)
    private static let errorColor = NSColor(srgbRed: 1.0, green: 0.45, blue: 0.35, alpha: 1)

    private var maskShape: CAShapeLayer?
    private let topCornerR: CGFloat = 8
    private let bottomCornerR: CGFloat = 18

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = false
        // Custom NotchShape mask: small concave indents at the top corners
        // mate with the notch's outer curves; bottom corners are convex
        // round. Path is rebuilt every layout pass so it tracks the
        // panel's animated height.
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = NSColor.black.cgColor
        layer?.mask = maskLayer
        maskShape = maskLayer

        glowLayer.cornerRadius = 18
        glowLayer.shadowColor = Self.recColor.cgColor
        glowLayer.shadowOpacity = 0.0
        glowLayer.shadowRadius = 12
        glowLayer.shadowOffset = .zero
        layer?.addSublayer(glowLayer)

        // Rim highlight sits above the black fill but below the content
        // subviews. Faint enough to read as a glassy edge, never a border.
        rimHighlight.fillColor = NSColor.clear.cgColor
        rimHighlight.strokeColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        rimHighlight.lineWidth = 1.5
        layer?.addSublayer(rimHighlight)

        micIcon.imageScaling = .scaleProportionallyUpOrDown
        micIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        addSubview(micIcon)

        primaryLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        primaryLabel.textColor = Self.recColor
        primaryLabel.lineBreakMode = .byTruncatingTail
        primaryLabel.usesSingleLineMode = true
        addSubview(primaryLabel)

        secondaryLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        secondaryLabel.textColor = Self.primaryTextColor
        secondaryLabel.lineBreakMode = .byTruncatingTail
        secondaryLabel.usesSingleLineMode = true
        addSubview(secondaryLabel)

        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
        timerLabel.textColor = Self.primaryTextColor
        timerLabel.lineBreakMode = .byTruncatingTail
        timerLabel.usesSingleLineMode = true
        addSubview(timerLabel)

        addSubview(bars)

        // Download progress bar: thin pill-shaped track with a red fill.
        // Hidden until applyState swaps in the .downloading layout.
        progressTrack.wantsLayer = true
        progressTrack.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        progressTrack.layer?.cornerRadius = 3
        progressTrack.alphaValue = 0
        addSubview(progressTrack)

        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = Self.recColor.cgColor
        progressFill.layer?.cornerRadius = 3
        progressFill.alphaValue = 0
        addSubview(progressFill)

        stopButton.onClick = { [weak self] in self?.onStop?() }
        cancelButton.onClick = { [weak self] in self?.onCancel?() }
        retryButton.onClick = { [weak self] in self?.onRetry?() }
        addSubview(stopButton)
        addSubview(cancelButton)
        addSubview(retryButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hoveredNow = true
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredNow = false
        onHover?(false)
    }

    // per-state layout switch; splitting hurts readability of the state machine
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func applyState(_ state: NotchIndicator.State, hovered: Bool, recordingStartedAt: Date?) {
        let previousState = currentState
        currentState = state
        hoveredNow = hovered

        // Ensure all subviews are unhidden so alpha can animate. Hidden
        // views skip layout/animation, which would cause pops.
        for subview in [primaryLabel, secondaryLabel, timerLabel, micIcon, bars,
                        stopButton, cancelButton, retryButton,
                        progressTrack, progressFill] as [NSView] {
            subview.isHidden = false
        }

        // Mic-pulse: on for recording, off elsewhere. Triggered AFTER the
        // configure step below so the icon image is set first.
        let wasRecording: Bool = { if case .recording = previousState { return true }; return false }()
        let isRecordingNow: Bool = { if case .recording = state { return true }; return false }()
        let isSuccessNow: Bool = { if case .success = state { return true }; return false }()
        let wasSuccess: Bool = { if case .success = previousState { return true }; return false }()

        switch state {
        case .hidden:
            stopMicPulse()
            crossfade(targets: [
                (primaryLabel, 0), (secondaryLabel, 0), (timerLabel, 0),
                (micIcon, 0), (bars, 0),
                (stopButton, 0), (cancelButton, 0), (retryButton, 0),
                (progressTrack, 0), (progressFill, 0)
            ])
            return

        case .idle:
            micIcon.contentTintColor = NSColor(white: 1.0, alpha: 0.48)
            micIcon.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microphone")
            secondaryLabel.textColor = Self.secondaryTextColor
            secondaryLabel.stringValue = "Double-tap fn"
            bars.mode = .idle
            glowLayer.shadowOpacity = 0.0
            crossfade(targets: [
                (micIcon, 1), (secondaryLabel, 1), (bars, 0.45),
                (primaryLabel, 0), (timerLabel, 0),
                (stopButton, 0), (cancelButton, 0), (retryButton, 0),
                (progressTrack, 0), (progressFill, 0)
            ])

        case .recording:
            micIcon.contentTintColor = Self.recColor
            micIcon.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            primaryLabel.textColor = Self.recColor
            primaryLabel.stringValue = "REC"
            bars.mode = .live
            timerLabel.stringValue = elapsed(from: recordingStartedAt)
            glowLayer.shadowColor = Self.recColor.cgColor
            glowLayer.shadowOpacity = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 0.4
            glowLayer.shadowRadius = 10
            crossfade(targets: [
                (micIcon, 1), (primaryLabel, 1), (bars, 1), (timerLabel, 1),
                (secondaryLabel, 0), (retryButton, 0),
                (stopButton, hovered ? 1 : 0),
                (cancelButton, hovered ? 1 : 0),
                (progressTrack, 0), (progressFill, 0)
            ])

        case .processing(let label):
            micIcon.contentTintColor = NSColor(white: 1.0, alpha: 0.75)
            micIcon.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Processing")
            secondaryLabel.textColor = Self.primaryTextColor
            secondaryLabel.stringValue = label
            bars.mode = .processing
            timerLabel.stringValue = elapsed(from: recordingStartedAt)
            glowLayer.shadowOpacity = 0.0
            crossfade(targets: [
                (micIcon, 1), (secondaryLabel, 1), (bars, 0.85), (timerLabel, 1),
                (primaryLabel, 0), (stopButton, 0), (cancelButton, 0), (retryButton, 0),
                (progressTrack, 0), (progressFill, 0)
            ])

        case .downloading(let progress):
            // Bars get hidden in favor of a single thin progress strip.
            // Mic icon flips to the download glyph; secondary label shows
            // "Downloading model" so the notch never has anonymous progress.
            micIcon.contentTintColor = Self.primaryTextColor
            micIcon.image = NSImage(systemSymbolName: "arrow.down.circle",
                                    accessibilityDescription: "Downloading model")
            secondaryLabel.textColor = Self.primaryTextColor
            secondaryLabel.stringValue = "Downloading model"
            timerLabel.stringValue = "\(Int((progress * 100).rounded()))%"
            downloadProgress = progress
            glowLayer.shadowOpacity = 0.0
            crossfade(targets: [
                (micIcon, 1), (secondaryLabel, 1), (timerLabel, 1),
                (progressTrack, 1), (progressFill, 1),
                (primaryLabel, 0), (bars, 0),
                (stopButton, 0), (cancelButton, 0), (retryButton, 0)
            ])

        case .success(let label):
            micIcon.contentTintColor = Self.successColor
            micIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
            secondaryLabel.textColor = Self.successColor
            secondaryLabel.stringValue = label
            glowLayer.shadowColor = Self.successColor.cgColor
            glowLayer.shadowOpacity = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 0.85
            glowLayer.shadowRadius = 14
            crossfade(targets: [
                (micIcon, 1), (secondaryLabel, 1),
                (primaryLabel, 0), (timerLabel, 0), (bars, 0),
                (stopButton, 0), (cancelButton, 0), (retryButton, 0),
                (progressTrack, 0), (progressFill, 0)
            ])

        case .error(let label):
            micIcon.contentTintColor = Self.errorColor
            micIcon.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "Error"
            )
            secondaryLabel.textColor = Self.primaryTextColor
            secondaryLabel.stringValue = label
            glowLayer.shadowColor = Self.errorColor.cgColor
            glowLayer.shadowOpacity = 0.0
            crossfade(targets: [
                (micIcon, 1), (secondaryLabel, 1), (retryButton, 1),
                (primaryLabel, 0), (timerLabel, 0), (bars, 0),
                (stopButton, 0), (cancelButton, 0),
                (progressTrack, 0), (progressFill, 0)
            ])
        }

        // Pulse and bounce animations tied to state transitions.
        if isRecordingNow && !wasRecording {
            startMicPulse()
        } else if !isRecordingNow && wasRecording {
            stopMicPulse()
        }
        if isSuccessNow && !wasSuccess {
            playSuccessBounce()
        }

        needsLayout = true
    }

    func refreshLiveText(recordingStartedAt: Date?) {
        switch currentState {
        case .recording, .processing:
            timerLabel.stringValue = elapsed(from: recordingStartedAt)
        default:
            break
        }
    }

    func updateLevel(_ level: Float) {
        bars.level = level
    }

    func startBars() {
        bars.start()
    }

    private func elapsed(from date: Date?) -> String {
        guard let date else { return "0:00" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        return seconds < 60
            ? String(format: "0:%02d", seconds)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // single layout pass building the animated notch silhouette
    // swiftlint:disable:next function_body_length
    override func layout() {
        super.layout()
        guard let host = layer else { return }

        // Rebuild the NotchShape mask path for the current bounds.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskShape?.frame = bounds
        let notchPath = Self.makeNotchPath(
            width: bounds.width,
            height: bounds.height,
            topR: min(topCornerR, bounds.height / 2),
            bottomR: min(bottomCornerR, bounds.height / 2)
        )
        maskShape?.path = notchPath
        // Rim highlight reuses the exact silhouette so it tracks the animated
        // height and the concave top corners perfectly.
        rimHighlight.frame = bounds
        rimHighlight.path = notchPath
        CATransaction.commit()

        let visibleH = bounds.height
        let visibleStripY: CGFloat = 0
        let stripCenterY = visibleH / 2

        // Glow layer sits behind everything, only in the visible strip.
        glowLayer.frame = NSRect(x: 0, y: visibleStripY, width: bounds.width, height: visibleH)
        glowLayer.cornerRadius = visibleH / 2

        // Common edge insets within the visible strip.
        let leftPad: CGFloat = 14
        let rightPad: CGFloat = 14
        let iconSize: CGFloat = 16
        let gap: CGFloat = 8

        var x = leftPad

        // Mic icon
        micIcon.frame = NSRect(x: x, y: stripCenterY - iconSize / 2, width: iconSize, height: iconSize)
        x += iconSize + gap

        switch currentState {
        case .recording:
            // REC label
            primaryLabel.sizeToFit()
            primaryLabel.frame = NSRect(x: x, y: stripCenterY - primaryLabel.frame.height / 2,
                                        width: primaryLabel.frame.width, height: primaryLabel.frame.height)
            x += primaryLabel.frame.width + gap

            // Timer (right side, fixed width via tabular numbers)
            timerLabel.sizeToFit()
            let timerW = max(34, timerLabel.frame.width)
            let timerX = bounds.maxX - rightPad - timerW
            timerLabel.frame = NSRect(x: timerX, y: stripCenterY - 9, width: timerW, height: 18)

            // Hover-revealed buttons sit between bars and timer.
            var rightAnchor = timerX - gap
            if !stopButton.isHidden && !cancelButton.isHidden {
                let bw1 = stopButton.intrinsicSize().width
                let bw2 = cancelButton.intrinsicSize().width
                cancelButton.frame = NSRect(x: rightAnchor - bw2, y: stripCenterY - 11, width: bw2, height: 22)
                rightAnchor -= bw2 + 4
                stopButton.frame = NSRect(x: rightAnchor - bw1, y: stripCenterY - 11, width: bw1, height: 22)
                rightAnchor -= bw1 + gap
            }

            // Bars fill the gap.
            let barsX = x + gap
            let barsW = max(40, rightAnchor - barsX)
            bars.frame = NSRect(x: barsX, y: visibleStripY + 6, width: barsW, height: visibleH - 12)

        case .idle:
            // [mic] Double-tap fn [faint bars]
            secondaryLabel.sizeToFit()
            secondaryLabel.frame = NSRect(x: x, y: stripCenterY - secondaryLabel.frame.height / 2,
                                          width: secondaryLabel.frame.width, height: secondaryLabel.frame.height)
            x += secondaryLabel.frame.width + gap * 2
            let barsW = bounds.maxX - rightPad - x
            bars.frame = NSRect(x: x, y: visibleStripY + 8, width: max(40, barsW), height: visibleH - 16)

        case .processing:
            secondaryLabel.sizeToFit()
            secondaryLabel.frame = NSRect(x: x, y: stripCenterY - secondaryLabel.frame.height / 2,
                                          width: secondaryLabel.frame.width, height: secondaryLabel.frame.height)
            x += secondaryLabel.frame.width + gap

            timerLabel.sizeToFit()
            let timerW = max(34, timerLabel.frame.width)
            let timerX = bounds.maxX - rightPad - timerW
            timerLabel.frame = NSRect(x: timerX, y: stripCenterY - 9, width: timerW, height: 18)

            let barsX = x + gap
            let barsW = max(40, (timerX - gap) - barsX)
            bars.frame = NSRect(x: barsX, y: visibleStripY + 6, width: barsW, height: visibleH - 12)

        case .downloading:
            // [mic] Downloading model …………────── 47%
            secondaryLabel.sizeToFit()
            secondaryLabel.frame = NSRect(x: x, y: stripCenterY - secondaryLabel.frame.height / 2,
                                          width: secondaryLabel.frame.width, height: secondaryLabel.frame.height)
            x += secondaryLabel.frame.width + gap

            timerLabel.sizeToFit()
            let pctW = max(36, timerLabel.frame.width)
            let pctX = bounds.maxX - rightPad - pctW
            timerLabel.frame = NSRect(x: pctX, y: stripCenterY - 9, width: pctW, height: 18)

            let barX = x + gap
            let barW = max(60, (pctX - gap) - barX)
            let barH: CGFloat = 6
            let barY = stripCenterY - barH / 2
            progressTrack.frame = NSRect(x: barX, y: barY, width: barW, height: barH)
            let fillW = max(0, min(barW, barW * CGFloat(downloadProgress)))
            progressFill.frame = NSRect(x: barX, y: barY, width: fillW, height: barH)

        case .success:
            secondaryLabel.sizeToFit()
            secondaryLabel.frame = NSRect(x: x, y: stripCenterY - secondaryLabel.frame.height / 2,
                                          width: secondaryLabel.frame.width, height: secondaryLabel.frame.height)

        case .error:
            secondaryLabel.sizeToFit()
            let labelW = min(secondaryLabel.frame.width, bounds.width - x - rightPad - 70)
            secondaryLabel.frame = NSRect(x: x, y: stripCenterY - secondaryLabel.frame.height / 2,
                                          width: max(40, labelW), height: secondaryLabel.frame.height)
            let bw = retryButton.intrinsicSize().width
            let bx = bounds.maxX - rightPad - bw
            retryButton.frame = NSRect(x: bx, y: stripCenterY - 11, width: bw, height: 22)

        case .hidden:
            break
        }
    }
}

// MARK: - NotchPillButton

final class NotchPillButton: NSButton {
    var onClick: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        self.title = title
        self.bezelStyle = .inline
        self.isBordered = false
        self.target = self
        self.action = #selector(clicked)
        self.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        self.contentTintColor = NSColor(white: 1.0, alpha: 0.95)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        layer?.cornerRadius = 8
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        layer?.borderWidth = 0.5
        let cell = self.cell as? NSButtonCell
        cell?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func clicked() { onClick?() }

    func intrinsicSize() -> NSSize {
        sizeToFit()
        let fitted = fittingSize
        return NSSize(width: fitted.width + 18, height: 22)
    }
}

// MARK: - NotchPillView path + animation helpers

extension NotchPillView {

    /// Builds a pill silhouette with concave top corners (small inward
    /// indents that mate with the notch's outer curves) and convex
    /// rounded bottom corners (standard pill shape).
    static func makeNotchPath(width: CGFloat, height: CGFloat,
                              topR: CGFloat, bottomR: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard width > 0, height > 0 else { return path }
        // Start on the top edge, just inside the top-left concave indent.
        path.move(to: CGPoint(x: topR, y: height))
        // Concave top-left: control inside the body so the curve dips in.
        path.addQuadCurve(to: CGPoint(x: 0, y: height - topR),
                          control: CGPoint(x: topR, y: height - topR))
        path.addLine(to: CGPoint(x: 0, y: bottomR))
        // Convex bottom-left: control at the corner.
        path.addQuadCurve(to: CGPoint(x: bottomR, y: 0),
                          control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width - bottomR, y: 0))
        // Convex bottom-right.
        path.addQuadCurve(to: CGPoint(x: width, y: bottomR),
                          control: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height - topR))
        // Concave top-right.
        path.addQuadCurve(to: CGPoint(x: width - topR, y: height),
                          control: CGPoint(x: width - topR, y: height - topR))
        path.closeSubpath()
        return path
    }

    /// Continuous gentle scale pulse on the mic icon while recording.
    func startMicPulse() {
        guard let layer = micIcon.layer else {
            micIcon.wantsLayer = true
            DispatchQueue.main.async { [weak self] in self?.startMicPulse() }
            return
        }
        if layer.animation(forKey: "rec-pulse") != nil { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.12, 1.0]
        pulse.keyTimes = [0.0, 0.5, 1.0]
        pulse.duration = 1.3
        pulse.repeatCount = .infinity
        pulse.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        layer.add(pulse, forKey: "rec-pulse")
    }

    func stopMicPulse() {
        micIcon.layer?.removeAnimation(forKey: "rec-pulse")
    }

    /// One-shot bounce when transitioning into success.
    func playSuccessBounce() {
        guard let layer = micIcon.layer else {
            micIcon.wantsLayer = true
            DispatchQueue.main.async { [weak self] in self?.playSuccessBounce() }
            return
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [0.55, 1.18, 0.96, 1.0]
        bounce.keyTimes = [0.0, 0.55, 0.82, 1.0]
        bounce.duration = 0.42
        bounce.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.2, 1.0),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        bounce.isRemovedOnCompletion = true
        layer.add(bounce, forKey: "success-bounce")
    }

    /// Animate all subviews' alpha to their target values (1 if visible
    /// in the new state, 0 if not) over ~180ms. Avoids the popping
    /// hide/show used previously.
    func crossfade(targets: [(NSView, CGFloat)]) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            for (view, alpha) in targets {
                view.animator().alphaValue = alpha
            }
        }, completionHandler: nil)
    }
}
// swiftlint:enable file_length
