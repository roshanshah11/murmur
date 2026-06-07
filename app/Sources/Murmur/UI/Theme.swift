import AppKit
import Foundation

/// User-selectable app appearance. Stored as a string in `Config` (so the type
/// is Foundation-safe and `Config.swift` needn't import AppKit); the AppKit
/// mapping lives here. Default is `.auto` (follow the system), so existing
/// installs see no forced change.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:  return "Auto"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    /// The AppKit appearance to force, or `nil` to follow the system setting.
    var nsAppearance: NSAppearance? {
        switch self {
        case .auto:  return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark:  return NSAppearance(named: .darkAqua)
        }
    }

    /// Apply process-wide. Setting `NSApp.appearance` cascades to every window
    /// (Settings, Onboarding, History) and SwiftUI's semantic colors follow it.
    /// Must be called on the main thread.
    func apply() {
        NSApp.appearance = nsAppearance
    }
}

extension Notification.Name {
    /// Posted by Settings → General when the user changes the appearance mode.
    /// `main.swift` observes it (on the main queue) and applies the new mode
    /// live so the whole UI re-themes without a relaunch.
    static let murmurAppearanceChanged = Notification.Name("murmur.appearance.changed")
}
