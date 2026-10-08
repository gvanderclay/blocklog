import SwiftData
import SwiftUI

/// The in-progress workout: its exercises and sets, presented full screen.
struct WorkoutScreen: View {
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedRepsSetID: UUID?
    @State private var isPickingExercise = false
    @State private var isReordering = false
    @State private var deleteCount = 0
    @State private var isFinishing = false
    @State private var isConfirmingDiscard = false
    @State private var isDiscarded = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(WorkoutLog.orderedExercises(of: workout).enumerated(), id: \.element.id) {
                    index, workoutExercise in
                    ExerciseSection(
                        workoutExercise: workoutExercise, exerciseIndex: index,
                        focusedRepsSetID: $focusedRepsSetID, deleteCount: $deleteCount)
                }
                Section {
                    Button("Add Exercise", systemImage: "plus") { isPickingExercise = true }
                        .accessibilityIdentifier("workout.addExercise")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Minimize", systemImage: "chevron.down") { dismiss() }
                        .accessibilityIdentifier("workout.minimize")
                }
                ToolbarItem(placement: .principal) {
                    Text(workout.startDate, style: .timer)
                        .font(.headline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .accessibilityLabel("Elapsed time")
                        .accessibilityIdentifier("workout.elapsed")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { isFinishing = true }
                        .accessibilityIdentifier("workout.finish")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Reorder", systemImage: "arrow.up.arrow.down") {
                            isReordering = true
                        }
                        .disabled(!WorkoutLog.canReorder(workout))
                        .accessibilityIdentifier("workout.reorder")
                        Button("Discard Workout", systemImage: "trash", role: .destructive) {
                            isConfirmingDiscard = true
                        }
                        .accessibilityIdentifier("workout.discard")
                    }
                    .accessibilityIdentifier("workout.menu")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Next") {
                        focusedRepsSetID = focusedRepsSetID.flatMap {
                            WorkoutLog.nextEmptySet(after: $0, in: workout)?.id
                        }
                    }
                    .accessibilityIdentifier("keyboard.next")
                    Button("Done") { focusedRepsSetID = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
            }
            .confirmationDialog(
                "Discard this workout?", isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) {
                    isDiscarded = true
                    dismiss()
                }
                .accessibilityIdentifier("workout.discardConfirm")
            } message: {
                Text("Its sets will be deleted.")
            }
            .sheet(isPresented: $isPickingExercise) {
                ExercisePicker { exercise in
                    withAnimation {
                        do {
                            try WorkoutLog(context: modelContext).addExercise(exercise, to: workout)
                        } catch {
                            saveFailed = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isReordering) {
                ReorderSheet(workout: workout)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isFinishing) {
                FinishSheet(workout: workout) { dismiss() }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
        .onDisappear {
            // Deleted only once the screen is gone, so nothing renders a deleted workout.
            // shortcut: a failed save here has no screen left to alert on; discard rolls back, so the
            // workout stays in progress and the Workout tab offers it again. Alert there if this ever fails in practice.
            if isDiscarded {
                try? WorkoutLog(context: modelContext).discard(workout)
            }
        }
    }
}

/// One workout exercise: its sets and an Add Set button.
private struct ExerciseSection: View {
    let workoutExercise: WorkoutExercise
    let exerciseIndex: Int
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// Bumped on every deletion, so the screen plays the delete haptic.
    @Binding var deleteCount: Int

    @Environment(\.modelContext) private var modelContext
    @State private var saveFailed = false
    @State private var isConfirmingRemove = false

    var body: some View {
        Section {
            ForEach(WorkoutLog.orderedSets(of: workoutExercise).enumerated(), id: \.element.id) {
                setIndex, set in
                SetRow(
                    set: set,
                    identifierPrefix: "workout.exercise.\(exerciseIndex).set.\(setIndex)",
                    focusedRepsSetID: focusedRepsSetID, onDelete: { deleteCount += 1 })
            }
            Button("Add Set", systemImage: "plus") {
                withAnimation {
                    do {
                        try WorkoutLog(context: modelContext).addSet(to: workoutExercise)
                    } catch {
                        saveFailed = true
                    }
                }
            }
            .saveFailedAlert(isPresented: $saveFailed)
            .accessibilityIdentifier("workout.exercise.\(exerciseIndex).addSet")
        } header: {
            HStack {
                Text(workoutExercise.exercise?.name ?? "Exercise")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("workout.exercise.\(exerciseIndex).name")
                Spacer()
                Menu("Exercise Actions", systemImage: "ellipsis.circle") {
                    Button("Remove Exercise", systemImage: "trash", role: .destructive) {
                        if WorkoutLog.needsRemovalConfirmation(workoutExercise) {
                            isConfirmingRemove = true
                        } else {
                            removeExercise()
                        }
                    }
                    .accessibilityIdentifier("workout.exercise.\(exerciseIndex).remove")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("workout.exercise.\(exerciseIndex).menu")
            }
            .confirmationDialog(
                "Remove this exercise?", isPresented: $isConfirmingRemove, titleVisibility: .visible
            ) {
                Button("Remove Exercise", role: .destructive) { removeExercise() }
                    .accessibilityIdentifier("workout.exercise.\(exerciseIndex).removeConfirm")
            } message: {
                Text("Its sets will be deleted.")
            }
        }
        .headerProminence(.increased)
    }

    private func removeExercise() {
        withAnimation {
            do {
                try WorkoutLog(context: modelContext).removeExercise(workoutExercise)
                deleteCount += 1
            } catch {
                saveFailed = true
            }
        }
    }
}

/// A compact list of the exercise names to drag into a new order; Done applies it.
private struct ReorderSheet: View {
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var order: [WorkoutExercise]
    @State private var saveFailed = false

    init(workout: Workout) {
        self.workout = workout
        _order = State(initialValue: WorkoutLog.orderedExercises(of: workout))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(order.enumerated(), id: \.element.id) { index, workoutExercise in
                    Text(workoutExercise.exercise?.name ?? "Exercise")
                        .accessibilityIdentifier("reorder.row.\(index)")
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        do {
                            try WorkoutLog(context: modelContext).reorderExercises(order)
                            dismiss()
                        } catch {
                            saveFailed = true
                        }
                    }
                    .accessibilityIdentifier("reorder.done")
                }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
        .presentationDetents([.medium])
    }
}
