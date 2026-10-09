import Foundation
import SwiftData

/// Double progression for a workout started from a routine: when every working set last time reached the top
/// of the exercise's rep range, the working sets start at the next PowerBlock setting with reps at the bottom
/// of the range, and the exercise carries a note saying why. Nothing is stored: `RoutineStart` asks once when
/// the workout starts and keeps what it applied in `AppliedProgressions`.
@MainActor
struct Progression {
    let context: ModelContext

    /// What progression says about one workout exercise.
    struct Suggestion: Equatable {
        /// The weight to pre-fill working sets with; nil when only the note applies (bodyweight with no added weight).
        let weight: Double?
        /// The reps to pre-fill working sets with, the bottom of the range.
        let reps: Int
        /// Such as "Up from 35 lb: you hit 12 on every set".
        let text: String
        /// Whether the note leads with the "↑" symbol.
        let showsArrow: Bool

        /// The note as one string: "↑ Up from 35 lb: you hit 12 on every set".
        var note: String { showsArrow ? "↑ \(text)" : text }
    }

    /// The suggestion for a workout exercise of a routine workout that has a rep range, or nil when it has
    /// none: a freeform or timed exercise, no working sets last time, a working set short of the top of the
    /// range, or a last weight of 90 lb with no next setting. "Last time" is the workout the previous-set
    /// lookup uses.
    func suggestion(for workoutExercise: WorkoutExercise) -> Suggestion? {
        guard let kind = workoutExercise.exercise?.kind, kind != .duration,
            let range = RoutineLibrary.repRange(for: workoutExercise)
        else { return nil }
        let working = PreviousSetLookup(context: context).lastWorkingSets(for: workoutExercise)
        guard !working.isEmpty, working.allSatisfy({ ($0.reps ?? 0) >= range.upperBound }) else {
            return nil
        }
        let hit = "you hit \(range.upperBound) on every set"
        guard let heaviest = working.compactMap(\.weight).max() else {
            // Bodyweight with no added weight: the first added block stays the user's decision.
            return kind == .bodyweightReps
                ? Suggestion(
                    weight: nil, reps: range.lowerBound,
                    text: "You hit \(range.upperBound) on every set: consider adding weight",
                    showsArrow: false) : nil
        }
        guard let next = PowerBlockTable.next(after: heaviest) else { return nil }
        let old =
            kind == .bodyweightReps
            ? AddedWeight.label(for: heaviest) : "\(heaviest.formatted()) lb"
        return Suggestion(
            weight: next, reps: range.lowerBound, text: "Up from \(old): \(hit)", showsArrow: true)
    }
}
