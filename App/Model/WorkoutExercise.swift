import Foundation
import SwiftData

/// One exercise inside one workout, with its sets.
@Model
final class WorkoutExercise {
    var id: UUID
    var position: Int
    var exercise: Exercise?
    var workout: Workout?

    /// Unordered: sort by `position`.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet] = []

    init(id: UUID = UUID(), exercise: Exercise, position: Int) {
        self.id = id
        self.exercise = exercise
        self.position = position
    }
}
