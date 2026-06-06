import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let host = NSHostingController(rootView: SettingsRoot())
        let window = NSWindow(contentViewController: host)
        window.title = "Murmur Settings"
        // Resizable so AppKit can give SwiftUI the size its `.frame(minWidth:minHeight:)`
        // asks for. Without `.resizable`, an autosaved frame could leave the
        // content view smaller than SwiftUI's intrinsic size and clip the
        // TabView tab strip (the original Settings-stuck-on-Prompts bug).
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.contentMinSize = NSSize(width: 580, height: 480)
        window.setFrameAutosaveName("MurmurSettings")
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
