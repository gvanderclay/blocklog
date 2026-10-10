import SwiftData
import SwiftUI

/// One finished workout: its title, date, duration and, for a Timed AMRAP, its score, then each exercise with its
/// sets. Edit switches it to
/// the workout screen's exercise sections and rows, with no rest timer, elapsed time or Finish.
struct HistoryDetail: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedRepsSetID: UUID?
    @State private var isEditing = false
    @State private var isPickingExercise = false
    @State private var isReordering = false
    @State private var deleteCount = 0
    @State private var saveFailed = false
    @State private var exerciseToRemove: WorkoutExercise?
    @State private var workoutToDelete: Workout?
    @State private var isDeleted = false
    /// Progression never applies to a past workout; the sections need a binding.
    @State private var progressions = AppliedProgressions()

    var body: some View {
        List {
            header
            ForEach(Array(WorkoutLog.orderedExercises(of: workout).enumerated()), id: \.element.id)
            {
                e, workoutExercise in
                if isEditing {
                    ExerciseSection(
                        workoutExercise: workoutExercise, exerciseIndex: e, workout: workout,
                        focusedRepsSetID: $focusedRepsSetID, deleteCount: $deleteCount,
                        progressions: $progressions, onRemove: remove, onAllSetsDone: {},
                        isEditingPast: true)
                } else {
                    readOnlySection(workoutExercise, e)
                }
            }
            if isEditing {
                Section {
                    Button("Add Exercise", systemImage: "plus") { isPickingExercise = true }
                        .accessibilityIdentifier("workout.addExercise")
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
        .toolbar { toolbar }
        .deleteWorkoutDialog(item: $workoutToDelete) { _ in
            isDeleted = true
            dismiss()
        }
        .confirmationDialog(
            "Remove this exercise?", item: $exerciseToRemove, titleVisibility: .visible
        ) { workoutExercise in
            Button("Remove Exercise", role: .destructive) { removeExercise(workoutExercise) }
                .accessibilityIdentifier(
                    "workout.exercise.\(WorkoutLog.orderedExercises(of: workout).firstIndex(of: workoutExercise) ?? 0).removeConfirm"
                )
        } message: { _ in
            Text("Its sets will be deleted.")
        }
        .sheet(isPresented: $isPickingExercise) {
            ExercisePicker { exercise in
                withAnimation(reduceMotion ? nil : .default) {
                    do {
                        try WorkoutLog(context: modelContext)
                            .addExercise(exercise, to: workout, completed: true)
                    } catch {
                        saveFailed = true
                    }
                }
            }
        }
        .sheet(isPresented: $isReordering) {
            ReorderSheet(
                items: WorkoutLog.orderedExercises(of: workout),
                name: { $0.exercise?.name ?? "Exercise" }
            ) { try WorkoutLog(context: modelContext).reorderExercises($0) }
            .interactiveDismissDisabled()
        }
        .saveFailedAlert(isPresented: $saveFailed)
        .onChange(of: workout.title) { saveTitle() }
        .onDisappear {
            // Deleted only once the screen is gone, so nothing renders a deleted workout.
            // shortcut: a failed save here has no screen left to alert on; delete rolls back, so the
            // workout stays in History. Alert there if this ever fails in practice.
            if isDeleted { try? WorkoutLog(context: modelContext).discard(workout) }
        }
    }

    @ViewBuilder
    private var header: some View {
        Section {
            if isEditing {
                TextField("Title", text: $workout.title)
                    .font(.title2.bold())
                    .accessibilityIdentifier("historyDetail.titleField")
            } else {
                Text(workout.title)
                    .font(.title2.bold())
                    .accessibilityIdentifier("historyDetail.title")
            }
            Text(WorkoutHistory.dateTimeText(of: workout))
            if let duration = WorkoutHistory.durationText(of: workout) {
                Text(duration).fontDesign(.rounded).monospacedDigit()
            }
            if let score = workout.format.score {
                LabeledContent("Score") {
                    Text(score.text).fontDesign(.rounded).monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Score")
                .accessibilityValue(score.spokenText)
                .accessibilityIdentifier("historyDetail.score")
            }
        }
    }

    private func readOnlySection(_ workoutExercise: WorkoutExercise, _ e: Int) -> some View {
        Section(workoutExercise.exercise?.name ?? "Exercise") {
            let sets = WorkoutLog.orderedSets(of: workoutExercise)
            let labels = SetNumbering.labels(for: sets.map(\.setType))
            ForEach(Array(sets.enumerated()), id: \.element.id) { s, set in
                HStack {
                    Text(labels[s]).foregroundStyle(.secondary).frame(
                        width: 28, alignment: .leading)
                    Text(set.values.text)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Set \(labels[s])")
                .accessibilityValue(set.values.spokenText)
                .accessibilityIdentifier("historyDetail.exercise.\(e).set.\(s)")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { finishEditing() }
                    .disabled(!PastWorkoutEditing.canFinishEditing(workout))
                    .accessibilityIdentifier("historyDetail.done")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Reorder", systemImage: "arrow.up.arrow.down") { isReordering = true }
                    .disabled(!WorkoutLog.canReorder(workout))
                    .accessibilityIdentifier("workout.reorder")
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
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .accessibilityIdentifier("historyDetail.edit")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    workoutToDelete = workout
                }
                .accessibilityIdentifier("historyDetail.delete")
            }
        }
    }

    private func saveTitle() {
        do { try modelContext.saveOrRollBack() } catch { saveFailed = true }
    }

    private func finishEditing() {
        do {
            focusedRepsSetID = nil
            if try PastWorkoutEditing(context: modelContext).finishEditing(workout) {
                isEditing = false
            }
        } catch {
            saveFailed = true
        }
    }

    /// Removes at once, or asks first when the exercise has sets to lose.
    private func remove(_ workoutExercise: WorkoutExercise) {
        if WorkoutLog.needsRemovalConfirmation(workoutExercise) {
            exerciseToRemove = workoutExercise
        } else {
            removeExercise(workoutExercise)
        }
    }

    private func removeExercise(_ workoutExercise: WorkoutExercise) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try WorkoutLog(context: modelContext).removeExercise(workoutExercise)
                deleteCount += 1
            } catch {
                saveFailed = true
            }
        }
    }
}
