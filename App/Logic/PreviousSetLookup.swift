import Foundation
import SwiftData

/// Finds what the user did last time for a set: the sets of the most recent finished workout that contains
/// its exercise, paired with the set by order. `previous(for:)` pairs counted sets by counted-set order and
/// gives warm-ups nothing; `previousWarmUp(for:)` pairs warm-ups by their order among warm-ups. Sets past the
/// end of that workout's matching sets get nothing. Sets lacking their kind's required values (a half-edited
/// past workout) are skipped, so they never feed a later workout.
@MainActor
struct PreviousSetLookup {
    let context: ModelContext

    /// The values of the previous counted set paired with `set`, or nil when there is none or `set` is a
    /// warm-up. The workout the set belongs to is never its own previous, so a finished workout being edited
    /// is skipped.
    func previous(for set: WorkoutSet) -> SetValues? {
        guard let number = SetNumbering.countedNumber(of: set) else { return nil }
        return lastTime(for: set, index: number - 1, matching: SetNumbering.isCounted)
    }

    /// The values of last time's warm-up paired with the warm-up `set` by order among warm-ups, or nil when
    /// there is none or `set` is not a warm-up. Skips the set's own workout like `previous(for:)`.
    func previousWarmUp(for set: WorkoutSet) -> SetValues? {
        guard set.setType == .warmUp, let workoutExercise = set.workoutExercise,
            let index = WorkoutLog.orderedSets(of: workoutExercise)
                .filter({ $0.setType == .warmUp }).firstIndex(where: { $0 === set })
        else { return nil }
        return lastTime(for: set, index: index, matching: { $0 == .warmUp })
    }

    /// The values of every progression set (normal and failure) in last time's workout exercise for
    /// `workoutExercise`, in order; empty when there is no last time. Skips the exercise's own workout and Timed
    /// AMRAP workouts, whose sets each hold an AMRAP's total reps rather than one set's.
    func lastProgressionSets(for workoutExercise: WorkoutExercise) -> [SetValues] {
        guard let exercise = workoutExercise.exercise,
            let match = lastTime(
                of: exercise, skipping: workoutExercise.workout, includingAMRAP: false)
        else { return [] }
        return WorkoutLog.orderedSets(of: match).filter {
            SetNumbering.isProgressionSet($0.setType) && $0.values.canCheckOff
        }.map(
            \.values)
    }

    /// The values of the first counted set the last time the exercise was done, for a start with no set yet, such
    /// as the AMRAP player's weights; nil when there is none.
    func previousFirstSet(of exercise: Exercise) -> SetValues? {
        guard let match = lastTime(of: exercise, skipping: nil) else { return nil }
        return WorkoutLog.orderedSets(of: match).first {
            SetNumbering.isCounted($0.setType) && $0.values.canCheckOff
        }?.values
    }

    /// The set at `index` among the sets whose type matches, in the set's exercise's first occurrence in
    /// the most recent other finished workout containing it.
    private func lastTime(
        for set: WorkoutSet, index: Int, matching include: (SetType) -> Bool
    ) -> SetValues? {
        guard let workoutExercise = set.workoutExercise, let exercise = workoutExercise.exercise,
            let match = lastTime(of: exercise, skipping: workoutExercise.workout)
        else { return nil }
        let previousSets = WorkoutLog.orderedSets(of: match).filter {
            include($0.setType) && $0.values.canCheckOff
        }
        guard previousSets.indices.contains(index) else { return nil }
        return previousSets[index].values
    }

    /// The first occurrence of the exercise in the most recent finished workout, other than `editing`, that
    /// contains it, leaving out Timed AMRAP workouts unless `includingAMRAP`.
    private func lastTime(
        of exercise: Exercise, skipping editing: Workout?, includingAMRAP: Bool = true
    ) -> WorkoutExercise? {
        // ponytail: fetches every finished workout for each set; fetch by exercise once history is long.
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = (try? context.fetch(descriptor)) ?? []
        guard
            let source = workouts.first(where: { workout in
                workout !== editing && (includingAMRAP || workout.format == .sets)
                    && workout.exercises.contains { $0.exercise === exercise }
            })
        else { return nil }
        return WorkoutLog.orderedExercises(of: source).first { $0.exercise === exercise }
    }

}
