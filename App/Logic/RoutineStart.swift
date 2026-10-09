import Foundation
import SwiftData

/// Starts a workout from a routine, with each set pre-filled from history, and gives the rep-range
/// placeholder its reps fields show.
@MainActor
struct RoutineStart {
    let context: ModelContext

    /// Starts a workout titled with the routine's name and linked to it, holding the routine's exercises and
    /// planned sets in order, and saves. Each set is pre-filled:
    /// - a duration set gets the routine's target duration;
    /// - a warm-up gets last time's warm-up in the same place among warm-ups;
    /// - any other set gets the previous counted set's weight and reps;
    /// - with nothing from last time, a set starts like a new freeform set: 5 lb (or "BW") and empty reps.
    /// Routine exercises whose exercise was deleted are skipped. Nil while another workout is in progress.
    func startWorkout(from routine: Routine, at date: Date = .now) throws -> Workout? {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        let workout = Workout(title: routine.name, startDate: date, routine: routine)
        context.insert(workout)
        let planned = RoutineLibrary.orderedExercises(of: routine).filter { $0.exercise != nil }
        for (position, routineExercise) in planned.enumerated() {
            guard let exercise = routineExercise.exercise else { continue }
            let workoutExercise = WorkoutExercise(exercise: exercise, position: position)
            context.insert(workoutExercise)
            workout.exercises.append(workoutExercise)
            // Every set is in place before any lookup, because the lookup pairs a set by its order.
            for (setPosition, raw) in routineExercise.plannedSetTypeRawValues.enumerated() {
                let set = WorkoutSet(
                    position: setPosition, setType: SetType(rawValue: raw) ?? .normal)
                context.insert(set)
                workoutExercise.sets.append(set)
            }
            for set in workoutExercise.sets {
                prefill(set, kind: exercise.kind, routineExercise: routineExercise)
            }
        }
        try context.saveOrRollBack()
        return workout
    }

    /// "8–12" for a workout exercise whose workout started from a routine that gives the exercise a rep
    /// range; nil otherwise. When the routine lists the exercise more than once, the nth such workout
    /// exercise (by position) takes the nth occurrence's range.
    static func repRangeText(for workoutExercise: WorkoutExercise) -> String? {
        guard let workout = workoutExercise.workout, let routine = workout.routine,
            let exercise = workoutExercise.exercise
        else { return nil }
        let occurrence = WorkoutLog.orderedExercises(of: workout)
            .filter { $0.exercise === exercise }
            .firstIndex { $0 === workoutExercise }
        let occurrences = RoutineLibrary.orderedExercises(of: routine).filter {
            $0.exercise === exercise
        }
        guard let occurrence, occurrences.indices.contains(occurrence),
            let low = occurrences[occurrence].repRangeLow,
            let high = occurrences[occurrence].repRangeHigh
        else { return nil }
        return "\(low)–\(high)"
    }

    private func prefill(_ set: WorkoutSet, kind: ExerciseKind, routineExercise: RoutineExercise) {
        if kind == .duration {
            set.durationSeconds =
                routineExercise.targetDurationSeconds ?? RoutineDraft.defaultTargetDuration
            return
        }
        let lookup = PreviousSetLookup(context: context)
        let previous =
            set.setType == .warmUp ? lookup.previousWarmUp(for: set) : lookup.previous(for: set)
        let firstWeight = PowerBlockTable.weights[0]
        // A bodyweight set's nil weight is "BW", so last time's nil is kept rather than defaulted.
        set.weight = kind == .weightReps ? previous?.weight ?? firstWeight : previous?.weight
        set.reps = previous?.reps
    }
}
