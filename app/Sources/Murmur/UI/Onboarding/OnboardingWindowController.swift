// AppKit window controller hosting the SwiftUI onboarding wizard.
//
// Singleton because the wizard is modeless and we want every entry point
// (first-launch auto-open, About tab "Run setup again" button, future
// command-line flag) to share a single window. `isReleasedWhenClosed`
// stays false so re-showing after a close works without rebuilding the
// hosting controller.
import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    private convenience init() {
        let host = NSHostingController(rootView: OnboardingRoot())
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Murmur"
        window.styleMask = [.titled, .closable]
        window.setFrameAutosaveName("MurmurOnboarding")
        window.isReleasedWhenClosed = false
        // Center on first show. The autosave frame takes precedence
        // on subsequent shows.
        window.center()
        self.init(window: window)
    }

    /// Opens the wizard if the current config hasn't been stamped with a
    /// completion version that matches the current onboarding revision.
    /// Called once from `applicationDidFinishLaunching`.
    static func openIfNeeded() {
        let config = Config.loadOrCreateDefault()
        if shouldShow(for: config) {
            shared.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Pure decision helper, separated from the side effect so it can be
    /// unit-tested without spinning up an AppKit window.
    static func shouldShow(for config: Config) -> Bool {
        config.onboardingCompletedVersion != currentVersion
    }

    /// Mark onboarding complete and persist. Safe to call even if the
    /// config file is read-only — we log the failure and continue so the
    /// wizard still dismisses (the user can finish setup manually).
    static func markComplete() {
        var config = Config.loadOrCreateDefault()
        config.onboardingCompletedVersion = currentVersion
        do {
            try config.save()
        } catch {
            Log.error("failed to persist onboarding completion: \(error)")
        }
    }

    /// Mark the wizard incomplete so it reopens on next launch. Useful for
    /// testing and for the About tab's "Run setup again" path (which calls
    /// `showWindow(nil)` directly — this isn't strictly needed there, but
    /// is provided for symmetry).
    static func reset() {
        var config = Config.loadOrCreateDefault()
        config.onboardingCompletedVersion = nil
        try? config.save()
    }

    /// The current onboarding schema version. Bump when a new step needs
    /// to re-prompt users who already finished an older flow.
    static let currentVersion = "1.0"
}
