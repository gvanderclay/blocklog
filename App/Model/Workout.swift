import Foundation
import SwiftData

/// One workout, done or in progress. A workout with no end date is the in-progress workout.
@Model
final class Workout {
    var id: UUID
    var title: String
    var startDate: Date
    /// Nil while the workout is in progress.
    var endDate: Date?
    /// The routine the workout started from; nil for a freeform workout. Deleting the routine nullifies it.
    var routine: Routine?
    /// How the workout was played, with the AMRAP score fields; read all three through `format`. Nil is Sets.
    var formatRawValue: String?
    /// A Timed AMRAP workout's completed rounds; nil for any other format.
    var amrapRounds: Int?
    /// A Timed AMRAP workout's reps in the unfinished round; nil for any other format.
    var amrapExtraReps: Int?

    /// Unordered: sort by `position`.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(
        id: UUID = UUID(), title: String, startDate: Date, endDate: Date? = nil,
        routine: Routine? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.routine = routine
    }
}
