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
        let w = max(geo.notchWidth + Self.extraOverhang * 2, width)
        let totalHeight = geo.safeTop + Self.visibleHeight
        return NSRect(
            x: geo.centerX - w / 2,
            y: geo.topY - totalHeight,
            width: w,
            height: totalHeight
        )
    }

    private func collapsedFrame(width: CGFloat, geo: NotchGeometry) -> NSRect {
        let w = max(geo.notchWidth + Self.extraOverhang * 2, width)
        return NSRect(
            x: geo.centerX - w / 2,
            y: geo.topY - geo.safeTop,
            width: w,
            height: geo.safeTop
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
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pill?.refreshLiveText(recordingStartedAt: self?.recordingStartedAt)
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTextTimer = t
    }

    private func stopElapsedTextTimer() {
        elapsedTextTimer?.invalidate()
        elapsedTextTimer = nil
    }

    private func startLevelPoll() {
        if levelPollTimer != nil { return }
        // SpectrumBarsView has its own 30Hz tick; we just need to feed it the
        // current mic level. 30Hz is plenty.
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let lvl = self.levelProvider?() ?? 0
            self.pill?.updateLevel(lvl)
        }
        RunLoop.main.add(t, forMode: .common)
        levelPollTimer = t
        pill?.startBars()
    }

    private func stopLevelPoll() {
        levelPollTimer?.invalidate()
        levelPollTimer = nil
    }

    // MARK: - Hover handling

    fileprivate func setHovered(_ h: Bool) {
        guard hovered != h else { return }
        hovered = h
        guard case .recording = state else { return }
        // Re-apply recording state with new hover flag so layout + width change.
        applyState(.recording)
    }

    // MARK: - Build

    private func ensureBuilt() {
        guard panel == nil else { return }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        p.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = false   // need hover detection
        p.isMovable = false
        p.animationBehavior = .none

        let view = NotchPillView()
        view.visibleHeight = Self.visibleHeight
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.width, .height]
        view.frame = NSRect(origin: .zero, size: p.frame.size)
        view.onHover = { [weak self] h in self?.setHovered(h) }
        view.onStop = { [weak self] in self?.onStopRequested?() }
        view.onCancel = { [weak self] in self?.onCancelRequested?() }
        view.onRetry = { [weak self] in self?.onRetryRequested?() }
        p.contentView = view
        self.panel = p
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

    // State-dependent intrinsic widths for the morph animation.
    func intrinsicWidth(for state: NotchIndicator.State, hovered: Bool) -> CGFloat {
        switch state {
        case .hidden:
            return 220
        case .idle:
            return 230
        case .recording:
            // Snug around the notch when not hovered; widen on hover to
            // make room for Stop / Cancel.
            return hovered ? 340 : 240
        case .processing:
            // Match the non-hovered recording width so the pill keeps
            // its size across recording → transcription.
            return 240
        case .success(let label):
            return max(200, 100 + estimatedWidth(label))
        case .error(let label):
            return max(260, 130 + estimatedWidth(label))
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
    private var trackingArea: NSTrackingArea?
    private var currentState: NotchIndicator.State = .hidden
    private var hoveredNow = false

    private static let primaryTextColor = NSColor(white: 1.0, alpha: 0.96)
    private static let secondaryTextColor = NSColor(white: 1.0, alpha: 0.58)
    private static let recColor = SpectrumBarsView.color(0xFF4FA3)
    private static let successColor = NSColor(srgbRed: 0.32, green: 0.86, blue: 0.55, alpha: 1)
    private static let errorColor = NSColor(srgbRed: 1.0, green: 0.45, blue: 0.35, alpha: 1)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        glowLayer.cornerRadius = 18
        glowLayer.shadowColor = Self.recColor.cgColor
        glowLayer.shadowOpacity = 0.0
        glowLayer.shadowRadius = 12
        glowLayer.shadowOffset = .zero
        layer?.addSublayer(glowLayer)

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
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(t)
        trackingArea = t
    }

    override func mouseEntered(with event: NSEvent) {
        hoveredNow = true
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredNow = false
        onHover?(false)
    }

    func applyState(_ state: NotchIndicator.State, hovered: Bool, recordingStartedAt: Date?) {
        currentState = state
        hoveredNow = hovered

        // Hide all by default, then enable the ones this state uses.
        for v in [primaryLabel, secondaryLabel, timerLabel, micIcon, bars, stopButton, cancelButton, retryButton] as [NSView] {
            v.isHidden = true
        }

        switch state {
        case .hidden:
            break

        case .idle:
            micIcon.isHidden = false
            micIcon.contentTintColor = NSColor(white: 1.0, alpha: 0.48)
            micIcon.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microphone")
            secondaryLabel.isHidden = false
            secondaryLabel.textColor = Self.secondaryTextColor
            secondaryLabel.stringValue = "Double-tap fn"
            bars.isHidden = false
            bars.mode = .idle
            bars.alphaValue = 0.45
            glowLayer.shadowOpacity = 0.0

        case .recording:
            micIcon.isHidden = false
            micIcon.contentTintColor = Self.recColor
            micIcon.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            primaryLabel.isHidden = false
            primaryLabel.textColor = Self.recColor
            primaryLabel.stringValue = "REC"
            bars.isHidden = false
            bars.mode = .live
            bars.alphaValue = 1.0
            timerLabel.isHidden = false
            timerLabel.stringValue = elapsed(from: recordingStartedAt)
            glowLayer.shadowOpacity = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 0.4
            if hovered {
                stopButton.isHidden = false
                cancelButton.isHidden = false
            }

        case .processing(let label):
            micIcon.isHidden = false
            micIcon.contentTintColor = NSColor(white: 1.0, alpha: 0.75)
            micIcon.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Processing")
            secondaryLabel.isHidden = false
            secondaryLabel.textColor = Self.primaryTextColor
            secondaryLabel.stringValue = label
            bars.isHidden = false
            bars.mode = .processing
            bars.alphaValue = 0.85
            timerLabel.isHidden = false
            timerLabel.stringValue = elapsed(from: recordingStartedAt)
            glowLayer.shadowOpacity = 0.0

        case .success(let label):
            micIcon.isHidden = false
            micIcon.contentTintColor = Self.successColor
            micIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
            secondaryLabel.isHidden = false
            secondaryLabel.textColor = Self.successColor
            secondaryLabel.stringValue = label
            glowLayer.shadowColor = Self.successColor.cgColor
            glowLayer.shadowOpacity = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 0.85
            glowLayer.shadowRadius = 14

        case .error(let label):
            micIcon.isHidden = false
            micIcon.contentTintColor = Self.errorColor
            micIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
            secondaryLabel.isHidden = false
            secondaryLabel.textColor = Self.primaryTextColor
            secondaryLabel.stringValue = label
            retryButton.isHidden = false
            glowLayer.shadowColor = Self.errorColor.cgColor
            glowLayer.shadowOpacity = 0.0
        }

        // Restore default glow color for next time.
        if case .recording = state {
            glowLayer.shadowColor = Self.recColor.cgColor
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
        guard let d = date else { return "0:00" }
        let s = max(0, Int(Date().timeIntervalSince(d)))
        return s < 60 ? String(format: "0:%02d", s) : String(format: "%d:%02d", s / 60, s % 60)
    }

    override func layout() {
        super.layout()
        guard let host = layer else { return }
        host.cornerRadius = min(visibleHeight / 2, bounds.height / 2)

        let visibleH = min(visibleHeight, bounds.height)
        let visibleStripY = bounds.maxY - bounds.height
        let stripCenterY = visibleStripY + visibleH / 2

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
        let s = fittingSize
        return NSSize(width: s.width + 18, height: 22)
    }
}
