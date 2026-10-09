import Foundation
import SwiftData

/// Saves, deletes and describes routines. Every change saves at once, so killing the app loses nothing.
@MainActor
struct RoutineLibrary {
    let context: ModelContext

    /// Every routine, sorted by name. Views use it in `@Query`.
    static var routinesByName: FetchDescriptor<Routine> {
        FetchDescriptor(sortBy: [SortDescriptor(\.name)])
    }

    /// The routine's exercises in position order.
    static func orderedExercises(of routine: Routine) -> [RoutineExercise] {
        routine.exercises.sorted { $0.position < $1.position }
    }

    /// A routine exercise's plan: "3 × 8–12" for a rep range, "3 × 45 s" for a target duration.
    static func summary(of routineExercise: RoutineExercise) -> String {
        let count = routineExercise.plannedSetTypeRawValues.count
        if let seconds = routineExercise.targetDurationSeconds { return "\(count) × \(seconds) s" }
        guard let low = routineExercise.repRangeLow, let high = routineExercise.repRangeHigh else {
            return "\(count) × —"
        }
        return "\(count) × \(low)–\(high)"
    }

    /// The plan read aloud: "3 sets of 8 to 12 reps" or "3 sets of 45 seconds".
    static func spokenSummary(of routineExercise: RoutineExercise) -> String {
        let count = routineExercise.plannedSetTypeRawValues.count
        let sets = count == 1 ? "1 set" : "\(count) sets"
        if let seconds = routineExercise.targetDurationSeconds {
            return "\(sets) of \(seconds) seconds"
        }
        guard let low = routineExercise.repRangeLow, let high = routineExercise.repRangeHigh else {
            return sets
        }
        return "\(sets) of \(low) to \(high) reps"
    }

    /// "8–12" for a workout exercise whose workout started from a routine that gives the exercise a rep
    /// range; nil otherwise.
    static func repRangeText(for workoutExercise: WorkoutExercise) -> String? {
        repRange(for: workoutExercise).map { "\($0.lowerBound)–\($0.upperBound)" }
    }

    /// The rep range a workout exercise's routine gives it; nil for a freeform workout or an exercise
    /// with no range. When the routine lists the exercise more than once, the nth such workout exercise
    /// (by position) takes the nth occurrence's range.
    static func repRange(for workoutExercise: WorkoutExercise) -> ClosedRange<Int>? {
        guard let workout = workoutExercise.workout, let routine = workout.routine,
            let exercise = workoutExercise.exercise
        else { return nil }
        let occurrence = WorkoutLog.orderedExercises(of: workout)
            .filter { $0.exercise === exercise }
            .firstIndex { $0 === workoutExercise }
        let occurrences = RoutineLibrary.orderedExercises(of: routine).filter {
            $0.exercise === exercise
        }
        guard let occurrence, occurrences.indices.contains(occurrence),
            let low = occurrences[occurrence].repRangeLow,
            let high = occurrences[occurrence].repRangeHigh, low <= high
        else { return nil }
        return low...high
    }

    /// Writes the draft into `routine`, replacing its name and exercises, or into a new routine when it is
    /// nil, and saves. Nil, changing nothing, when the draft can't be saved.
    @discardableResult
    func save(_ draft: RoutineDraft, to routine: Routine?, at date: Date = .now) throws -> Routine?
    {
        guard draft.canSave else { return nil }
        let target = routine ?? Routine(name: draft.trimmedName, creationDate: date)
        if routine == nil { context.insert(target) }
        target.name = draft.trimmedName
        let old = target.exercises
        target.exercises.removeAll()
        old.forEach(context.delete)
        for (position, entry) in draft.exercises.enumerated() {
            let routineExercise = RoutineExercise(
                exercise: entry.exercise, position: position,
                plannedSetTypes: entry.sets.map(\.type),
                repRangeLow: entry.isTimed ? nil : entry.repLow,
                repRangeHigh: entry.isTimed ? nil : entry.repHigh,
                targetDurationSeconds: entry.isTimed ? entry.targetDurationSeconds : nil)
            context.insert(routineExercise)
            target.exercises.append(routineExercise)
        }
        try context.saveOrRollBack()
        return target
    }

    /// Deletes the routine with its routine exercises. Workouts started from it are kept, with their link cleared.
    func delete(_ routine: Routine) throws {
        context.delete(routine)
        try context.saveOrRollBack()
    }
}
