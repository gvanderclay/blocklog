import Foundation

/// One round of a Timed AMRAP routine: its exercises in order, each with one fixed rep count. The only way to get
/// one is from a routine's exercises that keep the Timed AMRAP rules, so the AMRAP player and the score never
/// check them again.
@MainActor
struct AMRAPRound {
    /// One exercise of the round and the reps it takes each round.
    struct Entry {
        let exercise: Exercise
        let reps: Int
    }

    /// What the rules read from one routine exercise.
    struct Row {
        let type: ExerciseType
        let plannedSetCount: Int
        let target: RoutineTarget?
    }

    let entries: [Entry]

    /// The reps of one whole round: the sum of each exercise's reps.
    var repsPerRound: Int { entries.reduce(0) { $0 + $1.reps } }

    /// The round of a routine's exercises, in position order, leaving out those whose exercise was deleted. Nil
    /// unless they keep the rules of `fixedReps(of:)`.
    init?(_ routineExercises: [RoutineExercise]) {
        let ordered = RoutineLibrary.ordered(routineExercises).compactMap { routineExercise in
            routineExercise.exercise.map { (exercise: $0, routineExercise: routineExercise) }
        }
        let rows = ordered.map {
            Row(
                type: $0.exercise.type,
                plannedSetCount: $0.routineExercise.plannedSetTypeRawValues.count,
                target: $0.routineExercise.target)
        }
        guard let reps = Self.fixedReps(of: rows) else { return nil }
        entries = zip(ordered, reps).map { Entry(exercise: $0.exercise, reps: $1) }
    }

    /// The round of a routine draft's exercises, such as a starter routine's, in order. Nil unless they keep the
    /// rules of `fixedReps(of:)`.
    init?(draft: RoutineDraft) {
        let rows = draft.exercises.map {
            Row(type: $0.exercise.type, plannedSetCount: $0.sets.count, target: $0.target)
        }
        guard let reps = Self.fixedReps(of: rows) else { return nil }
        entries = zip(draft.exercises, reps).map { Entry(exercise: $0.exercise, reps: $1) }
    }

    /// Each exercise's total reps for the score, in order: the score's rounds times its reps, plus the extra reps
    /// given out in round order, each exercise taking at most its reps. Cindy (5, 10, 15) at 14 rounds + 7 reps
    /// gives 75, 142 and 210.
    func totalReps(for score: AMRAPScore) -> [Int] {
        var extraLeft = score.extraReps
        return entries.map { entry in
            let extra = min(extraLeft, entry.reps)
            extraLeft -= extra
            return score.rounds * entry.reps + extra
        }
    }

    /// Each row's fixed rep count, in order; nil unless there is at least one row and every row is a rep
    /// exercise (weight × reps or bodyweight reps) with exactly one planned set and a rep range whose low end is
    /// its high end. Import checks a stored routine's records with it.
    static func fixedReps(of rows: [Row]) -> [Int]? {
        guard !rows.isEmpty else { return nil }
        var reps: [Int] = []
        for row in rows {
            guard row.type != .duration, row.plannedSetCount == 1,
                let range = row.target?.repRange, range.lowerBound == range.upperBound
            else { return nil }
            reps.append(range.upperBound)
        }
        return reps
    }
}
