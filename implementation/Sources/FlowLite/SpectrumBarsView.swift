import AppKit
import QuartzCore

/// Compact horizontal equalizer driven by a normalized mic level (0..1).
/// 14 rounded bars laid out left-to-right, each with a fixed gradient color
/// from cyan → blue → purple → magenta → pink across the row. Bars smoothly
/// interpolate toward target heights so motion feels fluid, not jittery.
///
/// Modes:
/// - `.live`   bars react to mic level
/// - `.idle`   faint dotted line (very low amplitude)
/// - `.processing` bars wave in a sine pattern (no mic input)
/// - `.error`  flat dim red bars
final class SpectrumBarsView: NSView {
    enum Mode { case live, idle, processing, error }

    var mode: Mode = .live { didSet { updateColors() } }
    var level: Float = 0  // 0..1, updated externally during recording

    private let barCount = 14
    private var bars: [CALayer] = []
    private var displayLink: Any?  // CVDisplayLink or Timer
    private var pollTimer: Timer?
    private var phase: CGFloat = 0
    private var heights: [CGFloat] = []
    private var targets: [CGFloat] = []
    private let barWidth: CGFloat = 3.0
    private let barSpacing: CGFloat = 3.5
    private let minBarHeight: CGFloat = 2.0
    private let smoothing: CGFloat = 0.30  // higher = snappier; 0..1
    private var reducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static let palette: [UInt32] = [0x27E1FF, 0x3F8CFF, 0x7A5CFF, 0xD94DFF, 0xFF4FA3]

    var intrinsicWidth: CGFloat {
        CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        buildBars()
        heights = Array(repeating: minBarHeight, count: barCount)
        targets = Array(repeating: minBarHeight, count: barCount)
        startTimer()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { stopTimer() }

    func start() {
        if pollTimer == nil { startTimer() }
    }

    func stop() {
        stopTimer()
    }

    private func buildBars() {
        guard let host = layer else { return }
        for sub in host.sublayers ?? [] { sub.removeFromSuperlayer() }
        bars.removeAll()
        for i in 0..<barCount {
            let b = CALayer()
            b.cornerRadius = barWidth / 2
            b.backgroundColor = Self.colorForIndex(i, of: barCount).cgColor
            host.addSublayer(b)
            bars.append(b)
        }
    }

    private func updateColors() {
        for (i, bar) in bars.enumerated() {
            switch mode {
            case .live, .idle, .processing:
                bar.backgroundColor = Self.colorForIndex(i, of: barCount).cgColor
            case .error:
                bar.backgroundColor = NSColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 0.85).cgColor
            }
        }
    }

    override func layout() {
        super.layout()
        layoutBars(animated: false)
    }

    private func layoutBars(animated: Bool) {
        guard !bars.isEmpty else { return }
        let maxHeight = bounds.height
        let totalWidth = intrinsicWidth
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.midY
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        for i in 0..<barCount {
            let h = max(minBarHeight, heights[i])
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            bars[i].frame = NSRect(x: x, y: centerY - h / 2, width: barWidth, height: min(h, maxHeight))
        }
        CATransaction.commit()
    }

    private func startTimer() {
        stopTimer()
        // 30Hz is enough — frame-perfect motion not required.
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        let maxH = max(2, bounds.height - 2)
        phase += 0.18

        for i in 0..<barCount {
            let n = CGFloat(i) / CGFloat(max(1, barCount - 1))   // 0..1 across the row
            let target: CGFloat
            switch mode {
            case .live:
                // Reduced motion: tiny static heights tied to level only.
                if reducedMotion {
                    target = minBarHeight + CGFloat(level) * (maxH - minBarHeight) * 0.6
                } else {
                    // Each bar has a phase offset so motion feels wave-like.
                    let env = CGFloat(level)
                    let wave = sin(phase + n * 5.2) * 0.25 + 0.75   // 0.5..1.0
                    let base = env * maxH * wave
                    let jitter = (CGFloat.random(in: -1...1)) * 1.2 * env
                    target = max(minBarHeight, min(maxH, base + jitter))
                }
            case .idle:
                if reducedMotion {
                    target = minBarHeight
                } else {
                    // Very low amplitude shimmer.
                    let wave = sin(phase * 0.6 + n * 4.0) * 0.5 + 0.5
                    target = minBarHeight + wave * 1.6
                }
            case .processing:
                if reducedMotion {
                    target = maxH * 0.35
                } else {
                    // Moving wave from left to right.
                    let wave = sin(phase * 1.4 - n * 1.2) * 0.5 + 0.5
                    target = minBarHeight + wave * maxH * 0.55
                }
            case .error:
                target = minBarHeight + 2
            }
            targets[i] = target
            heights[i] += (targets[i] - heights[i]) * smoothing
        }
        layoutBars(animated: false)
    }

    // MARK: - Palette helper

    static func colorForIndex(_ i: Int, of n: Int) -> NSColor {
        guard n > 1 else { return color(palette[0]) }
        let t = Float(i) / Float(n - 1)               // 0..1
        let stops: [Float] = [0.0, 0.25, 0.55, 0.80, 1.0]
        // Find bracketing stops.
        var lo = 0
        for k in 0..<stops.count - 1 {
            if t >= stops[k] && t <= stops[k + 1] { lo = k; break }
        }
        let hi = min(lo + 1, palette.count - 1)
        let span = stops[hi] - stops[lo]
        let mix = span > 0 ? (t - stops[lo]) / span : 0
        return lerp(color(palette[lo]), color(palette[hi]), CGFloat(mix))
    }

    static func color(_ hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static func lerp(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let ac = a.usingColorSpace(.sRGB) ?? a
        let bc = b.usingColorSpace(.sRGB) ?? b
        return NSColor(
            srgbRed: ac.redComponent + (bc.redComponent - ac.redComponent) * t,
            green: ac.greenComponent + (bc.greenComponent - ac.greenComponent) * t,
            blue: ac.blueComponent + (bc.blueComponent - ac.blueComponent) * t,
            alpha: 1
        )
    }
}
