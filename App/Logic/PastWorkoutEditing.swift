import Foundation
import SwiftData

/// The rules for editing a finished workout in History. Every set of a past workout counts as done, so a set
/// is valid when it has its exercise type's required values, and Done is allowed once every set is valid.
@MainActor
struct PastWorkoutEditing {
    let context: ModelContext

    /// A set is valid when it has its type's required values: reps for the rep types, seconds above 0 for
    /// duration. (A weight × reps set always has a weight.)
    static func isValid(_ set: WorkoutSet) -> Bool {
        set.values.canCheckOff
    }

    /// What an invalid set is missing: "Add reps", or "Add a duration" for a duration set. Nil for a valid set.
    static func hint(for set: WorkoutSet) -> String? {
        guard !isValid(set) else { return nil }
        if case .duration = set.values { return "Add a duration" }
        return "Add reps"
    }

    /// Whether Done is enabled: no set in the workout is invalid.
    static func canFinishEditing(_ workout: Workout) -> Bool {
        workout.exercises.allSatisfy { $0.sets.allSatisfy(isValid) }
    }

    /// Saves a changed set. The set stays completed even when its reps or seconds were cleared, because every
    /// set of a past workout counts as done; it is just invalid until filled in.
    func saveEdit(of set: WorkoutSet) throws {
        set.isCompleted = true
        try context.saveOrRollBack()
    }

    /// Leaves editing: tidies the workout as finishing one does (`WorkoutLog.tidy`) and saves. Returns false, changing nothing, while a
    /// set is invalid. A failed save rolls back and throws.
    func finishEditing(_ workout: Workout) throws -> Bool {
        guard Self.canFinishEditing(workout) else { return false }
        WorkoutLog(context: context).tidy(workout, title: workout.title)
        try context.saveOrRollBack()
        return true
    }
}
