import AppKit
import QuartzCore

/// Floating pill positioned just below the notch (or top-center on non-notch
/// displays). Shows recording state with a red dot, and transcribing state
/// with an Apple-Intelligence-style rainbow conic gradient ring that rotates
/// continuously. Click-through, never steals focus, always-on-top.
/// All methods must be called on the main thread.
final class NotchIndicator {
    private var panel: NSPanel?
    private var container: NSView?
    private var label: NSTextField?
    private var dot: NSView?
    private var ringLayer: CAGradientLayer?
    private var ringMask: CAShapeLayer?
    private var visible = false
    private var currentMode: Mode?

    private enum Mode { case recording, transcribing }

    // Geometry. Width/height tuned for ~14" MacBook Pro notch (notch ~200pt wide).
    private let width: CGFloat = 280
    private let height: CGFloat = 34
    private let topMargin: CGFloat = 6
    private let ringInset: CGFloat = 1.5
    private let ringStroke: CGFloat = 2.0

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
        stopShimmer()
        currentMode = nil
        // Fade out instead of disappearing instantly.
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel?.alphaValue = 1
        })
        visible = false
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s < 60 ? String(format: "0:%02d", s) : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func present() {
        guard let panel else { return }
        repositionIfNeeded()
        if !visible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                ctx.allowsImplicitAnimation = true
                panel.animator().alphaValue = 1
            }, completionHandler: nil)
            visible = true
        }
    }

    private func repositionIfNeeded() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let safeTop = screen.safeAreaInsets.top  // notch height on M3 14" ≈ 38pt; 0 on non-notch displays
        let x = screen.frame.midX - width / 2
        // Place just under the notch (or just under the menu bar on non-notch).
        let baseY = screen.frame.maxY - max(safeTop, 24) - height - topMargin
        // Clamp inside visibleFrame so we never disappear under the menu bar.
        let y = min(baseY, frame.maxY - height - 2)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func update(text: String) {
        label?.stringValue = text
    }

    private func setMode(_ mode: Mode) {
        guard currentMode != mode else { return }
        currentMode = mode
        switch mode {
        case .recording:
            stopShimmer()
            dot?.isHidden = false
            dot?.layer?.backgroundColor = NSColor.systemRed.cgColor
            // Indent label to make room for dot.
            label?.frame.origin.x = 30
            label?.frame.size.width = width - 46
        case .transcribing:
            dot?.isHidden = true
            label?.frame.origin.x = 16
            label?.frame.size.width = width - 32
            startShimmer()
        }
    }

    private func startShimmer() {
        guard let ring = ringLayer else { return }
        ring.isHidden = false
        if ring.animation(forKey: "shimmer") != nil { return }
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.fromValue = 0
        anim.toValue = CGFloat.pi * 2
        anim.duration = 2.8
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        ring.add(anim, forKey: "shimmer")
    }

    private func stopShimmer() {
        ringLayer?.removeAnimation(forKey: "shimmer")
        ringLayer?.isHidden = true
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

        let cont = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        cont.wantsLayer = true
        guard let layer = cont.layer else { return }
        layer.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        layer.cornerRadius = height / 2
        layer.masksToBounds = false
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: -1)

        // Apple-Intelligence-style conic gradient ring.
        let ring = CAGradientLayer()
        ring.type = .conic
        ring.frame = layer.bounds.insetBy(dx: ringInset, dy: ringInset)
        ring.cornerRadius = (height - ringInset * 2) / 2
        ring.startPoint = CGPoint(x: 0.5, y: 0.5)
        ring.endPoint = CGPoint(x: 1.0, y: 0.5)
        ring.colors = [
            NSColor.systemBlue.cgColor,
            NSColor.systemPurple.cgColor,
            NSColor.systemPink.cgColor,
            NSColor.systemOrange.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemTeal.cgColor,
            NSColor.systemBlue.cgColor
        ]
        ring.locations = [0.0, 0.18, 0.36, 0.54, 0.72, 0.88, 1.0]
        ring.isHidden = true

        // Mask the gradient so only a stroked ring is visible.
        let mask = CAShapeLayer()
        mask.frame = ring.bounds
        let path = NSBezierPath(roundedRect: ring.bounds.insetBy(dx: ringStroke / 2, dy: ringStroke / 2),
                                xRadius: (height - ringInset * 2 - ringStroke) / 2,
                                yRadius: (height - ringInset * 2 - ringStroke) / 2)
        mask.path = path.cgPath
        mask.fillColor = NSColor.clear.cgColor
        mask.strokeColor = NSColor.white.cgColor
        mask.lineWidth = ringStroke
        ring.mask = mask
        layer.addSublayer(ring)

        let dotView = NSView(frame: NSRect(x: 14, y: height/2 - 4, width: 8, height: 8))
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        cont.addSubview(dotView)

        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.alignment = .center
        l.frame = NSRect(x: 30, y: 7, width: width - 46, height: 18)
        l.lineBreakMode = .byTruncatingTail
        l.usesSingleLineMode = true
        cont.addSubview(l)

        p.contentView = cont

        self.panel = p
        self.container = cont
        self.label = l
        self.dot = dotView
        self.ringLayer = ring
        self.ringMask = mask
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}
