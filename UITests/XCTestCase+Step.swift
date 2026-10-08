import XCTest

extension XCTestCase {
    /// Runs the body as a named activity, so a failure names the step that broke. A body that throws fails the test.
    @MainActor
    func step(_ name: String, _ body: () throws -> Void) rethrows {
        try XCTContext.runActivity(named: name) { _ in try body() }
    }
}
