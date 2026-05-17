import AppKit
import Foundation

struct AppContext {
    let name: String
    let bundleID: String

    static func capture() -> AppContext {
        if let app = NSWorkspace.shared.frontmostApplication {
            return AppContext(
                name: app.localizedName ?? "unknown",
                bundleID: app.bundleIdentifier ?? "unknown"
            )
        }
        return AppContext(name: "unknown", bundleID: "unknown")
    }

    static var ownBundleID: String {
        Bundle.main.bundleIdentifier ?? "FlowLite"
    }

    static var isFrontmostSelf: Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let bid = app.bundleIdentifier ?? ""
        if bid == ownBundleID { return true }
        if (app.localizedName ?? "").contains("FlowLite") { return true }
        return false
    }
}
