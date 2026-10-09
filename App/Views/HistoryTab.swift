import SwiftData
import SwiftUI

/// The finished workouts, newest first, each opening a detail that can be edited.
struct HistoryTab: View {
    @Query(WorkoutHistory.finishedWorkouts) private var workouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @State private var workoutToDelete: Workout?
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet", systemImage: "clock.arrow.circlepath",
                        description: Text("Finished workouts show up here."))
                } else {
                    List(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink {
                            HistoryDetail(workout: workout)
                        } label: {
                            row(workout)
                        }
                        .accessibilityIdentifier("history.row.\(index)")
                        // Tinted, not destructive: the role would remove the row before the confirmation.
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash") { workoutToDelete = workout }
                                .tint(.red)
                                .accessibilityIdentifier("history.row.\(index).delete")
                        }
                    }
                }
            }
            .navigationTitle("History")
            .deleteWorkoutDialog(item: $workoutToDelete) { workout in
                do {
                    try WorkoutLog(context: modelContext).discard(workout)
                } catch {
                    saveFailed = true
                }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
    }

    private func row(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WorkoutHistory.rowTitle(of: workout)).font(.headline)
            Text(
                [
                    WorkoutHistory.dateText(of: workout), WorkoutHistory.durationText(of: workout),
                    WorkoutHistory.exerciseCountText(of: workout),
                ].compactMap { $0 }.joined(separator: " · ")
            )
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
