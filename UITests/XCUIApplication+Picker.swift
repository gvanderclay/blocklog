import XCTest

extension XCUIApplication {
    /// In the open exercise picker, finds the exercise by name in the search field, dismisses the keyboard
    /// (a push with the keyboard up stalls XCTest) and taps its row, which then sits at the top of the list.
    @MainActor
    func pickExercise(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let search = searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), file: file, line: line)
        search.tap()
        search.typeText(name)
        search.typeText("\n")
        let row = buttons["exercisePicker.row.\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), file: file, line: line)
        row.tap()
    }
}
