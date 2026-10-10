import SwiftData
import SwiftUI

/// Starts a routine, disabled while another workout is in progress: a Sets routine as a workout, a Stretch routine
/// in the stretch player for one round. A Timed AMRAP routine shows no button until its player exists.
struct StartRoutineButton: View {
    let routine: Routine
    /// Shows the started workout, with its progressions, in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var player: StretchPlayer?
    @State private var saveFailed = false

    var body: some View {
        switch routine.format {
        case .sets, .stretch:
            Button("Start") { start() }
                .buttonStyle(.borderless)
                .accessibilityLabel("Start \(routine.name)")
                .disabled(!inProgressWorkouts.isEmpty)
                .saveFailedAlert(isPresented: $saveFailed)
                .fullScreenCover(item: $player) { StretchPlayerScreen(player: $0) }
        case .timedAMRAP:
            EmptyView()
        }
    }

    private func start() {
        if routine.format == .stretch {
            player = StretchPlayer.start(
                routine, rounds: StretchPlayer.roundChoices.lowerBound, in: modelContext)
            return
        }
        do {
            if let started = try RoutineStart(context: modelContext).startWorkout(from: routine) {
                present(started)
            }
        } catch {
            saveFailed = true
        }
    }
}
