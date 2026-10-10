import Foundation
import SwiftData

/// A named plan a workout can start from. It stores structure, never weights.
@Model
final class Routine {
    var id: UUID
    var name: String
    var creationDate: Date
    /// The programme the routine belongs to, set together with `programmePosition`; read both through
    /// `membership`. Nil for a routine in My Routines.
    var programme: Programme?
    /// The routine's place in its programme, from 0.
    var programmePosition: Int?
    /// How the routine plays, with `timeCapSeconds`; read both through `format`. Nil is Sets.
    var formatRawValue: String?
    /// A Timed AMRAP routine's length; nil for any other format.
    var timeCapSeconds: Int?

    /// Unordered: sort by `position`.
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []
    /// Workouts started from this routine; deleting the routine keeps them and clears their link.
    @Relationship(deleteRule: .nullify, inverse: \Workout.routine)
    var workouts: [Workout] = []

    init(id: UUID = UUID(), name: String, creationDate: Date) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
}
