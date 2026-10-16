import SwiftData
import SwiftUI

/// Starts an empty workout or one from a routine, resumes the one in progress, lists the routines (or, with
/// none, suggests starter routines) and opens the starter routines.
struct WorkoutTab: View {
    /// Shows a workout in the full-screen workout screen.
    let present: (Workout) -> Void
    /// Shows a workout started from a routine, with the progressions applied to it.
    let presentStarted: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @Query(ProgramLibrary.myRoutines) private var routines: [Routine]
    @Query(ProgramLibrary.programsByName) private var programs: [Program]
    @State private var saveFailed = false
    @State private var isCreatingRoutine = false
    @State private var isCreatingProgram = false
    @State private var newProgramName = ""
    @State private var routineToDelete: Routine?
    @State private var programToDelete: Program?
    @State private var isShowingStarterRoutines = false
    /// A workout started from the Starter Routines sheet, shown over the sheet.
    @State private var startedFromStarterRoutines: Workout?
    @State private var starterProgressions = AppliedProgressions()

    private var isFirstRun: Bool { routines.isEmpty && programs.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                if let workout = inProgressWorkouts.first {
                    Section("In Progress") {
                        Button {
                            present(workout)
                        } label: {
                            ResumeRow(title: workout.title, startDate: workout.startDate)
                        }
                        .accessibilityIdentifier("workoutTab.resume")
                    }
                }
                Section {
                    Button("Start Empty Workout", systemImage: "plus") {
                        do {
                            if let workout = try WorkoutLog(context: modelContext)
                                .startEmptyWorkout()
                            {
                                present(workout)
                            }
                        } catch {
                            saveFailed = true
                        }
                    }
                    .disabled(!inProgressWorkouts.isEmpty)
                    .accessibilityIdentifier("workoutTab.startEmpty")
                }
                Section {
                    ForEach(programs.enumerated(), id: \.element.id) { index, program in
                        ProgramRow(program: program, index: index, present: presentStarted)
                            .swipeActions(edge: .trailing) {
                                // No destructive role: with it the list removes the row before the user confirms.
                                Button("Delete", systemImage: "trash") {
                                    programToDelete = program
                                }
                                .tint(.red)
                                .accessibilityIdentifier("workoutTab.program.\(index).delete")
                            }
                            // On the row, so the dialog appears by it rather than at the top of the list.
                            .confirmationDialog(
                                "Delete this program?",
                                isPresented: Binding(
                                    get: { programToDelete === program },
                                    set: { if !$0 { programToDelete = nil } }),
                                titleVisibility: .visible
                            ) {
                                Button("Delete Program", role: .destructive) { delete(program) }
                                    .accessibilityIdentifier("workoutTab.deleteProgramConfirm")
                            } message: {
                                Text("Its routines move to My Routines.")
                            }
                    }
                    Button("New Program", systemImage: "plus") {
                        newProgramName = ""
                        isCreatingProgram = true
                    }
                    .accessibilityIdentifier("workoutTab.newProgram")
                } header: {
                    Text("Programs")
                } footer: {
                    Text(
                        "A program is a list of routines you rotate through, such as Push, Pull, Legs."
                    )
                }
                if isFirstRun {
                    Section("Starter Routines") {
                        ForEach(StarterRoutine.suggestions(in: StarterRoutine.bundled)) {
                            starterRoutine in
                            StarterRoutineLink(
                                starterRoutine: starterRoutine, present: presentStarted
                            )
                            .accessibilityIdentifier(
                                "workoutTab.suggestedStarterRoutine.\(starterRoutine.name)")
                        }
                    }
                }
                Section {
                    ForEach(routines) { routine in
                        RoutineLink(routine: routine)
                            .accessibilityIdentifier("workoutTab.routine.\(routine.name)")
                            .swipeActions(edge: .trailing) {
                                // No destructive role: with it the list removes the row before the user confirms.
                                Button("Delete", systemImage: "trash") { routineToDelete = routine }
                                    .tint(.red)
                                    .accessibilityIdentifier(
                                        "workoutTab.routine.\(routine.name).delete")
                            }
                            // On the row, so the dialog appears by it rather than at the top of the list.
                            .confirmationDialog(
                                "Delete this routine?",
                                isPresented: Binding(
                                    get: { routineToDelete === routine },
                                    set: { if !$0 { routineToDelete = nil } }),
                                titleVisibility: .visible
                            ) {
                                Button("Delete Routine", role: .destructive) { delete(routine) }
                                    .accessibilityIdentifier("workoutTab.deleteRoutineConfirm")
                            } message: {
                                Text("Workouts started from it are kept.")
                            }
                    }
                    Button("New Routine", systemImage: "plus") { isCreatingRoutine = true }
                        .accessibilityIdentifier("workoutTab.newRoutine")
                    Button("Starter Routines", systemImage: "rectangle.stack") {
                        isShowingStarterRoutines = true
                    }
                    .accessibilityIdentifier("workoutTab.starterRoutines")
                } header: {
                    Text("My Routines")
                } footer: {
                    if isFirstRun {
                        Text("No routines yet. Try a starter routine, or make your own.")
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: Program.self) { program in
                ProgramDetail(program: program, present: presentStarted)
            }
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetail(routine: routine, present: presentStarted)
            }
            .sheet(isPresented: $isCreatingRoutine) {
                RoutineEditor(routine: nil)
            }
            .sheet(isPresented: $isShowingStarterRoutines) {
                StarterRoutinesSheet { started in
                    starterProgressions = started.progressions
                    startedFromStarterRoutines = started.workout
                }
                // The root cover can't rise while this sheet is up (SwiftUI would first dismiss the sheet and show
                // the tab for half a second), so the workout covers the sheet where it stands. The sheet is
                // invisible from then on, and closes without animation once the workout has gone.
                .fullScreenCover(
                    item: $startedFromStarterRoutines, onDismiss: closeStarterRoutines
                ) { workout in
                    WorkoutScreen(workout: workout, progressions: $starterProgressions)
                }
                .opacity(startedFromStarterRoutines == nil ? 1 : 0)
                .animation(reduceMotion ? nil : .default, value: startedFromStarterRoutines == nil)
                .accessibilityHidden(startedFromStarterRoutines != nil)
                .presentationBackground {
                    Color(.systemGroupedBackground)
                        .opacity(startedFromStarterRoutines == nil ? 1 : 0)
                }
            }
            .alert("New Program", isPresented: $isCreatingProgram) {
                TextField("Name", text: $newProgramName)
                    .accessibilityIdentifier("workoutTab.newProgramName")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("workoutTab.newProgramCancel")
                Button("Create") { createProgram() }
                    .accessibilityIdentifier("workoutTab.newProgramCreate")
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
    }
}

extension WorkoutTab {
    private func closeStarterRoutines() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isShowingStarterRoutines = false }
    }

    private func createProgram() {
        do {
            try ProgramLibrary(context: modelContext).create(named: newProgramName)
        } catch {
            saveFailed = true
        }
    }

    private func delete(_ program: Program) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try ProgramLibrary(context: modelContext).delete(program)
            } catch {
                saveFailed = true
            }
        }
    }

    private func delete(_ routine: Routine) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try RoutineLibrary(context: modelContext).delete(routine)
            } catch {
                saveFailed = true
            }
        }
    }
}

/// The in-progress workout's title and elapsed time.
private struct ResumeRow: View {
    let title: String
    let startDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(startDate, style: .timer)
                .font(.subheadline)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        // The ticking time is the value, not the label, so the element's name stays steady.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text(startDate, style: .timer))
        .accessibilityHint("Resumes the workout")
    }
}

/// A program's name and "Up next: <routine>", with a Start button for that routine. A tap opens the program.
private struct ProgramRow: View {
    let program: Program
    let index: Int
    let present: (RoutineStart.Started) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let upNext = ProgramLibrary.upNext(in: program)
        // Start sits beside the link, not inside it, so it stays its own accessibility element. At accessibility
        // sizes it drops below the text, which keeps the whole row width.
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        layout {
            NavigationLink(value: program) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name)
                    Text(upNext.map { "Up next: \($0.name)" } ?? "No routines yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("workoutTab.program.\(index).upNext")
                }
            }
            .accessibilityIdentifier("workoutTab.program.\(index)")
            if let upNext {
                StartRoutineButton(routine: upNext, present: present)
                    .accessibilityIdentifier("workoutTab.program.\(index).start")
            }
        }
    }
}
