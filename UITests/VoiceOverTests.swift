import XCTest

/// VoiceOver traversal of one set row, with the real VoiceOver (`XCUIVoiceOverService`, iOS 27).
///
/// Why it is a class of its own and not a step of a journey: VoiceOver speaks aloud from the simulator, so
/// `just test` and `just test-ui` skip this class and only CI (`just ci-test BlocklogUI`) runs it, and turning
/// VoiceOver on also changes how taps behave, which would disturb a journey's later steps.
/// Never run it locally: `just test-one BlocklogUITests/VoiceOverTests` would turn VoiceOver on.
final class VoiceOverTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Swiping forward through a checked set of 15 pounds times 10 speaks the set number, the weight, the reps
    /// and the check state as `docs/design.md` words them: "Weight, 15 pounds", "Reps, 10", "Set 1, done".
    @MainActor
    func testSetRowIsSpokenWithNumberWeightRepsAndCheckState() throws {
        let app = XCUIApplication.launchedForTesting()
        let voiceOver = XCUIDevice.shared.voiceOverService
        // A failed assertion must not leave VoiceOver talking. A killed runner (a timeout) gets no teardown,
        // so CI's simulator is not reused after it.
        addTeardownBlock { @MainActor in
            do {
                if voiceOver.isEnabled { try voiceOver.disable() }
            } catch {
                XCTFail("Couldn't turn VoiceOver off: \(error)")
            }
            XCTAssertFalse(voiceOver.isEnabled, "VoiceOver is still on after the test")
        }

        step("Log one checked set: 15 pounds times 10") {
            app.startWorkout()
            app.addExercise("Dumbbell Bench Press", as: 0)
            let plus = app.buttons["workout.exercise.0.set.0.weightPlus"]
            for _ in 0..<3 { plus.tap() }
            app.type("10", into: "workout.exercise.0.set.0.reps")
        }

        var spoken: [String] = []
        try step("Swipe forward until VoiceOver reaches the set's check button") {
            try voiceOver.enable()
            // The set row is near the top of the screen; 40 swipes is far more than it needs.
            for _ in 0..<40 {
                let utterance = try voiceOver.moveForward().utterance
                spoken.append(utterance)
                if utterance.contains("Set 1") { break }
            }
            XCTAssertTrue(
                spoken.last?.contains("Set 1") == true,
                "VoiceOver never reached the check button; it spoke \(spoken)")
        }

        step("The row is spoken as set number, weight, reps and check state") {
            let row = Array(spoken.drop { !$0.contains("Set type") })
            XCTAssertFalse(row.isEmpty, "VoiceOver never spoke the set type; it spoke \(spoken)")
            func spokenElement(_ label: String, _ value: String) -> Bool {
                row.contains { $0.contains(label) && $0.contains(value) }
            }
            XCTAssertTrue(spokenElement("Set type", "1"), "set number: \(row)")
            XCTAssertTrue(spokenElement("Weight", "15 pounds"), "weight: \(row)")
            XCTAssertTrue(spokenElement("Reps", "10"), "reps: \(row)")
            // VoiceOver drops the comma ("selected Set 1 done Button"), so match the words. "Set 1, not done"
            // is the unchecked phrasing and also contains "done".
            XCTAssertTrue(
                row.contains {
                    let words = $0.replacingOccurrences(of: ",", with: "")
                    return words.contains("Set 1 done") && !words.contains("not done")
                },
                "check state: \(row)")
        }
    }
}
