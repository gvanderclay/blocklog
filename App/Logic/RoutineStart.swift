import Foundation
import SwiftData

/// Starts a workout from a routine or from a draft of one (a template's), with each set pre-filled from history.
@MainActor
struct RoutineStart {
    let context: ModelContext

    /// A workout started from a routine, with the progressions applied to it.
    struct Started {
        let workout: Workout
        let progressions: AppliedProgressions
    }

    /// One exercise to start with: its planned set types, and the target duration for a duration exercise.
    private struct Planned {
        let exercise: Exercise
        let setTypes: [SetType]
        let targetDurationSeconds: Int?
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
        let planned = RoutineLibrary.orderedExercises(of: routine).compactMap { routineExercise in
            routineExercise.exercise.map {
                Planned(
                    exercise: $0,
                    setTypes: routineExercise.plannedSetTypeRawValues.map {
                        SetType(rawValue: $0) ?? .normal
                    },
                    targetDurationSeconds: routineExercise.targetDurationSeconds)
            }
        }
        let workout = Workout(title: routine.name, startDate: date, routine: routine)
        return try start(workout, with: planned)
    }

    /// Starts a workout with the given title and no routine link, holding the draft's exercises and planned
    /// sets in order, pre-filled as `startWorkout(from:)` does, and saves. With no routine link, no
    /// progression applies. Nil while another workout is in progress.
    func startWorkout(titled title: String, from draft: RoutineDraft, at date: Date = .now) throws
        -> Started?
    {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        let planned = draft.exercises.map {
            Planned(
                exercise: $0.exercise, setTypes: $0.sets.map(\.type),
                targetDurationSeconds: $0.isTimed ? $0.targetDurationSeconds : nil)
        }
        return try start(Workout(title: title, startDate: date), with: planned)
    }

    private func start(_ workout: Workout, with planned: [Planned]) throws -> Started {
        context.insert(workout)
        var progressions = AppliedProgressions()
        for (position, plannedExercise) in planned.enumerated() {
            let exercise = plannedExercise.exercise
            let workoutExercise = WorkoutExercise(exercise: exercise, position: position)
            context.insert(workoutExercise)
            workout.exercises.append(workoutExercise)
            // Every set is in place before any lookup, because the lookup pairs a set by its order.
            for (setPosition, type) in plannedExercise.setTypes.enumerated() {
                let set = WorkoutSet(position: setPosition, setType: type)
                context.insert(set)
                workoutExercise.sets.append(set)
            }
            let progression = Progression(context: context).suggestion(for: workoutExercise)
            for set in workoutExercise.sets {
                prefill(
                    set, kind: exercise.kind,
                    targetDurationSeconds: plannedExercise.targetDurationSeconds,
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

    /// Reads history for the set, then writes the values it starts with.
    private func prefill(
        _ set: WorkoutSet, kind: ExerciseKind, targetDurationSeconds: Int?,
        progression: Progression.Suggestion?
    ) {
        let lookup = PreviousSetLookup(context: context)
        let stepUp = progression.flatMap { suggestion in
            suggestion.weight.map { (weight: $0, reps: suggestion.reps) }
        }
        set.values = SetValues.prefilled(
            for: kind,
            previous: set.setType == .warmUp
                ? lookup.previousWarmUp(for: set) : lookup.previous(for: set),
            progression: SetNumbering.isWorking(set.setType) ? stepUp : nil,
            targetSeconds: targetDurationSeconds)
    }
}
