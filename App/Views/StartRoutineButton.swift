import SwiftData
import SwiftUI

/// Starts a workout from a routine, disabled while another workout is in progress.
struct StartRoutineButton: View {
    let routine: Routine
    /// Shows the started workout, with its progressions, in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var saveFailed = false

    var body: some View {
        Button("Start") {
            do {
                if let started = try RoutineStart(context: modelContext).startWorkout(
                    from: routine)
                {
                    present(started)
                }
            } catch {
                saveFailed = true
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Start \(routine.name)")
        .disabled(!inProgressWorkouts.isEmpty)
        .saveFailedAlert(isPresented: $saveFailed)
    }
}
