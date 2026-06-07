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
    // Peak-hold physics: fast rise on attack, slow decay so amplitude peaks
    // linger long enough to read. Pure single-value smoothing made the bars
    // feel uniform and lifeless.
    private let attack: CGFloat = 0.55    // 0..1 — how fast bars rise toward target
    private let decay: CGFloat = 0.12     // 0..1 — how fast bars fall back down
    private var reducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // Traditional white + red palette per user preference. Bars stay white;
    // the red accents live elsewhere (REC label, mic icon, recording glow).
    static let palette: [UInt32] = [0xFFFFFF]

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
        for idx in 0..<barCount {
            let bar = CALayer()
            bar.cornerRadius = barWidth / 2
            bar.backgroundColor = Self.colorForIndex(idx, of: barCount).cgColor
            host.addSublayer(bar)
            bars.append(bar)
        }
    }

    private func updateColors() {
        for (idx, bar) in bars.enumerated() {
            switch mode {
            case .live, .idle, .processing:
                bar.backgroundColor = Self.colorForIndex(idx, of: barCount).cgColor
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
        for idx in 0..<barCount {
            let barHeight = max(minBarHeight, heights[idx])
            let xPos = startX + CGFloat(idx) * (barWidth + barSpacing)
            bars[idx].frame = NSRect(
                x: xPos,
                y: centerY - barHeight / 2,
                width: barWidth,
                height: min(barHeight, maxHeight)
            )
        }
        CATransaction.commit()
    }

    private func startTimer() {
        stopTimer()
        // 30Hz is enough — frame-perfect motion not required.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        let maxH = max(2, bounds.height - 2)
        phase += 0.18

        for idx in 0..<barCount {
            let normalized = CGFloat(idx) / CGFloat(max(1, barCount - 1))   // 0..1 across the row
            let target: CGFloat
            switch mode {
            case .live:
                // Reduced motion: tiny static heights tied to level only.
                if reducedMotion {
                    target = minBarHeight + CGFloat(level) * (maxH - minBarHeight) * 0.6
                } else {
                    // Each bar has a phase offset so motion feels wave-like.
                    let env = CGFloat(level)
                    let wave = sin(phase + normalized * 5.2) * 0.25 + 0.75   // 0.5..1.0
                    let base = env * maxH * wave
                    let jitter = (CGFloat.random(in: -1...1)) * 1.2 * env
                    target = max(minBarHeight, min(maxH, base + jitter))
                }
            case .idle:
                if reducedMotion {
                    target = minBarHeight
                } else {
                    // Very low amplitude shimmer.
                    let wave = sin(phase * 0.6 + normalized * 4.0) * 0.5 + 0.5
                    target = minBarHeight + wave * 1.6
                }
            case .processing:
                if reducedMotion {
                    target = maxH * 0.35
                } else {
                    // Moving wave from left to right.
                    let wave = sin(phase * 1.4 - normalized * 1.2) * 0.5 + 0.5
                    target = minBarHeight + wave * maxH * 0.55
                }
            case .error:
                target = minBarHeight + 2
            }
            targets[idx] = target
            // Peak-hold: rise fast, fall slow.
            let delta = targets[idx] - heights[idx]
            heights[idx] += delta * (delta > 0 ? attack : decay)
        }
        layoutBars(animated: false)
    }

    // MARK: - Palette helper

    static func colorForIndex(_ index: Int, of count: Int) -> NSColor {
        // Single-color palette → all bars share the base color. Slight
        // alpha variation across the row keeps the row visually grouped
        // without re-introducing a gradient.
        let base = color(palette[0])
        let fraction = count > 1 ? Float(index) / Float(count - 1) : 0
        let alpha: CGFloat = 0.82 + CGFloat(sin(Float.pi * fraction)) * 0.18
        return base.withAlphaComponent(alpha)
    }

    static func color(_ hex: UInt32) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    static func lerp(_ from: NSColor, _ to: NSColor, _ fraction: CGFloat) -> NSColor {
        let fromColor = from.usingColorSpace(.sRGB) ?? from
        let toColor = to.usingColorSpace(.sRGB) ?? to
        return NSColor(
            srgbRed: fromColor.redComponent + (toColor.redComponent - fromColor.redComponent) * fraction,
            green: fromColor.greenComponent + (toColor.greenComponent - fromColor.greenComponent) * fraction,
            blue: fromColor.blueComponent + (toColor.blueComponent - fromColor.blueComponent) * fraction,
            alpha: 1
        )
    }
}
