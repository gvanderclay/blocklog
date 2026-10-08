import XCTest

extension XCUIApplication {
    /// Taps a text field and asserts that it gained keyboard focus, shown by the keyboard toolbar's
    /// Done button, tapping a second time if the first tap's focus was dropped.
    ///
    /// Why a second tap: on a cold simulator under heavy host load, the first keyboard bring-up can
    /// take tens of seconds. While it runs, the system keyboard arbiter (in the InputUI process) logs
    /// "assertion invalidated" and "timed out with 1 assertions remaining, disconnecting" for the
    /// app's client handle. The app then logs "KeyboardArbiter:Client failedConnection" followed by
    /// "handleKeyboardChange: resignFirstResponder", so the field loses focus before the tap returns.
    /// Nothing in the app takes the focus away. The second bring-up is warm and keeps its focus.
    @MainActor
    func focus(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        field.tap()
        let done = buttons["keyboard.done"]
        if done.appears() { return }
        XCTContext.runActivity(
            named:
                "Keyboard didn't appear after the first tap; re-tapping (cold-simulator keyboard arbiter drop, see XCUIApplication+Focus.swift)"
        ) { _ in
            print("focus(_:): keyboard didn't appear after tapping \(field.identifier); re-tapping")
            field.tap()
        }
        XCTAssertTrue(
            done.appears(timeout: 10),
            "\(field.identifier) has no keyboard focus after a second tap", file: file, line: line)
    }
}
