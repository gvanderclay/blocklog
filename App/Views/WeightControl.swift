import SwiftUI

/// − and + step through the PowerBlock settings; tapping the value opens a menu of all of them.
struct WeightControl: View {
    let weight: Double
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let onChange: (Double) -> Void

    var body: some View {
        let previous = PowerBlockTable.previous(before: weight)
        let next = PowerBlockTable.next(after: weight)
        HStack(spacing: 0) {
            Button("Decrease weight", systemImage: "minus") {
                if let previous { onChange(previous) }
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(previous == nil)
            .accessibilityIdentifier("\(identifierPrefix).weightMinus")

            Menu {
                ForEach(PowerBlockTable.weights.enumerated(), id: \.element) { index, option in
                    Button {
                        onChange(option)
                    } label: {
                        if option == weight {
                            Label("\(option, format: .number) lb", systemImage: "checkmark")
                        } else {
                            Text("\(option, format: .number) lb")
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix).weightOption.\(index)")
                }
            } label: {
                Text("\(weight, format: .number) lb")
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: weight))
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Weight")
            .accessibilityValue("\(weight, format: .number) pounds")
            .accessibilityIdentifier("\(identifierPrefix).weightValue")

            Button("Increase weight", systemImage: "plus") {
                if let next { onChange(next) }
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .disabled(next == nil)
            .accessibilityIdentifier("\(identifierPrefix).weightPlus")
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: weight)
    }
}
