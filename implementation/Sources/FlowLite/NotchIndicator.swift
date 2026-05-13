import AppKit
import QuartzCore

/// Floating widget that visually extends the MacBook notch. Pattern adapted
/// from theboredteam/boring.notch: panel top edge sits at screen.maxY (under
/// the notch cutout the panel is invisible because hardware), only the bottom
/// portion is visible below the notch. Bottom corners rounded, top corners
/// square — they're hidden under the notch.
///
/// Animation: panel height grows from safeAreaInsets.top (no visible drip) to
/// safeAreaInsets.top + visibleHeight using a spring-like cubic timing, so it
/// looks like the notch dripping a widget downward (Dynamic-Island style).
final class NotchIndicator {
    private var panel: NSPanel?
    private var pillView: NotchPillView?
    private var label: NSTextField?
    private var dot: NSView?
    private var visible = false
    private var currentMode: Mode?

    private enum Mode { case recording, transcribing }

    // Geometry
    private let visibleHeight: CGFloat = 36          // visible drip below notch
    private let extraOverhang: CGFloat = 14          // pill extends past notch on each side
    private let fallbackNotchWidth: CGFloat = 200    // M-series 14"/16" notch ≈ 200pt
    private let fallbackSafeTop: CGFloat = 32        // menu-bar height on non-notch Macs

    private let openDuration: CFTimeInterval = 0.42
    private let closeDuration: CFTimeInterval = 0.28
    private let springTiming = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.2, 1.0)
    private let easeInTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)

    // MARK: - Public

    func showRecording(elapsedSeconds: TimeInterval) {
        ensureBuilt()
        setMode(.recording)
        update(text: "REC  \(format(elapsedSeconds))")
        present()
    }

    func showTranscribing(elapsedSeconds: TimeInterval) {
        ensureBuilt()
        setMode(.transcribing)
        update(text: "TRANSCRIBING  \(format(elapsedSeconds))")
        present()
    }

    func hide() {
        guard visible else { return }
        visible = false
        currentMode = nil
        animateCollapsed { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }

    // MARK: - Layout

    private func currentScreen() -> NSScreen? {
        // Prefer the screen actually showing the menu bar. NSScreen.main may
        // be wrong if a focused window is on a secondary display.
        return NSScreen.screens.first ?? NSScreen.main
    }

    private func safeTop(for screen: NSScreen) -> CGFloat {
        let inset = screen.safeAreaInsets.top
        return inset > 0 ? inset : fallbackSafeTop
    }

    private func notchWidth(for screen: NSScreen) -> CGFloat {
        // safeAreaInsets.left/right are 0 on macOS notch displays — auxiliary
        // areas would tell us the notch width but require macOS 12+ specifics
        // that vary by SDK. Use a sane default that matches all M-series 14"/16".
        return screen.safeAreaInsets.top > 0 ? fallbackNotchWidth : 160
    }

    private func expandedFrame(for screen: NSScreen) -> NSRect {
        let safe = safeTop(for: screen)
        let width = notchWidth(for: screen) + extraOverhang * 2
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - (safe + visibleHeight),
            width: width,
            height: safe + visibleHeight
        )
    }

    private func collapsedFrame(for screen: NSScreen) -> NSRect {
        let safe = safeTop(for: screen)
        let width = notchWidth(for: screen) + extraOverhang * 2
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - safe,
            width: width,
            height: safe
        )
    }

    // MARK: - Animation

    private func present() {
        guard let panel, let screen = currentScreen() else { return }

        if !visible {
            // Start collapsed (height = just under notch, invisible).
            panel.setFrame(collapsedFrame(for: screen), display: false)
            pillView?.visibleHeight = visibleHeight
            pillView?.needsLayout = true
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = openDuration
                ctx.timingFunction = springTiming
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(self.expandedFrame(for: screen), display: true)
            }, completionHandler: nil)
            visible = true
        }
    }

    private func animateCollapsed(_ completion: @escaping () -> Void) {
        guard let panel, let screen = currentScreen() else { completion(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = closeDuration
            ctx.timingFunction = easeInTiming
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(self.collapsedFrame(for: screen), display: true)
        }, completionHandler: completion)
    }

    private func setMode(_ mode: Mode) {
        guard currentMode != mode else { return }
        currentMode = mode
        switch mode {
        case .recording:
            dot?.isHidden = false
            dot?.layer?.backgroundColor = NSColor.systemRed.cgColor
            pillView?.contentLayout = .recording
        case .transcribing:
            dot?.isHidden = false
            dot?.layer?.backgroundColor = NSColor.systemTeal.cgColor
            pillView?.contentLayout = .transcribing
        }
        pillView?.needsLayout = true
    }

    private func update(text: String) {
        label?.stringValue = text
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s < 60 ? String(format: "0:%02d", s) : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Build

    private func ensureBuilt() {
        guard panel == nil else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
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
        p.ignoresMouseEvents = true
        p.isMovable = false
        p.animationBehavior = .none

        let pill = NotchPillView()
        pill.visibleHeight = visibleHeight
        pill.translatesAutoresizingMaskIntoConstraints = true
        pill.autoresizingMask = [.width, .height]
        pill.frame = NSRect(origin: .zero, size: p.frame.size)

        // Dot
        let dotView = NSView(frame: NSRect(x: 14, y: 0, width: 8, height: 8))
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        pill.dotView = dotView
        pill.addSubview(dotView)

        // Label
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        l.usesSingleLineMode = true
        l.frame = NSRect(x: 0, y: 0, width: 100, height: 18)
        pill.label = l
        pill.addSubview(l)

        p.contentView = pill

        self.panel = p
        self.pillView = pill
        self.label = l
        self.dot = dotView
    }
}

// MARK: - NotchPillView

final class NotchPillView: NSView {
    enum ContentLayout { case recording, transcribing }

    var visibleHeight: CGFloat = 36
    var contentLayout: ContentLayout = .recording
    weak var label: NSTextField?
    weak var dotView: NSView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        // Round only the bottom corners — top corners hide under the notch.
        layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        guard let host = layer else { return }
        host.cornerRadius = min(visibleHeight / 2, bounds.height / 2)

        let visibleH = min(visibleHeight, bounds.height)
        let visibleStripY = bounds.maxY - bounds.height
        let stripCenterY = visibleStripY + visibleH / 2

        let dotSize: CGFloat = 8
        dotView?.isHidden = false
        dotView?.frame = NSRect(x: 16, y: stripCenterY - dotSize / 2, width: dotSize, height: dotSize)
        let labelX: CGFloat = 30
        let labelW = bounds.width - labelX - 16
        label?.frame = NSRect(x: labelX, y: stripCenterY - 9, width: labelW, height: 18)
        label?.alignment = .left
    }
}

