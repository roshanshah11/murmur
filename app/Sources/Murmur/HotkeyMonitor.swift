import AppKit
import Foundation

final class HotkeyMonitor {
    private let onToggle: () -> Void
    private var monitor: Any?
    private var lastPressAt = Date.distantPast
    private var lastFireAt = Date.distantPast
    private var fnDown = false

    private let doubleTapWindow: TimeInterval = 0.35
    private let postFireDebounce: TimeInterval = 0.5

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
    }

    var isActive: Bool { monitor != nil }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        if monitor == nil {
            Log.event(state: "hotkey_monitor_failed", fields: [
                "hint": "Input Monitoring / Accessibility permission likely missing"
            ])
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        let nowFn = event.modifierFlags.contains(.function)

        guard nowFn != fnDown else { return }
        let wasDown = fnDown
        fnDown = nowFn

        guard !wasDown && nowFn else { return }

        let otherFlags: NSEvent.ModifierFlags = [.command, .shift, .control, .option, .capsLock]
        if !event.modifierFlags.intersection(otherFlags).isEmpty {
            lastPressAt = .distantPast
            return
        }

        let now = Date()

        if now.timeIntervalSince(lastFireAt) < postFireDebounce {
            return
        }

        if now.timeIntervalSince(lastPressAt) <= doubleTapWindow {
            lastFireAt = now
            lastPressAt = .distantPast
            DispatchQueue.main.async { [onToggle] in
                onToggle()
            }
        } else {
            lastPressAt = now
        }
    }
}
