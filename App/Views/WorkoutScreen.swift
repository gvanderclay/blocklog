import SwiftData
import SwiftUI

/// The in-progress workout: its exercises and sets, presented full screen.
struct WorkoutScreen: View {
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedRepsSetID: UUID?
    @State private var isPickingExercise = false
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
                        focusedRepsSetID: $focusedRepsSetID)
                }
                Section {
                    Button("Add Exercise", systemImage: "plus") { isPickingExercise = true }
                        .accessibilityIdentifier("workout.addExercise")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                            WorkoutLog.nextEmptyRepsSet(after: $0, in: workout)?.id
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
            .sheet(isPresented: $isFinishing) {
                FinishSheet(workout: workout) { dismiss() }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
        .onDisappear {
            // Deleted only once the screen is gone, so nothing renders a deleted workout.
            // ponytail: a failed save here has no screen left to alert on; autosave retries the delete.
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

    @Environment(\.modelContext) private var modelContext
    @State private var saveFailed = false

    var body: some View {
        Section {
            ForEach(WorkoutLog.orderedSets(of: workoutExercise).enumerated(), id: \.element.id) {
                setIndex, set in
                SetRow(
                    set: set,
                    identifierPrefix: "workout.exercise.\(exerciseIndex).set.\(setIndex)",
                    focusedRepsSetID: focusedRepsSetID)
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
            Text(workoutExercise.exercise?.name ?? "Exercise")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workout.exercise.\(exerciseIndex).name")
        }
        .headerProminence(.increased)
    }
}
