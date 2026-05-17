import XCTest
@testable import Murmur

final class OnboardingStepTests: XCTestCase {
    func test_allStepsHaveTitle() {
        for step in OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "step \(step) is missing a title")
        }
    }

    func test_ordinalIsMonotonic() {
        // Ordinals must match the declaration order in allCases.
        for (idx, step) in OnboardingStep.allCases.enumerated() {
            XCTAssertEqual(step.ordinal, idx,
                           "step \(step) ordinal \(step.ordinal) != index \(idx)")
        }
    }

    func test_nextWalksAllCases_andStopsAtDone() {
        var visited: [OnboardingStep] = []
        var current: OnboardingStep? = .welcome
        while let step = current {
            visited.append(step)
            current = step.next()
            // Guard against an infinite loop if next() ever returns the
            // current step by accident.
            XCTAssertLessThanOrEqual(visited.count, OnboardingStep.allCases.count + 1,
                                      "next() did not terminate; visited: \(visited)")
        }
        XCTAssertEqual(visited, OnboardingStep.allCases,
                       "next() must visit every case in declaration order")
        XCTAssertEqual(visited.last, .done, "next() should terminate at .done")
        XCTAssertNil(OnboardingStep.done.next(), ".done.next() must be nil")
    }

    func test_previousWalksBackToWelcome() {
        var current: OnboardingStep? = .done
        var visited: [OnboardingStep] = []
        while let step = current {
            visited.append(step)
            current = step.previous()
        }
        XCTAssertEqual(visited.first, .done)
        XCTAssertEqual(visited.last, .welcome)
        XCTAssertNil(OnboardingStep.welcome.previous(), ".welcome.previous() must be nil")
    }

    func test_modelStep_isNotSkippable_othersAre() {
        XCTAssertFalse(OnboardingStep.model.isSkippable,
                       "model step must be required — no transcription without a model")
        for step in OnboardingStep.allCases where step != .model {
            XCTAssertTrue(step.isSkippable, "step \(step) should be skippable")
        }
    }

    func test_visibleSteps_excludesDone() {
        let visible = OnboardingStep.visibleSteps
        XCTAssertFalse(visible.contains(.done),
                       "visibleSteps must hide the terminal .done sentinel")
        XCTAssertEqual(visible.count, OnboardingStep.allCases.count - 1)
    }

    func test_codable_roundTrips() throws {
        for step in OnboardingStep.allCases {
            let data = try JSONEncoder().encode(step)
            let decoded = try JSONDecoder().decode(OnboardingStep.self, from: data)
            XCTAssertEqual(step, decoded)
        }
    }
}
