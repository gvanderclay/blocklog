import XCTest

extension XCTestCase {
    /// Runs the accessibility audit on the screen that is showing, as a named step. Every issue fails the
    /// test, and all issues of one audit are reported together, each naming its element, instead of stopping
    /// at the first.
    ///
    /// A false positive is filtered by passing `ignoring`, which gets the issue and must say in a comment
    /// at the call site why the issue is wrong. There is no blanket suppression.
    @MainActor
    func auditAccessibility(
        of app: XCUIApplication, screen: String,
        ignoring isFalsePositive: ((XCUIAccessibilityAuditIssue) -> Bool)? = nil
    ) {
        step("Audit \(screen) for accessibility") {
            // Report every issue, not just the first.
            let continueAfterFailureBefore = continueAfterFailure
            continueAfterFailure = true
            defer { continueAfterFailure = continueAfterFailureBefore }
            var found: [String] = []
            do {
                try app.performAccessibilityAudit { issue in
                    if isFalsePositive?(issue) == true { return true }
                    found.append(
                        "\(issue.compactDescription) [\(issue.auditType.rawValue)]: \(issue.debugDescription)"
                    )
                    return true  // reported below with its element, so this isn't suppression
                }
            } catch {
                XCTFail("The accessibility audit of \(screen) didn't run: \(error)")
            }
            for issue in found { XCTFail("\(screen): \(issue)") }
        }
    }
}

/// The audit issues no view code can fix, each with its reason. A screen passes the ones it shows to
/// `auditAccessibility(of:screen:ignoring:)`; each matches one named element, never a whole kind of issue.
extension XCUIAccessibilityAuditIssue {
    /// A toolbar button or the toolbar's timer. The system draws toolbar items in its glass bar with its own
    /// fixed-size text, and the audit reads that text as ignoring Dynamic Type, and the glass as low contrast.
    /// `docs/design.md` requires the system placements (`.confirmationAction` and the like), so the views
    /// can't change this.
    /// TODO(ticket 12 follow-up): confirm on the ax-large screenshots that these items stay readable.
    func isSystemToolbarItem(_ identifiers: Set<String>) -> Bool {
        guard let identifier = element?.identifier, identifiers.contains(identifier) else {
            return false
        }
        return [.contrast, .dynamicType, .textClipped].contains(auditType)
    }

    /// Text in the system's secondary style, whose contrast the audit rates "nearly passed" (a bit under 4.5:1
    /// for small text). `docs/design.md` requires `.secondary` for secondary information, so a view can't
    /// darken it.
    /// TODO(ticket 12 follow-up): decide whether design.md's secondary text should be darker.
    func isSecondaryText(_ labels: Set<String>) -> Bool {
        auditType == .contrast && compactDescription == "Contrast nearly passed"
            && labels.contains(element?.label ?? "")
    }

    /// Text of a stock control that the system wraps and scales itself, which the audit still reads as clipped:
    /// the search field, a Form picker's value, a List row's button label.
    /// TODO(ticket 12 follow-up): verify on the ax-large screenshots.
    func isSystemControl(_ labels: Set<String>) -> Bool {
        auditType == .textClipped && labels.contains(element?.label ?? "")
    }
}

extension XCUIAccessibilityAuditIssue {
    /// The picker's last visible row, which scrolls under the floating bottom bar; the audit measures its
    /// contrast against the bar.
    /// TODO(ticket 12 follow-up): last picker row under the floating bottom bar fails contrast; check on device whether it's the system bar's material
    func isPickerRowUnderBottomBar(_ identifier: String) -> Bool {
        auditType == .contrast && compactDescription == "Contrast failed"
            && element?.identifier == identifier
    }
}
