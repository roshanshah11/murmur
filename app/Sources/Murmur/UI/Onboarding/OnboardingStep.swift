// Six-step first-launch wizard state machine.
//
// `.done` is a terminal sentinel: when the user lands there we mark
// onboardingCompletedVersion = "1.0" and dismiss the window. Steps are
// `Codable` so they can be persisted across an app relaunch (future work)
// without breaking the type signature.
import Foundation

public enum OnboardingStep: String, CaseIterable, Identifiable, Codable {
    case welcome
    case howItWorks
    case microphone
    case accessibility
    case model
    case test
    case done

    public var id: String { rawValue }

    /// Step title rendered at the top of each panel and used in the
    /// progress indicator.
    public var title: String {
        switch self {
        case .welcome:       return "Welcome"
        case .howItWorks:    return "How it works"
        case .microphone:    return "Microphone"
        case .accessibility: return "Accessibility"
        case .model:         return "Pick a model"
        case .test:          return "Test dictation"
        case .done:          return "Ready"
        }
    }

    /// Zero-based position in the canonical step order. `.done` is the
    /// highest ordinal; the progress dots stop drawing at the step before
    /// it so the UI doesn't show "step 7 of 7" on a single-button screen.
    public var ordinal: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    /// Returns the next step in the canonical order, or `nil` when called
    /// on `.done`. Used by the "Next" button to advance.
    public func next() -> OnboardingStep? {
        let idx = Self.allCases.firstIndex(of: self) ?? 0
        let nextIdx = idx + 1
        return nextIdx < Self.allCases.count ? Self.allCases[nextIdx] : nil
    }

    /// Returns the previous step, or `nil` when called on `.welcome`.
    /// Used by the "Back" button.
    public func previous() -> OnboardingStep? {
        let idx = Self.allCases.firstIndex(of: self) ?? 0
        let prevIdx = idx - 1
        return prevIdx >= 0 ? Self.allCases[prevIdx] : nil
    }

    /// Whether the user is allowed to use the "Skip" button on this step.
    /// `.model` is required because the app can't transcribe without a
    /// model; everything else is optional.
    public var isSkippable: Bool {
        switch self {
        case .model: return false
        default: return true
        }
    }

    /// Steps that should appear in the top-of-window progress indicator.
    /// `.done` is hidden because it's the terminal sentinel — the wizard
    /// transitions out of `.done` immediately after the final button.
    public static var visibleSteps: [OnboardingStep] {
        allCases.filter { $0 != .done }
    }
}
