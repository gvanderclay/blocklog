import Foundation

/// The set the user does after a checked-off one, and the block change to it.
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

    /// The set the workout screen opens when it appears: the first unchecked set after the last checked one
    /// in workout order, else the first unchecked set; nil when every set is checked.
    static func current(in workout: Workout) -> WorkoutSet? {
        let sets = WorkoutLog.orderedExercises(of: workout).flatMap(WorkoutLog.orderedSets(of:))
        return sets.last(where: \.isCompleted).flatMap(after) ?? sets.first { !$0.isCompleted }
    }

    /// Whether Add Set opens the set it added: only when every other set of its exercise is checked, so adding a
    /// set mid-exercise leaves the set under way open.
    static func opensAddedSet(_ set: WorkoutSet) -> Bool {
        set.workoutExercise?.sets.allSatisfy { $0 === set || $0.isCompleted } ?? true
    }

    /// The weights of a checked-off set and the next one, and what to change on the block between them.
    struct Change {
        let now: Double
        let next: Double
        /// Such as "Pin 30 → 40 · remove 1 adder".
        let line: String
    }

    /// The change after `set`; nil when there is no next set, either has no weight, or there is nothing
    /// to change on the block.
    static func change(after set: WorkoutSet) -> Change? {
        guard let now = set.weight, let next = after(set)?.weight,
            let line = PowerBlockTable.changeLine(from: now, to: next)
        else { return nil }
        return Change(now: now, next: next, line: line)
    }
}
