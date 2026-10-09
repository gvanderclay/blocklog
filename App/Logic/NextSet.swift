import Foundation

/// The set the user does after a checked-off one, and the block change between their weights.
@MainActor
enum NextSet {
    /// The first unchecked set after `set` in its exercise; failing that, the first unchecked set in a
    /// later exercise by position. Never looks back, and is nil when none is left.
    static func after(_ set: WorkoutSet) -> WorkoutSet? {
        guard let workoutExercise = set.workoutExercise else { return nil }
        let laterSets = WorkoutLog.orderedSets(of: workoutExercise).filter {
            $0.position > set.position && !$0.isCompleted
        }
        if let next = laterSets.first { return next }
        guard let workout = workoutExercise.workout else { return nil }
        return WorkoutLog.orderedExercises(of: workout)
            .filter { $0.position > workoutExercise.position }
            .lazy
            .compactMap { WorkoutLog.orderedSets(of: $0).first { !$0.isCompleted } }
            .first
    }

    /// The two weights the rest's change hint compares; nil when there is no next set or either has no weight.
    static func weights(after set: WorkoutSet) -> (now: Double, next: Double)? {
        guard let now = set.weight, let next = after(set)?.weight else { return nil }
        return (now, next)
    }

    /// What to change on the block for the next set, such as "Pin 30 → 40 · remove 1 adder"; nil when
    /// there is nothing to change.
    static func changeLine(after set: WorkoutSet) -> String? {
        weights(after: set).flatMap { PowerBlockTable.changeLine(from: $0.now, to: $0.next) }
    }
}
