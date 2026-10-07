import SwiftData
import SwiftUI

/// Starts an empty workout, or resumes the one in progress.
struct WorkoutTab: View {
    /// Shows a workout in the full-screen workout screen.
    let present: (Workout) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.endDate == nil }) private var inProgressWorkouts:
        [Workout]
    @State private var saveFailed = false

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
            }
            .navigationTitle("Workout")
            .saveFailedAlert(isPresented: $saveFailed)
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
