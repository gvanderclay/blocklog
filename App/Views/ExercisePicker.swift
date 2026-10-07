import SwiftData
import SwiftUI

/// The exercises a workout can add, sorted by name; tapping one adds it to the workout.
struct ExercisePicker: View {
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(WorkoutLog.addableExercises) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                Button(exercise.name) {
                    onPick(exercise)
                    dismiss()
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("exercisePicker.row.\(exercise.name)")
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("exercisePicker.cancel")
                }
            }
        }
    }
}
