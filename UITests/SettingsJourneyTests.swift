import XCTest

/// Journey 5: open Settings, see Export and Import and keep Timer Sound off across a relaunch, then see Import switch off while a workout is in
/// progress. The share sheet and the file importer are system UI, so the journey stops at their buttons.
final class SettingsJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testExportAndImportRows() {
        let app = XCUIApplication.launchedForTesting()

        auditAccessibility(of: app, screen: "the Workout tab") {
            $0.isSystemControl(["Start Empty Workout"])
        }

        step("Open Settings and see Export and Import offered") {
            // The tab bar's identifiers go missing from the tree after an audit, so find the tab by its label.
            let settingsTab = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settingsTab.appears())
            settingsTab.tap()
            XCTAssertTrue(app.buttons["settings.export"].appears())
            XCTAssertTrue(app.buttons["settings.export"].isEnabled)
            XCTAssertTrue(app.buttons["settings.import"].isEnabled)
            XCTAssertTrue(
                app.staticTexts["Importing replaces all data on this phone with a backup file."]
                    .exists)
        }

        auditAccessibility(of: app, screen: "Settings")

        step("Turn Timer Sound off, relaunch and see it still off") {
            let sound = app.switches["settings.timerSound"]
            XCTAssertEqual(sound.value as? String, "1")
            // A tap at the row's center misses the switch, which sits at its trailing edge.
            sound.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            // The switch's value updates a moment after the tap.
            let off = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == '0'"), object: sound)
            XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: 5), .completed)
            app.relaunchKeepingDefaults()
            XCTAssertTrue(app.tabBars.buttons["Settings"].appears())
            app.tabBars.buttons["Settings"].tap()
            XCTAssertTrue(sound.appears())
            XCTAssertEqual(sound.value as? String, "0")
        }

        step("Start a workout, minimize it and see Import switched off with its reason") {
            app.buttons["tabs.workout"].tap()
            app.startWorkout()
            app.buttons["workout.minimize"].tap()
            // The tab bar's identifiers are missing from the tree for a moment while the sheet minimizes.
            XCTAssertTrue(app.buttons["tabs.settings"].appears())
            app.buttons["tabs.settings"].tap()
            XCTAssertTrue(app.buttons["settings.import"].appears())
            XCTAssertFalse(app.buttons["settings.import"].isEnabled)
            XCTAssertTrue(
                app.staticTexts["Finish or discard your workout in progress to import."].exists)
            XCTAssertTrue(app.buttons["settings.export"].isEnabled)
        }
    }
}
