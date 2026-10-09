import SwiftData
import SwiftUI

/// The in-progress workout: its exercises and sets, presented full screen.
struct WorkoutScreen: View {
    let workout: Workout
    /// What progression applied when the workout started; the screen shows it and ends highlights.
    @Binding var progressions: AppliedProgressions

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(RestTimer.self) private var restTimer
    @AppStorage("defaultRestSeconds") private var defaultRest = 90
    @FocusState private var focusedRepsSetID: UUID?
    @State private var isPickingExercise = false
    @State private var isReordering = false
    @State private var deleteCount = 0
    @State private var isFinishing = false
    @State private var isConfirmingDiscard = false
    @State private var isOfferingFinish = false
    @State private var isDiscarded = false
    @State private var saveFailed = false
    /// Held here, not on the section header, so the dialog shows however far the list has scrolled.
    @State private var exerciseToRemove: WorkoutExercise?

    var body: some View {
        NavigationStack {
            List {
                ForEach(WorkoutLog.orderedExercises(of: workout).enumerated(), id: \.element.id) {
                    index, workoutExercise in
                    ExerciseSection(
                        workoutExercise: workoutExercise, exerciseIndex: index,
                        workout: workout, focusedRepsSetID: $focusedRepsSetID,
                        deleteCount: $deleteCount, progressions: $progressions, onRemove: remove,
                        onAllSetsDone: { isOfferingFinish = true })
                }
                Section {
                    Button("Add Exercise", systemImage: "plus") { isPickingExercise = true }
                        .accessibilityIdentifier("workout.addExercise")
                }
                Section {
                    Button("Discard Workout", role: .destructive) { isConfirmingDiscard = true }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("workout.discardBottom")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if restTimer.isRunning {
                    RestTimerBar()
                        .transition(
                            reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: restTimer.isRunning)
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
                    Button("Done") { checkOffFocusedSet() }
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
            .confirmationDialog(
                "All sets done", isPresented: $isOfferingFinish, titleVisibility: .visible
            ) {
                Button("Finish") { isFinishing = true }
                    .accessibilityIdentifier("allSetsDone.finish")
                Button("Keep Going", role: .cancel) {}
                    .accessibilityIdentifier("allSetsDone.keepGoing")
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
                            try WorkoutLog(context: modelContext).addExercise(exercise, to: workout)
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
                try? WorkoutLog(context: modelContext, restTimer: restTimer).discard(workout)
            }
        }
    }

    /// Removes at once, or asks first when the exercise has a checked set.
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

    /// Keyboard Done: checks off the focused set and moves on like Next; closes the keyboard when it can't.
    private func checkOffFocusedSet() {
        guard let id = focusedRepsSetID,
            let set = WorkoutLog.orderedExercises(of: workout).flatMap(WorkoutLog.orderedSets(of:))
                .first(where: { $0.id == id })
        else {
            focusedRepsSetID = nil
            return
        }
        withAnimation(reduceMotion ? nil : .default) {
            do {
                switch try WorkoutLog(context: modelContext, restTimer: restTimer)
                    .checkOff(set, in: workout, defaultRest: defaultRest)
                {
                case .focus(let next):
                    focusedRepsSetID = next?.id
                case .allSetsDone:
                    focusedRepsSetID = nil
                    isOfferingFinish = true
                }
            } catch {
                saveFailed = true
            }
        }
    }
}

/// One workout exercise: its sets and an Add Set button.
private struct ExerciseSection: View {
    let workoutExercise: WorkoutExercise
    let exerciseIndex: Int
    let workout: Workout
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// Bumped on every deletion, so the screen plays the delete haptic.
    @Binding var deleteCount: Int
    @Binding var progressions: AppliedProgressions
    let onRemove: (WorkoutExercise) -> Void
    let onAllSetsDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("defaultRestSeconds") private var defaultRest = 90
    @State private var saveFailed = false
    /// Flips once when the section first appears, so the progression arrow bounces once.
    @State private var arrowBounce = false

    var body: some View {
        Section {
            ForEach(WorkoutLog.orderedSets(of: workoutExercise).enumerated(), id: \.element.id) {
                setIndex, set in
                SetRow(
                    set: set,
                    identifierPrefix: "workout.exercise.\(exerciseIndex).set.\(setIndex)",
                    focusedRepsSetID: focusedRepsSetID, workout: workout,
                    progressions: $progressions, onDelete: { deleteCount += 1 },
                    onAllSetsDone: onAllSetsDone)
            }
            Button("Add Set", systemImage: "plus") {
                withAnimation(reduceMotion ? nil : .default) {
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
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                progressionNote
            }
        }
        .headerProminence(.increased)
    }

    /// The note under the name when progression applies; the arrow bounces once as the workout opens.
    @ViewBuilder
    private var progressionNote: some View {
        if let suggestion = progressions.note(for: workoutExercise) {
            HStack(spacing: 4) {
                if suggestion.showsArrow {
                    Image(systemName: "arrow.up.circle.fill")
                        .symbolEffect(.bounce, value: arrowBounce)
                        .symbolEffectsRemoved(reduceMotion)
                        .accessibilityHidden(true)
                }
                Text(suggestion.text)
            }
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .textCase(nil)
            .onAppear { arrowBounce = true }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("workout.exercise.\(exerciseIndex).progressionNote")
        }
    }

    private var headerRow: some View {
        HStack {
            Text(workoutExercise.exercise?.name ?? "Exercise")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workout.exercise.\(exerciseIndex).name")
            Spacer()
            Menu {
                if let exercise = workoutExercise.exercise {
                    // A submenu, so the 19 choices don't push Remove Exercise off the menu.
                    Menu("Rest Time…", systemImage: "timer") {
                        Picker("Rest Time", selection: restOverride(of: exercise)) {
                            Text("Default (\(RestTimer.clock(defaultRest)))").tag(Int?.none)
                            ForEach(RestTimer.choices, id: \.self) {
                                Text(RestTimer.clock($0)).tag(Int?.some($0))
                            }
                        }
                    }
                    .accessibilityIdentifier("workout.exercise.\(exerciseIndex).restTime")
                }
                Button("Remove Exercise", systemImage: "trash", role: .destructive) {
                    onRemove(workoutExercise)
                }
                .accessibilityIdentifier("workout.exercise.\(exerciseIndex).remove")
            } label: {
                // The 44 × 44 frame belongs on the label: a frame outside the menu leaves its tap target small.
                Label("Exercise Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("workout.exercise.\(exerciseIndex).menu")
        }
    }

    /// The exercise's rest override, saved when the picker changes it.
    private func restOverride(of exercise: Exercise) -> Binding<Int?> {
        Binding(
            get: { exercise.restOverrideSeconds },
            set: { seconds in
                do {
                    try WorkoutLog(context: modelContext).setRestOverride(seconds, of: exercise)
                } catch {
                    saveFailed = true
                }
            })
    }
}
