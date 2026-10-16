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
    @AccessibilityFocusState private var accessibilityFocusedSetID: UUID?
    /// The set shown open. View state only: a reopened screen recomputes it with `NextSet.current`.
    @State private var openSetID: UUID?
    @State private var listBottomInset: CGFloat = 0
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
    /// Held here too, so a scrolled-away row can't drop the cover.
    @State private var stopwatch: Stopwatch?
    /// shortcut: lost when the screen closes (Minimize); hold it with the progressions if that bites.
    @State private var stopwatchGoals = StopwatchGoals()
    /// Set when Stop checks off the last unchecked set; "All sets done" waits until the stopwatch has closed.
    @State private var offersFinishAfterStopwatch = false

    init(workout: Workout, progressions: Binding<AppliedProgressions>) {
        self.workout = workout
        _progressions = progressions
        _openSetID = State(initialValue: NextSet.current(in: workout)?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                list
                    // No anchor: the list scrolls only as far as the set needs to be wholly visible.
                    .onChange(of: openSetID) { _, id in scroll(to: id, with: proxy) }
                    .onAppear { scroll(to: openSetID, with: proxy) }
                    // The rest bar a check-off adds, or the keyboard, covers more of the list: keep the open set
                    // in view. Not on shrinking, so the rest ending never moves the list. On the next turn, because
                    // the list applies its new inset only after this update.
                    .onChange(of: listBottomInset) { old, new in
                        if new > old { Task { scroll(to: openSetID, with: proxy) } }
                    }
            }
            // Behind the list, so the strip a falling keyboard exposes shows the grouped grey, not window white.
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
            .toolbar { toolbar }
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
                            openSetID = try WorkoutLog(context: modelContext)
                                .addExercise(exercise, to: workout).id
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
        // Under the stopwatch cover, the list stays in the accessibility tree; hide it while it shows.
        .accessibilityHidden(stopwatch != nil)
        .fullScreenCover(
            item: $stopwatch,
            onDismiss: {
                if offersFinishAfterStopwatch {
                    offersFinishAfterStopwatch = false
                    isOfferingFinish = true
                }
            }
        ) { stopwatch in
            StopwatchScreen(stopwatch: stopwatch) { seconds in
                try logStopwatch(seconds, of: stopwatch)
            }
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

    private func scroll(to id: UUID?, with proxy: ScrollViewProxy) {
        guard let id else { return }
        withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(id) }
    }

    private var list: some View {
        List {
            ForEach(WorkoutLog.orderedExercises(of: workout).enumerated(), id: \.element.id) {
                index, workoutExercise in
                ExerciseSection(
                    workoutExercise: workoutExercise, exerciseIndex: index,
                    workout: workout, focusedRepsSetID: $focusedRepsSetID,
                    openSetID: $openSetID, accessibilityFocus: $accessibilityFocusedSetID,
                    deleteCount: $deleteCount, progressions: $progressions, onRemove: remove,
                    onAllSetsDone: { isOfferingFinish = true }, onStartStopwatch: startStopwatch)
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
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.bottom) { listBottomInset = $0 }
        .background {
            // Holds the keyboard while a check-off swaps the open set's field (SetRow.keyboardHolderID).
            TextField("", text: .constant(""))
                .keyboardType(.numberPad)
                .focused($focusedRepsSetID, equals: SetRow.keyboardHolderID)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .accessibilityIdentifier("workout.keyboardHolder")
        }
        .safeAreaInset(edge: .bottom) {
            if restTimer.isRunning {
                // Hidden once Finish is tapped: the keyboard drops as the sheet rises, and the bar would ride it
                // down across the list.
                RestTimerBar()
                    .opacity(isFinishing ? 0 : 1)
                    // Move only: the bar's material doesn't fade with opacity, so it left before its contents did.
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? nil : .default, value: restTimer.isRunning)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Minimize", systemImage: "chevron.down") { dismiss() }
                .accessibilityIdentifier("workout.minimize")
        }
        ToolbarItem(placement: .principal) {
            Text(workout.startDate, style: .timer)
                .font(.headline)
                .fontDesign(.rounded)
                .monospacedDigit()
                // The ticking time is the value, not the label, as in the resume row.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(Text(workout.startDate, style: .timer))
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
    }

    /// Play: puts the keyboard down, ends a running rest (as Skip does) and opens the stopwatch.
    private func startStopwatch(for set: WorkoutSet) {
        focusedRepsSetID = nil
        restTimer.skip()
        stopwatch = stopwatchGoals.stopwatch(
            for: set, placeholder: SetPlaceholder(context: modelContext).value(for: set))
    }

    /// Stop: logs the seconds and checks the set off, which starts the rest, then closes the stopwatch. Keyboard
    /// focus stays where it is. A failed save throws and leaves the stopwatch open, so the run isn't lost.
    private func logStopwatch(_ seconds: Int, of stopwatch: Stopwatch) throws {
        let outcome = try WorkoutLog(context: modelContext, restTimer: restTimer)
            .logStopwatch(
                seconds: seconds, of: stopwatch.set, in: workout, defaultRest: defaultRest)
        stopwatchGoals.logged(stopwatch)
        withAnimation(reduceMotion ? nil : .default) {
            switch outcome {
            case .open(let next): openSetID = next?.id
            case .allSetsDone:
                openSetID = nil
                offersFinishAfterStopwatch = true
            case .missingValue: break
            }
        }
        self.stopwatch = nil
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
        let removedIDs = workoutExercise.sets.map(\.id)
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try WorkoutLog(context: modelContext).removeExercise(workoutExercise)
                deleteCount += 1
                if let openSetID, removedIDs.contains(openSetID) {
                    self.openSetID = NextSet.current(in: workout)?.id
                }
            } catch {
                saveFailed = true
            }
        }
    }
}

/// One workout exercise: its sets and an Add Set button. Also the editing mode of a past workout's detail.
struct ExerciseSection: View {
    let workoutExercise: WorkoutExercise
    let exerciseIndex: Int
    let workout: Workout
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// The set shown open; Add Set opens the set it adds.
    @Binding var openSetID: UUID?
    let accessibilityFocus: AccessibilityFocusState<UUID?>.Binding
    /// Bumped on every deletion, so the screen plays the delete haptic.
    @Binding var deleteCount: Int
    @Binding var progressions: AppliedProgressions
    let onRemove: (WorkoutExercise) -> Void
    let onAllSetsDone: () -> Void
    /// Opens the stopwatch for a set; nil in past editing.
    var onStartStopwatch: ((WorkoutSet) -> Void)?
    /// True when the section edits a finished workout: sets are completed, with no check-off control.
    var isEditingPast = false

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
                    focusedRepsSetID: focusedRepsSetID, openSetID: $openSetID,
                    accessibilityFocus: accessibilityFocus, workout: workout,
                    progressions: $progressions, onDelete: { deleteCount += 1 },
                    onAllSetsDone: onAllSetsDone, isEditingPast: isEditingPast,
                    onStartStopwatch: isEditingPast ? nil : onStartStopwatch)
            }
            Button("Add Set", systemImage: "plus") {
                withAnimation(reduceMotion ? nil : .default) {
                    do {
                        let added = try WorkoutLog(context: modelContext)
                            .addSet(to: workoutExercise, completed: isEditingPast)
                        if NextSet.opensAddedSet(added) { openSetID = added.id }
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
