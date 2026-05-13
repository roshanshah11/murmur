import AppKit

/// Floating pill that sits just under the notch on MacBook screens (and at
/// the top center on non-notch displays). Click-through, never accepts focus,
/// shows recording / transcribing state with a live timer.
/// All methods must be called on the main thread (caller responsibility).
final class NotchIndicator {
    private var panel: NSPanel?
    private var label: NSTextField?
    private var dot: NSView?
    private var visible = false

    private let width: CGFloat = 260
    private let height: CGFloat = 30

    func showRecording(elapsedSeconds: TimeInterval) {
        ensureBuilt()
        update(text: "REC  \(format(elapsedSeconds))", color: .systemRed)
        present()
    }

    func showTranscribing(elapsedSeconds: TimeInterval) {
        ensureBuilt()
        update(text: "TRANSCRIBING  \(format(elapsedSeconds))", color: .systemBlue)
        present()
    }

    func hide() {
        guard visible else { return }
        panel?.orderOut(nil)
        visible = false
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s < 60 ? String(format: "0:%02d", s) : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func present() {
        guard let panel else { return }
        if !visible {
            repositionIfNeeded()
            panel.orderFrontRegardless()
            visible = true
        }
    }

    private func repositionIfNeeded() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.frame
        // Place just below the notch / menu bar.
        let x = frame.midX - width / 2
        let y = frame.maxY - height - 4
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func update(text: String, color: NSColor) {
        label?.stringValue = text
        dot?.layer?.backgroundColor = color.cgColor
    }

    private func ensureBuilt() {
        guard panel == nil else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.isMovable = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        container.layer?.cornerRadius = height / 2
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.layer?.borderWidth = 0.5

        let dotView = NSView(frame: NSRect(x: 14, y: height/2 - 4, width: 8, height: 8))
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        container.addSubview(dotView)

        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.alignment = .center
        l.frame = NSRect(x: 28, y: 6, width: width - 44, height: 18)
        l.lineBreakMode = .byTruncatingTail
        l.usesSingleLineMode = true
        container.addSubview(l)

        p.contentView = container

        self.panel = p
        self.label = l
        self.dot = dotView
    }
}
