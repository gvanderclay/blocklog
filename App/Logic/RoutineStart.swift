import Foundation
import SwiftData

/// Starts a workout from a routine, with each set pre-filled from history.
@MainActor
struct RoutineStart {
    let context: ModelContext

    /// A workout started from a routine, with the progressions applied to it.
    struct Started {
        let workout: Workout
        let progressions: AppliedProgressions
    }

    /// Starts a workout titled with the routine's name and linked to it, holding the routine's exercises and
    /// planned sets in order, and saves. Each set is pre-filled:
    /// - a duration set gets the routine's target duration;
    /// - a warm-up gets last time's warm-up in the same place among warm-ups;
    /// - when progression applies (see `Progression`), a normal or failure set gets the stepped-up weight and
    ///   the bottom of the rep range;
    /// - any other set gets the previous counted set's weight and reps;
    /// - with nothing from last time, a set starts like a new freeform set: 5 lb (or "BW") and empty reps.
    /// Routine exercises whose exercise was deleted are skipped. Nil while another workout is in progress.
    /// The result also carries the progressions applied, for the screen to show.
    func startWorkout(from routine: Routine, at date: Date = .now) throws -> Started? {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        // Read the routine's exercises before linking the workout to it. Linking first leaves
        // `routine.exercises` unloaded, and after a rollback reading it traps in SwiftData ("Could not cast
        // DefaultStoreSnapshotValueFuture to Array<RoutineExercise>").
        let planned = RoutineLibrary.orderedExercises(of: routine).filter { $0.exercise != nil }
        let workout = Workout(title: routine.name, startDate: date, routine: routine)
        context.insert(workout)
        var progressions = AppliedProgressions()
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
            let progression = Progression(context: context).suggestion(for: workoutExercise)
            for set in workoutExercise.sets {
                prefill(
                    set, kind: exercise.kind, routineExercise: routineExercise,
                    progression: progression)
            }
            if let progression {
                let stepped =
                    progression.weight == nil
                    ? [] : workoutExercise.sets.filter { SetNumbering.isWorking($0.setType) }
                progressions.record(progression, for: workoutExercise, prefilled: stepped)
            }
        }
        try context.saveOrRollBack()
        return Started(workout: workout, progressions: progressions)
    }

    private func prefill(
        _ set: WorkoutSet, kind: ExerciseKind, routineExercise: RoutineExercise,
        progression: Progression.Suggestion?
    ) {
        if kind == .duration {
            set.durationSeconds =
                routineExercise.targetDurationSeconds ?? RoutineDraft.defaultTargetDuration
            return
        }
        if let progression, let weight = progression.weight, SetNumbering.isWorking(set.setType) {
            set.weight = weight
            set.reps = progression.reps
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
