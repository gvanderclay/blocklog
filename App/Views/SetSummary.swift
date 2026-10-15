import SwiftUI

/// A set that isn't open, as one line: its check state, label and values. Tapping it opens the set.
/// An unchecked set shows the values checking it off would log. The set row puts the stopwatch beside it.
struct SetSummary: View {
    let label: String
    let spokenName: String
    let values: SetValues
    let isDone: Bool
    /// True while the weight is the one progression pre-filled, shown in the accent color.
    let isHighlighted: Bool
    /// True in past-workout editing: every set counts as done, so there is no check indicator or "done".
    let isEditingPast: Bool
    /// The red hint for a past set missing a value, such as "Add reps"; nil for none.
    let hint: String?
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    /// Bumped when the set is checked off, so the indicator bounces.
    let checkOffCount: Int
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if !isEditingPast {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isDone ? Color.green : Color.secondary)
                            .symbolEffect(.bounce, value: checkOffCount)
                            .symbolEffectsRemoved(reduceMotion)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .leading)
                    Text(values.text)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(valueStyle)
                    Spacer(minLength: 0)
                }
                if let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                        .accessibilityIdentifier("\(identifierPrefix).hint")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)  // `.ignore` makes a new element, which drops the Button's trait
        .accessibilityLabel(spokenName)
        .accessibilityValue(spokenValue)
        .accessibilityHint("Opens the set")
        .accessibilityIdentifier("\(identifierPrefix).summary")
    }

    private var valueStyle: Color {
        if isHighlighted { return .accentColor }
        return isDone || isEditingPast ? .primary : .secondary
    }

    private var spokenValue: String {
        if isEditingPast { return values.spokenText + (hint.map { ", \($0)" } ?? "") }
        return values.spokenText + (isDone ? ", done" : ", not done")
    }
}
