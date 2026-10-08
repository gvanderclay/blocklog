import Foundation
import SwiftData

/// Finds what the user did last time for a set: the non-warm-up sets of the most recent finished workout that
/// contains its exercise, paired with the set by counted-set order. Warm-up sets get nothing, and so do sets
/// past the end of that workout's sets.
@MainActor
struct PreviousSetLookup {
    let context: ModelContext

    /// The values of the previous set paired with `set`, or nil when there is none. The workout the set
    /// belongs to is never its own previous, so a finished workout being edited is skipped.
    func previous(for set: WorkoutSet) -> PreviousValues? {
        guard let workoutExercise = set.workoutExercise, let exercise = workoutExercise.exercise,
            let number = SetNumbering.countedNumber(of: set)
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
        let previousSets = WorkoutLog.orderedSets(of: match).filter {
            SetNumbering.isCounted($0.setType)
        }
        guard previousSets.indices.contains(number - 1) else { return nil }
        let previousSet = previousSets[number - 1]
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
