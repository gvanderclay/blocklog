import Foundation
import Testing

@testable import Blocklog

/// Proves the unit bundle is hosted in the app and can import its module.
@Test func hostedInApp() {
    #expect(Bundle.main.bundleIdentifier == "com.gvanderclay.blocklog")
}
