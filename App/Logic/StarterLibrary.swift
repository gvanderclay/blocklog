import Foundation
import SwiftData

/// Uses a starter routine: starts a workout from it, or turns it into routines. A starter exercise the starter routine
/// names that the store lacks is inserted on use; nothing else in the store changes.
@MainActor
struct StarterLibrary {
    let context: ModelContext

    /// A routine draft of the starter routine, in its format, for the routine editor to adjust and save. Saves any starter
    /// exercise it had to insert, so the draft's exercises are stored.
    func draft(of starterRoutine: StarterRoutine) throws -> RoutineDraft {
        let draft = try makeDraft(of: starterRoutine)
        try context.saveOrRollBack()
        return draft
    }

    /// Starts a workout titled with the starter routine's name, with no routine link, holding its exercises and
    /// set types in order, pre-filled from history as a routine start is, and saves. Nil, changing nothing,
    /// while another workout is in progress or for a starter routine that isn't of the Sets format.
    func startWorkout(from starterRoutine: StarterRoutine, at date: Date = .now) throws
        -> RoutineStart.Started?
    {
        guard starterRoutine.format == .sets,
            WorkoutLog(context: context).inProgressWorkout() == nil
        else { return nil }
        return try RoutineStart(context: context).startWorkout(
            titled: starterRoutine.name, from: try makeDraft(of: starterRoutine), at: date)
    }

    /// Creates a programme of the starter programme's name holding a copy of each of its routines, in order,
    /// in one save.
    @discardableResult
    func addProgramme(_ programme: StarterProgramme, at date: Date = .now) throws -> Programme? {
        let drafts = try programme.routines.map(makeDraft(of:))
        return try ProgrammeLibrary(context: context).create(
            named: programme.name, holding: drafts, at: date)
    }

    /// The draft, inserting missing starter exercises without saving.
    private func makeDraft(of starterRoutine: StarterRoutine) throws -> RoutineDraft {
        let exercises = try StarterExercises.exercises(
            named: starterRoutine.exercises.map(\.exercise), in: context)
        return RoutineDraft(
            name: starterRoutine.name, format: starterRoutine.format,
            exercises: starterRoutine.exercises.compactMap { entry in
                guard let exercise = exercises[entry.exercise] else { return nil }
                return RoutineDraft.Entry(
                    exercise: exercise,
                    sets: entry.sets.map { RoutineDraft.PlannedSet(type: $0) },
                    target: entry.target)
            })
    }
}
