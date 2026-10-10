import Foundation

/// One round of a stretch routine, which the stretch player plays: its stretches in order, each held for a fixed
/// number of seconds, on each side in turn for a per-side stretch. Built from a Stretch-format routine's exercises
/// or a starter stretch routine, and only when every stretch has a hold.
@MainActor
struct StretchRound {
    /// One stretch of the round. The player logs it by name, so a starter stretch the store lacks is inserted then.
    struct Stretch {
        let name: String
        let seconds: Int
        let isPerSide: Bool
    }

    /// What the rules read from one routine exercise.
    struct Row {
        let type: ExerciseType
        let target: RoutineTarget?
    }

    let stretches: [Stretch]

    /// The round of a routine's exercises, in position order, leaving out those whose exercise was deleted. A
    /// stretch is per side when its exercise is. Nil unless they keep the rules of `holdSeconds(of:)`.
    init?(_ routineExercises: [RoutineExercise]) {
        let exercises = RoutineLibrary.ordered(routineExercises).compactMap { routineExercise in
            routineExercise.exercise.map { (exercise: $0, target: routineExercise.target) }
        }
        guard
            let seconds = Self.holdSeconds(
                of: exercises.map { Row(type: $0.exercise.type, target: $0.target) })
        else { return nil }
        stretches = zip(exercises, seconds).map {
            Stretch(name: $0.exercise.name, seconds: $1, isPerSide: $0.exercise.isPerSide == true)
        }
    }

    /// The round of a starter stretch routine. A stretch is per side when the starter exercise of its name is,
    /// since seeding may resolve the name to a custom exercise. Nil when it has no entries or an entry has no
    /// target duration.
    init?(_ starterRoutine: StarterRoutine) {
        var stretches: [Stretch] = []
        for entry in starterRoutine.exercises {
            guard let seconds = entry.target?.seconds else { return nil }
            stretches.append(
                Stretch(name: entry.exercise, seconds: seconds, isPerSide: entry.isPerSide))
        }
        guard !stretches.isEmpty else { return nil }
        self.stretches = stretches
    }

    /// Each row's hold in seconds, in order; nil unless there is at least one row and every row is a duration
    /// exercise with a target duration. Import checks a stored Stretch routine's records with it.
    static func holdSeconds(of rows: [Row]) -> [Int]? {
        guard !rows.isEmpty else { return nil }
        var seconds: [Int] = []
        for row in rows {
            guard row.type == .duration, let hold = row.target?.seconds else { return nil }
            seconds.append(hold)
        }
        return seconds
    }
}
