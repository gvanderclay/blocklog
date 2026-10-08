import SwiftUI

/// − and + step through the PowerBlock settings; tapping the value opens a menu of all of them.
/// For a bodyweight set (`isAdded`), the value is the added weight, and nil shows "BW".
struct WeightControl: View {
    let weight: Double?
    /// True for the added weight of a bodyweight set, which can also be nil ("BW").
    var isAdded = false
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let onChange: (Double?) -> Void

    var body: some View {
        let previous =
            isAdded ? AddedWeight.previous(before: weight) : PowerBlockTable.stepDown(from: weight)
        let next = isAdded ? AddedWeight.next(after: weight) : PowerBlockTable.stepUp(from: weight)
        let canDecrease = isAdded ? AddedWeight.canDecrease(from: weight) : previous != nil
        let name = isAdded ? "addedWeight" : "weight"
        let options: [Double?] = isAdded ? AddedWeight.options : PowerBlockTable.weights.map { $0 }
        HStack(spacing: 0) {
            Button("Decrease weight", systemImage: "minus") {
                onChange(previous)
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(!canDecrease)
            .accessibilityIdentifier("\(identifierPrefix).\(name)Minus")

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
                    .accessibilityIdentifier("\(identifierPrefix).\(name)Option.\(index)")
                }
            } label: {
                Text(text(for: weight))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: weight ?? 0))
                    .frame(minHeight: 44)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)
            .accessibilityLabel(isAdded ? "Added weight" : "Weight")
            .accessibilityValue(
                weight.map { "\($0.formatted()) pounds" } ?? "bodyweight"
            )
            .accessibilityIdentifier("\(identifierPrefix).\(name)Value")

            Button("Increase weight", systemImage: "plus") {
                if let next { onChange(next) }
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(next == nil)
            .accessibilityIdentifier("\(identifierPrefix).\(name)Plus")
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: weight)
    }

    private func text(for weight: Double?) -> String {
        isAdded ? AddedWeight.label(for: weight) : "\((weight ?? 0).formatted()) lb"
    }
}
