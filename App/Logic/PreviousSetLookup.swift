import Foundation
import SwiftData

/// Finds what the user did last time for a set: the sets of the most recent finished workout that contains
/// its exercise, paired with the set by order. `previous(for:)` pairs counted sets by counted-set order and
/// gives warm-ups nothing; `previousWarmUp(for:)` pairs warm-ups by their order among warm-ups. Sets past the
/// end of that workout's matching sets get nothing.
@MainActor
struct PreviousSetLookup {
    let context: ModelContext

    /// The values of the previous counted set paired with `set`, or nil when there is none or `set` is a
    /// warm-up. The workout the set belongs to is never its own previous, so a finished workout being edited
    /// is skipped.
    func previous(for set: WorkoutSet) -> PreviousValues? {
        guard let number = SetNumbering.countedNumber(of: set) else { return nil }
        return lastTime(for: set, index: number - 1, matching: SetNumbering.isCounted)
    }

    /// The values of last time's warm-up paired with the warm-up `set` by order among warm-ups, or nil when
    /// there is none or `set` is not a warm-up. Skips the set's own workout like `previous(for:)`.
    func previousWarmUp(for set: WorkoutSet) -> PreviousValues? {
        guard set.setType == .warmUp, let workoutExercise = set.workoutExercise,
            let index = WorkoutLog.orderedSets(of: workoutExercise)
                .filter({ $0.setType == .warmUp }).firstIndex(where: { $0 === set })
        else { return nil }
        return lastTime(for: set, index: index, matching: { $0 == .warmUp })
    }

    /// The set at `index` among the sets whose type matches, in the set's exercise's first occurrence in
    /// the most recent other finished workout containing it.
    private func lastTime(
        for set: WorkoutSet, index: Int, matching include: (SetType) -> Bool
    ) -> PreviousValues? {
        guard let workoutExercise = set.workoutExercise, let exercise = workoutExercise.exercise
        else { return nil }
        let editing = workoutExercise.workout
        // ponytail: fetches every finished workout for each set; fetch by exercise once history is long.
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = (try? context.fetch(descriptor)) ?? []
        guard
            let source = workouts.first(where: { workout in
                workout !== editing && workout.exercises.contains { $0.exercise === exercise }
            }),
            // The exercise's first occurrence in that workout.
            let match = WorkoutLog.orderedExercises(of: source).first(where: {
                $0.exercise === exercise
            })
        else { return nil }
        let previousSets = WorkoutLog.orderedSets(of: match).filter { include($0.setType) }
        guard previousSets.indices.contains(index) else { return nil }
        let previousSet = previousSets[index]
        return PreviousValues(
            weight: previousSet.weight, reps: previousSet.reps,
            durationSeconds: previousSet.durationSeconds)
    }
}

/// What a previous set recorded: its weight (the added weight on bodyweight reps, nil for none), its reps and
/// its duration. Which of them show depends on the exercise kind.
@MainActor
struct PreviousValues: Equatable {
    let weight: Double?
    let reps: Int?
    let durationSeconds: Int?

    /// The value beside a set: "35 lb × 10", "BW × 12", "+10 lb × 8" or "45 s".
    func text(for kind: ExerciseKind) -> String {
        switch kind {
        case .weightReps: "\((weight ?? 0).formatted()) lb × \(repsText)"
        case .bodyweightReps: "\(AddedWeight.label(for: weight)) × \(repsText)"
        case .duration: "\(durationSeconds.map(String.init) ?? "—") s"
        }
    }

    /// The value read aloud: "35 pounds times 10", "bodyweight times 12", "10 pounds added times 8" or "45 seconds".
    func spokenText(for kind: ExerciseKind) -> String {
        switch kind {
        case .weightReps: "\((weight ?? 0).formatted()) pounds times \(repsText)"
        case .bodyweightReps:
            "\(weight.map { "\($0.formatted()) pounds added" } ?? "bodyweight") times \(repsText)"
        case .duration: "\(durationSeconds.map(String.init) ?? "—") seconds"
        }
    }

    private var repsText: String {
        reps.map(String.init) ?? "—"
    }
}
