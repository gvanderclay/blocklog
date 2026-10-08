import XCTest

/// Journey 5: open Settings and see Export and Import, then see Import switch off while a workout is in
/// progress. The share sheet and the file importer are system UI, so the journey stops at their buttons.
final class SettingsJourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testExportAndImportRows() {
        let app = XCUIApplication.launchedForTesting()

        step("Open Settings and see Export and Import offered") {
            app.buttons["tabs.settings"].tap()
            XCTAssertTrue(app.buttons["settings.export"].appears())
            XCTAssertTrue(app.buttons["settings.export"].isEnabled)
            XCTAssertTrue(app.buttons["settings.import"].isEnabled)
            XCTAssertTrue(
                app.staticTexts["Importing replaces all data on this phone with a backup file."]
                    .exists)
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
