import XCTest

extension XCUIElement {
    /// True when the element is in the accessibility tree. Checks first, because `waitForExistence` spends about 1 s
    /// before its first check even when the element is already there (docs/research/ui-test-speed.md).
    @MainActor
    func appears(timeout: TimeInterval = 5) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }

    /// True when the element is gone, with the same up-front check.
    @MainActor
    func disappears(timeout: TimeInterval = 5) -> Bool {
        !exists || waitForNonExistence(timeout: timeout)
    }
}
