// Reads microphone + accessibility permission status. Pure observation
// (with one explicit prompt-trigger helper). The wizard polls these between
// step transitions to know when the user has flipped the system toggle.
//
// `AXIsProcessTrustedWithOptions(nil)` is the documented prompt-free query;
// `AXIsProcessTrustedWithOptions(kAXTrustedCheckOptionPrompt: true)` would
// pop System Settings open, which we don't want during a poll.
import AVFoundation
import AppKit
import ApplicationServices

public enum PermissionStatus: String, Equatable {
    case notDetermined
    case granted
    case denied
}

public enum PermissionsProbe {
    /// Current microphone authorization. Never prompts. Safe to call from
    /// any thread that's allowed to touch AVCaptureDevice — the SwiftUI
    /// step views call this from the main actor via `Task { @MainActor in }`.
    @MainActor
    public static func microphone() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Current accessibility (AX) trust. `options=nil` is the documented
    /// prompt-free form — passing `kAXTrustedCheckOptionPrompt: true` would
    /// open System Settings, which is the wrong behavior for a poll.
    public static func accessibility() -> PermissionStatus {
        AXIsProcessTrustedWithOptions(nil) ? .granted : .denied
    }

    /// Triggers Apple's TCC microphone prompt. Returns the new status when
    /// the user dismisses the alert. If the user previously denied, this is
    /// a no-op and resolves with `.denied`.
    public static func requestMicrophone() async -> PermissionStatus {
        // If we already have an answer, short-circuit. `requestAccess` on an
        // already-denied app does NOT re-prompt; it just calls back with
        // `false`, which would look the same as a fresh denial.
        let current = await MainActor.run { microphone() }
        if current != .notDetermined { return current }

        return await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    /// Deep-link into System Settings → Privacy & Security → Accessibility.
    /// macOS 13+ accepts the legacy `x-apple.systempreferences:` URL form.
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Deep-link into Privacy & Security → Microphone. Useful when the user
    /// has already denied the prompt and needs to flip the toggle manually.
    public static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
