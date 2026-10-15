import SwiftUI

/// − and + step through the PowerBlock settings; tapping the value opens a menu of all of them.
/// For a bodyweight set (`isAdded`), the value is the added weight, and nil shows "BW".
struct WeightControl: View {
    let weight: Double?
    /// True for the added weight of a bodyweight set, which can also be nil ("BW").
    var isAdded = false
    /// True while the weight is the one progression pre-filled, shown in the accent color.
    var isHighlighted = false
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    /// The set's spoken name, such as "Set 2", which starts each VoiceOver label; nil for a control that isn't
    /// a set's, such as the AMRAP player's weight.
    var spokenSetName: String?
    /// True for the identifiers `<prefix>.decrease`, `.value`, `.option.<i>` and `.increase`, as the AMRAP
    /// player's weights use; otherwise `<prefix>.weightMinus`, `.weightValue`, `.weightOption.<i>` and
    /// `.weightPlus` (`addedWeight…` for an added weight).
    var usesStepIdentifiers = false
    let onChange: (Double?) -> Void

    var body: some View {
        let previous =
            isAdded ? AddedWeight.previous(before: weight) : PowerBlockTable.stepDown(from: weight)
        let next = isAdded ? AddedWeight.next(after: weight) : PowerBlockTable.stepUp(from: weight)
        let canDecrease = isAdded ? AddedWeight.canDecrease(from: weight) : previous != nil
        let name = isAdded ? "addedWeight" : "weight"
        let ids =
            usesStepIdentifiers
            ? (minus: "decrease", value: "value", option: "option.", plus: "increase")
            : (
                minus: "\(name)Minus", value: "\(name)Value", option: "\(name)Option.",
                plus: "\(name)Plus"
            )
        let options: [Double?] = isAdded ? AddedWeight.options : PowerBlockTable.weights.map { $0 }
        HStack(spacing: 0) {
            Button("Decrease weight", systemImage: "minus") {
                onChange(previous)
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(!canDecrease)
            .accessibilityLabel(spoken("Decrease weight"))
            .accessibilityIdentifier("\(identifierPrefix).\(ids.minus)")

            Menu {
                ForEach(options.enumerated(), id: \.offset) { index, option in
                    Button {
                        onChange(option)
                    } label: {
                        if option == weight {
                            Label(text(for: option), systemImage: "checkmark")
                        } else {
                            Text(text(for: option))
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix).\(ids.option)\(index)")
                }
            } label: {
                Text(text(for: weight))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(isHighlighted ? Color.accentColor : Color.primary)
                    .contentTransition(.numericText(value: weight ?? 0))
                    .frame(minWidth: 44, minHeight: 44)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)
            .accessibilityLabel(spoken(isAdded ? "Added weight" : "Weight"))
            .accessibilityValue(
                weight.map { "\($0.formatted()) pounds" } ?? "bodyweight"
            )
            .accessibilityIdentifier("\(identifierPrefix).\(ids.value)")

            Button("Increase weight", systemImage: "plus") {
                if let next { onChange(next) }
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(next == nil)
            .accessibilityLabel(spoken("Increase weight"))
            .accessibilityIdentifier("\(identifierPrefix).\(ids.plus)")
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: weight)
    }

    /// "Set 2 decrease weight" for a set's control, else the label as it is.
    private func spoken(_ label: String) -> String {
        guard let spokenSetName else { return label }
        return "\(spokenSetName) \(label.prefix(1).lowercased())\(label.dropFirst())"
    }

    private func text(for weight: Double?) -> String {
        isAdded ? AddedWeight.label(for: weight) : "\((weight ?? 0).formatted()) lb"
    }
}
