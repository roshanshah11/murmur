import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let host = NSHostingController(rootView: SettingsRoot())
        let window = NSWindow(contentViewController: host)
        window.title = "Murmur Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setFrameAutosaveName("MurmurSettings")
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
