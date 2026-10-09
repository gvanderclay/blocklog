import SwiftData
import SwiftUI

/// A routine's exercises with their plans, such as "3 × 8–12", plus Start Workout and Edit.
struct RoutineDetail: View {
    let routine: Routine
    /// Shows the started workout, with its progressions, in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var isEditing = false
    @State private var saveFailed = false

    var body: some View {
        List {
            Section {
                ForEach(RoutineLibrary.orderedExercises(of: routine).enumerated(), id: \.element.id)
                {
                    index, routineExercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routineExercise.exercise?.name ?? "Exercise")
                        Text(RoutineLibrary.summary(of: routineExercise))
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(RoutineLibrary.spokenSummary(of: routineExercise))
                            .accessibilityIdentifier("routineDetail.exercise.\(index).summary")
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                Button("Start Workout") { start() }
                    .disabled(!inProgressWorkouts.isEmpty)
                    .accessibilityIdentifier("routineDetail.start")
            } footer: {
                if !inProgressWorkouts.isEmpty {
                    Text("Finish or discard the workout in progress first.")
                }
            }
        }
        .navigationTitle(routine.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .accessibilityIdentifier("routineDetail.edit")
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineEditor(routine: routine)
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private func start() {
        do {
            if let started = try RoutineStart(context: modelContext).startWorkout(from: routine) {
                present(started)
            }
        } catch {
            saveFailed = true
        }
    }
}
