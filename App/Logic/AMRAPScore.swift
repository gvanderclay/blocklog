import Foundation

/// A Timed AMRAP's score: the rounds completed plus the extra reps of the unfinished round. Both ways in are
/// failable, so a score always has rounds and extra reps of 0 or more.
@MainActor
struct AMRAPScore: Equatable {
    let rounds: Int
    let extraReps: Int

    /// A score of the round, as the AMRAP player keeps it; nil unless rounds are 0 or more and extra reps are 0 up
    /// to one fewer than the round's reps.
    init?(rounds: Int, extraReps: Int, of round: AMRAPRound) {
        guard rounds >= 0, (0..<round.repsPerRound).contains(extraReps) else { return nil }
        self.rounds = rounds
        self.extraReps = extraReps
    }

    /// A score from a workout's stored fields; nil unless both are 0 or more. A workout doesn't store its round,
    /// and its routine may have changed since, so the upper bound of the extra reps can't be checked again.
    init?(storedRounds rounds: Int, extraReps: Int) {
        guard rounds >= 0, extraReps >= 0 else { return nil }
        self.rounds = rounds
        self.extraReps = extraReps
    }

    /// "14 rounds + 7 reps", always both parts: "1 round + 0 reps".
    var text: String {
        "\(rounds) \(rounds == 1 ? "round" : "rounds") + \(extraReps) \(extraReps == 1 ? "rep" : "reps")"
    }

    /// The score read aloud: "14 rounds plus 7 reps".
    var spokenText: String { text.replacingOccurrences(of: "+", with: "plus") }

    /// Last time's score of a Timed AMRAP: the newest finished Timed AMRAP workout among `workouts` that is
    /// linked to the routine, or, for a starter routine (`routine` nil), that has no routine link and the title.
    /// Nil when there is none.
    static func last(of routine: Routine?, titled title: String, in workouts: [Workout])
        -> AMRAPScore?
    {
        workouts.filter { workout in
            guard workout.endDate != nil else { return false }
            if let routine { return workout.routine === routine }
            return workout.routine == nil && workout.title == title
        }
        .compactMap { workout in workout.format.score.map { (workout.startDate, $0) } }
        .max { $0.0 < $1.0 }?.1
    }
}
