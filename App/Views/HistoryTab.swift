import SwiftData
import SwiftUI

/// The finished workouts, newest first, each opening a read-only detail.
struct HistoryTab: View {
    @Query(WorkoutHistory.finishedWorkouts) private var workouts: [Workout]

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
                    }
                }
            }
            .navigationTitle("History")
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

/// One finished workout, read-only: its title, date and duration, then each exercise with its sets.
struct HistoryDetail: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                Text(workout.title)
                    .font(.title2.bold())
                    .accessibilityIdentifier("historyDetail.title")
                Text(WorkoutHistory.dateTimeText(of: workout))
                if let duration = WorkoutHistory.durationText(of: workout) {
                    Text(duration).fontDesign(.rounded).monospacedDigit()
                }
            }
            ForEach(Array(WorkoutLog.orderedExercises(of: workout).enumerated()), id: \.element.id)
            {
                e, workoutExercise in
                Section(workoutExercise.exercise?.name ?? "Exercise") {
                    let sets = WorkoutLog.orderedSets(of: workoutExercise)
                    let labels = SetNumbering.labels(for: sets.map(\.setType))
                    ForEach(Array(sets.enumerated()), id: \.element.id) { s, set in
                        HStack {
                            Text(labels[s]).foregroundStyle(.secondary).frame(
                                width: 28, alignment: .leading)
                            Text(set.values.text)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Set \(labels[s])")
                        .accessibilityValue(set.values.spokenText)
                        .accessibilityIdentifier("historyDetail.exercise.\(e).set.\(s)")
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
