import SwiftData
import SwiftUI

/// One weight × reps set: its number, weight, reps and check-off button.
struct SetRow: View {
    let set: WorkoutSet
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let focusedRepsSetID: FocusState<UUID?>.Binding

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkOffCount = 0
    @State private var saveFailed = false

    var body: some View {
        @Bindable var set = set
        let number = WorkoutLog.setNumber(of: set)
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
        layout {
            Text("\(number)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .leading)
                .accessibilityLabel("Set \(number)")
                .accessibilityIdentifier("\(identifierPrefix).number")
            if let weight = set.weight {
                WeightControl(weight: weight, identifierPrefix: identifierPrefix) { newWeight in
                    withAnimation {
                        attempt { try $0.setWeight(newWeight, of: set) }
                    }
                }
            }
            Spacer(minLength: 0)
            TextField("Reps", text: $set.repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .fontDesign(.rounded)
                .monospacedDigit()
                .frame(minWidth: 56, maxWidth: 80, minHeight: 44)
                .focused(focusedRepsSetID, equals: set.id)
                .accessibilityIdentifier("\(identifierPrefix).reps")
            Button {
                withAnimation {
                    attempt { try $0.toggleCompleted(set) }
                }
                if set.isCompleted { checkOffCount += 1 }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        set.isCompleted ? Color.green : Color.secondary
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: checkOffCount)
                    .symbolEffectsRemoved(reduceMotion)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .disabled(!set.isCompleted && !WorkoutLog.canCheckOff(set))
            .accessibilityLabel("Set \(number)")
            .accessibilityValue(set.isCompleted ? "done" : "not done")
            .accessibilityIdentifier("\(identifierPrefix).check")
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.15) : nil)
        .sensoryFeedback(trigger: set.isCompleted) { _, isCompleted in
            isCompleted ? .success : .impact(weight: .light)
        }
        .onChange(of: set.reps) {
            attempt { try $0.save() }
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// Runs a change through the workout log, showing the alert if it fails to save.
    private func attempt(_ change: (WorkoutLog) throws -> Void) {
        do {
            try change(WorkoutLog(context: modelContext))
        } catch {
            saveFailed = true
        }
    }
}
