import AppKit
import Foundation

enum PasteResult {
    case pasted(target: AppContext)
    case copiedOnly(reason: String)
}

final class PasteboardInserter {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func paste(_ text: String) -> PasteResult {
        guard !text.isEmpty else {
            return .copiedOnly(reason: "empty text")
        }

        let pasteboard = NSPasteboard.general
        let previousString = config.restoreClipboardAfterPaste ? pasteboard.string(forType: .string) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // T5: don't paste into ourselves.
        if AppContext.isFrontmostSelf {
            Log.event(state: "paste_skipped_self_frontmost", fields: ["chars": String(text.count)])
            return .copiedOnly(reason: "FlowLite is frontmost; text copied to clipboard")
        }

        let target = AppContext.capture()
        let delay = max(0, config.pasteDelayMs)
        if delay > 0 {
            usleep(useconds_t(delay * 1000))
        }
        simulateCommandV()

        if config.restoreClipboardAfterPaste, let previousString {
            let restoreDelay = Double(config.clipboardRestoreDelayMs) / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                pasteboard.clearContents()
                pasteboard.setString(previousString, forType: .string)
            }
        }

        Log.event(state: "paste_dispatched", fields: [
            "target_app": target.name,
            "target_bundle": target.bundleID,
            "chars": String(text.count)
        ])
        return .pasted(target: target)
    }

    private func simulateCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
