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
    /// A workout started from the Starter Routines sheet, shown once the sheet has closed.
    @State private var startedFromStarterRoutines: RoutineStart.Started?

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
                Section("Programs") {
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
                }
                Section {
                    if routines.isEmpty && programs.isEmpty {
                        ForEach(StarterRoutine.suggestions(in: StarterRoutine.bundled)) {
                            starterRoutine in
                            StarterRoutineLink(
                                starterRoutine: starterRoutine, present: presentStarted
                            )
                            .accessibilityIdentifier(
                                "workoutTab.suggestedStarterRoutine.\(starterRoutine.name)")
                        }
                    }
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
                    if routines.isEmpty && programs.isEmpty {
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
            .sheet(
                isPresented: $isShowingStarterRoutines, onDismiss: presentStartedFromStarterRoutines
            ) {
                StarterRoutinesSheet { started in
                    // The workout screen can't cover the tab while this sheet is up.
                    startedFromStarterRoutines = started
                    isShowingStarterRoutines = false
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
    private func presentStartedFromStarterRoutines() {
        guard let started = startedFromStarterRoutines else { return }
        startedFromStarterRoutines = nil
        presentStarted(started)
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

    var body: some View {
        let upNext = ProgramLibrary.upNext(in: program)
        // Start sits beside the link, not inside it, so it stays its own accessibility element.
        HStack {
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
