import Foundation
import SwiftData

/// Uses a template: starts a workout from it, or turns it into routines. A starter exercise the template
/// names that the store lacks is inserted on use; nothing else in the store changes.
@MainActor
struct TemplateLibrary {
    let context: ModelContext

    /// A routine draft of the template, for the routine editor to adjust and save. Saves any starter
    /// exercise it had to insert, so the draft's exercises are stored.
    func draft(of template: Template) throws -> RoutineDraft {
        let draft = try makeDraft(of: template)
        try context.saveOrRollBack()
        return draft
    }

    /// Starts a workout titled with the template's name, with no routine link, holding its exercises and
    /// set types in order, pre-filled from history as a routine start is, and saves. Nil, changing nothing,
    /// while another workout is in progress.
    func startWorkout(from template: Template, at date: Date = .now) throws -> RoutineStart.Started?
    {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        return try RoutineStart(context: context).startWorkout(
            titled: template.name, from: try makeDraft(of: template), at: date)
    }

    /// Adds every session of the programme as a routine named after it, in one save.
    @discardableResult
    func addProgramme(_ programme: Template.Programme, at date: Date = .now) throws -> [Routine] {
        let drafts = try programme.sessions.map(makeDraft(of:))
        return try RoutineLibrary(context: context).saveNew(drafts, at: date)
    }

    /// The draft, inserting missing starter exercises without saving.
    private func makeDraft(of template: Template) throws -> RoutineDraft {
        let exercises = try StarterExercises.exercises(
            named: template.exercises.map(\.exercise), in: context)
        var draft = RoutineDraft()
        draft.name = template.name
        draft.exercises = template.exercises.compactMap { entry in
            guard let exercise = exercises[entry.exercise] else { return nil }
            return RoutineDraft.Entry(
                exercise: exercise,
                sets: entry.sets.map { RoutineDraft.PlannedSet(type: $0) },
                repLow: entry.repLow ?? RoutineDraft.defaultRepRange.low,
                repHigh: entry.repHigh ?? RoutineDraft.defaultRepRange.high,
                targetDurationSeconds: entry.targetDurationSeconds
                    ?? RoutineDraft.defaultTargetDuration)
        }
        return draft
    }
}
