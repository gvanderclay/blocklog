import Foundation
import SwiftData

/// Compares a finished workout with the routine it started from, and rewrites the routine to match.
@MainActor
struct RoutineDifference {
    let context: ModelContext

    /// Whether the workout has a structural change against its routine: its ordered exercises differ, or
    /// an exercise's set count does. Weight, reps, duration and set-type edits never count. False for a
    /// workout with no routine. Call it after Finish, which has dropped unchecked sets and empty exercises.
    /// Routine and workout exercises whose exercise was deleted are left out, since a workout started from
    /// the routine never held them.
    static func isStructural(_ workout: Workout) -> Bool {
        guard let routine = workout.routine else { return false }
        let planned = plannedExercises(of: routine).map {
            ($0.exercise, $0.plannedSetTypeRawValues.count)
        }
        let done = doneExercises(of: workout).map { ($0.exercise, $0.sets.count) }
        return planned.count != done.count
            || zip(planned, done).contains { $0.0 !== $1.0 || $0.1 != $1.1 }
    }

    /// Rewrites the routine's exercises to match the workout's order, and saves. A routine exercise for the
    /// same exercise is reused (the nth occurrence matching the nth, when an exercise appears twice), keeping
    /// its rep range or target duration; its planned set types become the workout's set types. A new
    /// exercise gets the default rep range, or the default target duration for a duration exercise.
    /// Routine exercises the workout no longer has are deleted. When the save fails it rolls everything
    /// back and throws.
    func update(_ routine: Routine, toMatch workout: Workout) throws {
        var unused = RoutineLibrary.orderedExercises(of: routine)
        var kept: [RoutineExercise] = []
        for done in Self.doneExercises(of: workout) {
            guard let exercise = done.exercise else { continue }
            let position = kept.count
            let types = WorkoutLog.orderedSets(of: done).map(\.setType)
            let routineExercise: RoutineExercise
            if let index = unused.firstIndex(where: { $0.exercise === exercise }) {
                routineExercise = unused.remove(at: index)
                routineExercise.plannedSetTypeRawValues = types.map(\.rawValue)
            } else {
                let isTimed = exercise.kind == .duration
                routineExercise = RoutineExercise(
                    exercise: exercise, position: position, plannedSetTypes: types,
                    repRangeLow: isTimed ? nil : RoutineTarget.defaultRepRange.lowerBound,
                    repRangeHigh: isTimed ? nil : RoutineTarget.defaultRepRange.upperBound,
                    targetDurationSeconds: isTimed ? RoutineTarget.defaultDurationSeconds : nil)
                context.insert(routineExercise)
                routine.exercises.append(routineExercise)
            }
            routineExercise.position = position
            kept.append(routineExercise)
        }
        // What is left over, with the entries whose exercise was deleted, is gone from the workout.
        routine.exercises.removeAll { !kept.contains($0) }
        unused.forEach(context.delete)
        try context.saveOrRollBack()
    }

    private static func plannedExercises(of routine: Routine) -> [RoutineExercise] {
        RoutineLibrary.orderedExercises(of: routine).filter { $0.exercise != nil }
    }

    private static func doneExercises(of workout: Workout) -> [WorkoutExercise] {
        WorkoutLog.orderedExercises(of: workout).filter { $0.exercise != nil }
    }
}
