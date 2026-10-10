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
    @Query(ProgrammeLibrary.myRoutines) private var routines: [Routine]
    @Query(ProgrammeLibrary.programmesByName) private var programmes: [Programme]
    @State private var saveFailed = false
    @State private var isCreatingRoutine = false
    @State private var isCreatingProgramme = false
    @State private var newProgrammeName = ""
    @State private var routineToDelete: Routine?
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
                Section("Programmes") {
                    ForEach(programmes.enumerated(), id: \.element.id) { index, programme in
                        ProgrammeRow(programme: programme, index: index, present: presentStarted)
                    }
                    Button("New Programme", systemImage: "plus") {
                        newProgrammeName = ""
                        isCreatingProgramme = true
                    }
                    .accessibilityIdentifier("workoutTab.newProgramme")
                }
                Section {
                    if routines.isEmpty && programmes.isEmpty {
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
                    if routines.isEmpty && programmes.isEmpty {
                        Text("No routines yet. Try a starter routine, or make your own.")
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: Programme.self) { programme in
                ProgrammeDetail(programme: programme, present: presentStarted)
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
            .confirmationDialog(
                "Delete this routine?", item: $routineToDelete, titleVisibility: .visible
            ) { routine in
                Button("Delete Routine", role: .destructive) { delete(routine) }
                    .accessibilityIdentifier("workoutTab.deleteRoutineConfirm")
            } message: { _ in
                Text("Workouts started from it are kept.")
            }
            .alert("New Programme", isPresented: $isCreatingProgramme) {
                TextField("Name", text: $newProgrammeName)
                    .accessibilityIdentifier("workoutTab.newProgrammeName")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("workoutTab.newProgrammeCancel")
                Button("Create") { createProgramme() }
                    .accessibilityIdentifier("workoutTab.newProgrammeCreate")
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

    private func createProgramme() {
        do {
            try ProgrammeLibrary(context: modelContext).create(named: newProgrammeName)
        } catch {
            saveFailed = true
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

/// A programme's name and "Up next: <routine>", with a Start button for that routine. A tap opens the programme.
private struct ProgrammeRow: View {
    let programme: Programme
    let index: Int
    let present: (RoutineStart.Started) -> Void

    var body: some View {
        let upNext = ProgrammeLibrary.upNext(in: programme)
        // Start sits beside the link, not inside it, so it stays its own accessibility element.
        HStack {
            NavigationLink(value: programme) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(programme.name)
                    Text(upNext.map { "Up next: \($0.name)" } ?? "No routines yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("workoutTab.programme.\(index).upNext")
                }
            }
            .accessibilityIdentifier("workoutTab.programme.\(index)")
            if let upNext {
                StartRoutineButton(routine: upNext, present: present)
                    .accessibilityIdentifier("workoutTab.programme.\(index).start")
            }
        }
    }
}
