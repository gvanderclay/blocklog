import XCTest

extension XCTestCase {
    /// Runs the body as a named activity, so a failure names the step that broke.
    @MainActor
    func step(_ name: String, _ body: () -> Void) {
        XCTContext.runActivity(named: name) { _ in body() }
    }
}
