import Foundation

/// The progressions a routine workout actually applied when it started: per workout exercise, its note, and
/// which sets were pre-filled with the stepped-up weight. Held as transient view state for the workout in
/// progress and never stored, so it is gone after a relaunch. Workout exercises and sets are told apart by
/// id, so an exercise added later, or a set added or duplicated later, is never part of it.
@MainActor
struct AppliedProgressions {
    private var suggestions: [UUID: Progression.Suggestion] = [:]
    private var highlightedSetIDs: Set<UUID> = []

    /// Records the suggestion applied to `workoutExercise`; `prefilled` are the sets it gave the stepped-up
    /// weight, which stay highlighted until the user changes the weight or checks the set off.
    mutating func record(
        _ suggestion: Progression.Suggestion, for workoutExercise: WorkoutExercise,
        prefilled: [WorkoutSet]
    ) {
        suggestions[workoutExercise.id] = suggestion
        highlightedSetIDs.formUnion(prefilled.map(\.id))
    }

    /// The note the exercise's progression applied at start, or nil when none did.
    func note(for workoutExercise: WorkoutExercise) -> Progression.Suggestion? {
        suggestions[workoutExercise.id]
    }

    /// Whether the set still shows the weight progression pre-filled.
    func isHighlighted(_ set: WorkoutSet) -> Bool {
        highlightedSetIDs.contains(set.id)
    }

    /// The user changed the set's weight (by −, +, the weight menu, the setup sheet or last time's values):
    /// its highlight ends for good, even if the weight comes back to the suggested one.
    mutating func weightChanged(of set: WorkoutSet) {
        highlightedSetIDs.remove(set.id)
    }

    /// The user checked the set off: its highlight ends for good, even if the set is unchecked again.
    mutating func checkedOff(_ set: WorkoutSet) {
        highlightedSetIDs.remove(set.id)
    }
}
