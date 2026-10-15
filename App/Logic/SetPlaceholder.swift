import Foundation
import SwiftData

/// The grey number in a set's empty reps or seconds field, and what checking the set off fills in.
@MainActor
struct SetPlaceholder {
    let context: ModelContext

    /// The rep range's low end (rep types only), else the previous numbers' reps or seconds, else the set
    /// above's value or, when that is empty, its placeholder. Nil when none applies.
    func value(for set: WorkoutSet) -> Int? {
        if let workoutExercise = set.workoutExercise {
            let type = workoutExercise.exercise?.type ?? .weightReps
            if type != .duration, let range = RoutineLibrary.repRange(for: workoutExercise) {
                return range.lowerBound
            }
        }
        if let previous = PreviousSetLookup(context: context).previousNumbers(for: set),
            let number = Self.number(of: previous)
        {
            return number
        }
        // shortcut: one finished-workout fetch per set walked up; fine for a handful of sets, cache if slow.
        guard let workoutExercise = set.workoutExercise,
            let index = WorkoutLog.orderedSets(of: workoutExercise).firstIndex(where: { $0 === set }
            ),
            index > 0
        else { return nil }
        let above = WorkoutLog.orderedSets(of: workoutExercise)[index - 1]
        return Self.number(of: above.values) ?? value(for: above)
    }

    /// What a set summary shows: a checked set's own values; an unchecked set's values with an empty or zero
    /// reps or seconds filled from the placeholder, as checking it off would log; its own values with none.
    func summaryValues(for set: WorkoutSet) -> SetValues {
        let values = set.values
        guard !set.isCompleted, !values.canCheckOff, let number = value(for: set) else {
            return values
        }
        return values.filling(number)
    }

    private static func number(of values: SetValues) -> Int? {
        let number = values.reps ?? values.seconds
        return (number ?? 0) > 0 ? number : nil
    }
}
