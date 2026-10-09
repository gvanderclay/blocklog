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
    @Query(RoutineLibrary.routinesByName) private var routines: [Routine]
    @State private var saveFailed = false
    @State private var isCreatingRoutine = false
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
                Section {
                    if routines.isEmpty {
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
                        NavigationLink(routine.name, value: routine)
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
                    Text("Routines")
                } footer: {
                    if routines.isEmpty {
                        Text("No routines yet. Try a starter routine, or make your own.")
                    }
                }
            }
            .navigationTitle("Workout")
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Resumes the workout")
    }
}
