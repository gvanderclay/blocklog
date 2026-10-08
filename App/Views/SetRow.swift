import SwiftData
import SwiftUI

/// One set: its type label, the fields its exercise kind records, and a check-off button.
/// Swipe left deletes it; a long press opens its set-type, duplicate and delete menu.
struct SetRow: View {
    let set: WorkoutSet
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// Called after the set is deleted, so the screen plays the delete haptic.
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkOffCount = 0
    @State private var saveFailed = false

    var body: some View {
        @Bindable var set = set
        let label = SetNumbering.label(of: set)
        let kind = set.workoutExercise?.exercise?.kind ?? .weightReps
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
        layout {
            Menu {
                typeButtons(identifier: "setMenu.type")
            } label: {
                Text(label)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 28, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Set type")
            .accessibilityValue(label)
            .accessibilityIdentifier("\(identifierPrefix).typeMenu")
            switch kind {
            case .weightReps:
                if let weight = set.weight {
                    WeightControl(weight: weight, identifierPrefix: identifierPrefix) { newWeight in
                        guard let newWeight else { return }
                        withAnimation {
                            attempt { try $0.setWeight(newWeight, of: set) }
                        }
                    }
                }
            case .bodyweightReps:
                WeightControl(weight: set.weight, isAdded: true, identifierPrefix: identifierPrefix)
                {
                    newWeight in
                    withAnimation {
                        attempt { try $0.setAddedWeight(newWeight, of: set) }
                    }
                }
            case .duration:
                EmptyView()
            }
            Spacer(minLength: 0)
            if kind == .duration {
                HStack(spacing: 4) {
                    TextField("Seconds", text: $set.durationText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .frame(minWidth: 72, maxWidth: 96, minHeight: 44)
                        .focused(focusedRepsSetID, equals: set.id)
                        .accessibilityIdentifier("\(identifierPrefix).duration")
                    Text("s").foregroundStyle(.secondary)
                }
            } else {
                TextField("Reps", text: $set.repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .frame(minWidth: 56, maxWidth: 80, minHeight: 44)
                    .focused(focusedRepsSetID, equals: set.id)
                    .accessibilityIdentifier("\(identifierPrefix).reps")
            }
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
            .accessibilityLabel("Set \(label)")
            .accessibilityValue(set.isCompleted ? "done" : "not done")
            .accessibilityIdentifier("\(identifierPrefix).check")
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.15) : nil)
        .sensoryFeedback(trigger: set.isCompleted) { _, isCompleted in
            isCompleted ? .success : .impact(weight: .light)
        }
        .sensoryFeedback(.selection, trigger: set.setType)
        .swipeActions(edge: .trailing) {
            deleteButton
        }
        .contextMenu {
            Menu("Set Type", systemImage: "list.number") {
                typeButtons(identifier: "setMenu.type")
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                withAnimation {
                    attempt { try $0.duplicateSet(set) }
                }
            }
            .accessibilityIdentifier("setMenu.duplicate")
            deleteButton
        }
        .onChange(of: set.reps) {
            attempt { try $0.save() }
        }
        .onChange(of: set.durationSeconds) {
            attempt { try $0.save() }
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private var deleteButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation {
                attempt { try $0.deleteSet(set) }
            }
            onDelete()
        }
        .accessibilityIdentifier("setMenu.delete")
    }

    /// One button per set type, the current one checked.
    private func typeButtons(identifier: String) -> some View {
        ForEach(SetType.allCases, id: \.self) { type in
            Button {
                attempt { try $0.setType(type, of: set) }
            } label: {
                if set.setType == type {
                    Label(type.title, systemImage: "checkmark")
                } else {
                    Text(type.title)
                }
            }
            .accessibilityIdentifier("\(identifier).\(type.rawValue)")
        }
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
