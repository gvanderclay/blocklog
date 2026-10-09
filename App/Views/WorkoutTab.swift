import SwiftData
import SwiftUI

/// Starts an empty workout or one from a routine, resumes the one in progress, and lists the routines.
struct WorkoutTab: View {
    /// Shows a workout in the full-screen workout screen.
    let present: (Workout) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @Query(RoutineLibrary.routinesByName) private var routines: [Routine]
    @State private var saveFailed = false
    @State private var isCreatingRoutine = false
    @State private var routineToDelete: Routine?

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
                Section("Routines") {
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
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetail(routine: routine, present: present)
            }
            .sheet(isPresented: $isCreatingRoutine) {
                RoutineEditor(routine: nil)
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
