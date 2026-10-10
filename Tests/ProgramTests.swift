import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the program library and up next against an in-memory store seeded with the starters.
@MainActor
struct ProgramTests {
    let container: ModelContainer
    let library: ProgramLibrary
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        library = ProgramLibrary(context: container.mainContext)
    }

    private var context: ModelContext { container.mainContext }

    private func draft(_ name: String) throws -> RoutineDraft {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == "Dumbbell Bench Press" })
        var draft = RoutineDraft()
        draft.name = name
        draft.addExercise(try #require(try context.fetch(descriptor).first))
        return draft
    }

    /// A program holding a new routine for each name, in order.
    private func program(_ names: [String]) throws -> Program {
        try #require(try library.create(named: "PPL", holding: names.map(draft)))
    }

    private func names(in program: Program) -> [String] {
        ProgramLibrary.orderedRoutines(of: program).map(\.name)
    }

    private func positions(in program: Program) -> [Int?] {
        ProgramLibrary.orderedRoutines(of: program).map { $0.membership?.position }
    }

    private func routine(_ name: String, in program: Program) throws -> Routine {
        try #require(ProgramLibrary.orderedRoutines(of: program).first { $0.name == name })
    }

    /// A finished workout of the routine starting `hours` after `start`.
    @discardableResult
    private func finishWorkout(of routine: Routine, hours: Double, finished: Bool = true) throws
        -> Workout
    {
        let date = start.addingTimeInterval(hours * 3_600)
        let workout = Workout(
            title: routine.name, startDate: date, endDate: finished ? date + 1_800 : nil,
            routine: routine)
        context.insert(workout)
        try context.save()
        return workout
    }

    // MARK: My Routines

    @Test func myRoutinesHoldsOnlyRoutinesInNoProgram() throws {
        _ = try program(["Push", "Pull"])
        try RoutineLibrary(context: context).save(try draft("Arms"), to: nil)

        #expect(try context.fetch(ProgramLibrary.myRoutines).map(\.name) == ["Arms"])
    }

    // MARK: Create, rename and delete

    @Test func createSavesATrimmedNameAndRefusesABlankOne() throws {
        let program = try #require(try library.create(named: "  Push Pull Legs \n", at: start))

        let fresh = try ModelContext(container).fetch(FetchDescriptor<Program>())
        #expect(fresh.map(\.name) == ["Push Pull Legs"])
        #expect(program.creationDate == start)
        #expect(program.routines.isEmpty)
        #expect(try library.create(named: " \n ") == nil)
        #expect(try context.fetchCount(FetchDescriptor<Program>()) == 1)
    }

    @Test func renameSavesATrimmedNameAndRefusesABlankOne() throws {
        let program = try program([])

        #expect(try library.rename(program, to: " Upper/Lower "))
        #expect(!(try library.rename(program, to: "   ")))

        let fresh = try ModelContext(container).fetch(FetchDescriptor<Program>())
        #expect(fresh.map(\.name) == ["Upper/Lower"])
    }

    @Test func deleteMovesItsRoutinesToMyRoutines() throws {
        let program = try program(["Push", "Pull"])

        try library.delete(program)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Program>()) == 0)
        let routines = try fresh.fetch(RoutineLibrary.routinesByName)
        #expect(routines.map(\.name) == ["Pull", "Push"])
        #expect(routines.allSatisfy { $0.program == nil && $0.programPosition == nil })
    }

    // MARK: Adding

    @Test func createHoldsTheDraftsInOrder() throws {
        let program = try program(["Push", "Pull", "Legs"])

        #expect(names(in: program) == ["Push", "Pull", "Legs"])
        #expect(positions(in: program) == [0, 1, 2])
    }

    @Test func addCopiesFromMyRoutinesAStarterRoutineOrANewRoutineToTheEnd() throws {
        let program = try program(["Push"])
        let mine = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))
        let goldenSix = try #require(try StarterRoutine.load().first { $0.name == "Golden Six" })

        let copy = try #require(try library.add(RoutineDraft(routine: mine), to: program))
        try library.add(StarterLibrary(context: context).draft(of: goldenSix), to: program)
        try library.add(draft("Legs"), to: program)

        #expect(names(in: program) == ["Push", "Arms", "Golden Six", "Legs"])
        #expect(positions(in: program) == [0, 1, 2, 3])
        #expect(copy !== mine)
        #expect(mine.membership == nil)
        #expect(RoutineLibrary.orderedExercises(of: copy).count == 1)
        let fresh = try ModelContext(container).fetch(FetchDescriptor<Program>())
        #expect(fresh.first?.routines.count == 4)
    }

    @Test func addRefusesADraftThatCannotBeSaved() throws {
        let program = try program(["Push"])

        #expect(try library.add(RoutineDraft(), to: program) == nil)

        #expect(names(in: program) == ["Push"])
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
    }

    // MARK: Reordering and removing

    @Test func reorderGivesThePositionsOfTheNewOrder() throws {
        let program = try program(["Push", "Pull", "Legs"])
        let routines = ProgramLibrary.orderedRoutines(of: program)

        #expect(try library.reorder([routines[2], routines[0], routines[1]], in: program))

        #expect(names(in: program) == ["Legs", "Push", "Pull"])
        #expect(positions(in: program) == [0, 1, 2])
    }

    @Test func reorderRefusesAListThatIsNotExactlyTheProgramsRoutines() throws {
        let program = try program(["Push", "Pull"])
        let routines = ProgramLibrary.orderedRoutines(of: program)
        let other = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))

        #expect(!(try library.reorder([routines[1]], in: program)))
        #expect(!(try library.reorder([routines[1], other], in: program)))
        #expect(!(try library.reorder([routines[1], routines[1]], in: program)))

        #expect(names(in: program) == ["Push", "Pull"])
        #expect(other.membership == nil)
    }

    @Test func removeMovesTheRoutineToMyRoutinesAndRenumbersTheRest() throws {
        let program = try program(["Push", "Pull", "Legs"])
        let pull = try routine("Pull", in: program)

        try library.remove(pull)

        #expect(names(in: program) == ["Push", "Legs"])
        #expect(positions(in: program) == [0, 1])
        #expect(pull.program == nil && pull.programPosition == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Routine>()) == 3)
    }

    @Test func deletingAProgramsRoutineRenumbersTheRest() throws {
        let program = try program(["Push", "Pull", "Legs"])

        try RoutineLibrary(context: context).delete(try routine("Push", in: program))

        #expect(names(in: program) == ["Pull", "Legs"])
        #expect(positions(in: program) == [0, 1])
    }

    // MARK: Up next

    @Test func upNextIsTheFirstRoutineWithNoWorkoutsAndNoneForAnEmptyProgram() throws {
        #expect(ProgramLibrary.upNext(in: try program(["Push", "Pull"]))?.name == "Push")
        #expect(ProgramLibrary.upNext(in: try program([])) == nil)
    }

    @Test func upNextFollowsTheNewestProgramWorkoutAndWrapsRound() throws {
        let program = try program(["Push", "Pull", "Legs"])

        try finishWorkout(of: try routine("Push", in: program), hours: 0)
        #expect(ProgramLibrary.upNext(in: program)?.name == "Pull")

        try finishWorkout(of: try routine("Legs", in: program), hours: 24)
        #expect(ProgramLibrary.upNext(in: program)?.name == "Push")
    }

    @Test func upNextIgnoresWorkoutsOutsideTheProgramAndInProgress() throws {
        let program = try program(["Push", "Pull", "Legs"])
        let mine = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))
        try finishWorkout(of: try routine("Push", in: program), hours: 0)

        try finishWorkout(of: mine, hours: 24)
        try finishWorkout(of: try routine("Pull", in: program), hours: 48, finished: false)

        #expect(ProgramLibrary.upNext(in: program)?.name == "Pull")
    }

    @Test func upNextFallsBackWhenTheNewestProgramWorkoutIsDeleted() throws {
        let program = try program(["Push", "Pull", "Legs"])
        try finishWorkout(of: try routine("Push", in: program), hours: 0)
        let newest = try finishWorkout(of: try routine("Pull", in: program), hours: 24)
        #expect(ProgramLibrary.upNext(in: program)?.name == "Legs")

        context.delete(newest)
        try context.save()

        #expect(ProgramLibrary.upNext(in: program)?.name == "Pull")
    }

    @Test func upNextFollowsTheOrderAfterAReorder() throws {
        let program = try program(["Push", "Pull", "Legs"])
        let routines = ProgramLibrary.orderedRoutines(of: program)
        try finishWorkout(of: routines[0], hours: 0)

        try library.reorder([routines[0], routines[2], routines[1]], in: program)

        #expect(ProgramLibrary.upNext(in: program)?.name == "Legs")
    }

    // MARK: Finish summary

    /// Starts the routine, checks off its first set and finishes, as the workout screen and finish sheet do.
    private func finishSummary(of routine: Routine) throws -> WorkoutSummary {
        let started = try #require(
            try RoutineStart(context: context).startWorkout(from: routine, at: start))
        let workoutExercise = try #require(started.workout.exercises.first)
        let set = try #require(WorkoutLog.orderedSets(of: workoutExercise).first)
        set.repsText = "8"
        try WorkoutLog(context: context).toggleCompleted(set)
        return try #require(
            try WorkoutLog(context: context).finish(
                started.workout, title: "", at: start.addingTimeInterval(3_600)))
    }

    @Test func finishingPushInPPLLeavesPullUpNext() throws {
        let program = try program(["Push", "Pull", "Legs"])

        let summary = try finishSummary(of: try routine("Push", in: program))

        #expect(summary.nextInProgram?.program == "PPL")
        #expect(summary.nextInProgram?.routine == "Pull")
    }

    @Test func finishingTheLastRoutineWrapsToTheFirst() throws {
        let program = try program(["Push", "Pull", "Legs"])

        let summary = try finishSummary(of: try routine("Legs", in: program))

        #expect(summary.nextInProgram?.routine == "Push")
    }

    @Test func finishingARoutineInNoProgramShowsNoNextLine() throws {
        let mine = try #require(
            try RoutineLibrary(context: context).save(try draft("Arms"), to: nil))

        let summary = try finishSummary(of: mine)

        #expect(summary.nextInProgram == nil)
    }

    /// A read-only store holding a program of Push, Pull and Legs, so every save fails.
    private func failingProgramStore() throws -> ReadOnlyStore {
        try ReadOnlyStore { context in
            let program = Program(name: "PPL", creationDate: start)
            context.insert(program)
            for (position, name) in ["Push", "Pull", "Legs"].enumerated() {
                let routine = Routine(name: name, creationDate: start)
                context.insert(routine)
                routine.membership = ProgramMembership(program: program, position: position)
            }
        }
    }

    private func expectProgramUnchanged(in context: ModelContext) throws {
        #expect(!context.hasChanges)
        let program = try #require(try context.fetch(FetchDescriptor<Program>()).first)
        let ordered = ProgramLibrary.orderedRoutines(of: program)
        #expect(ordered.map(\.name) == ["Push", "Pull", "Legs"])
        #expect(ordered.map { $0.membership?.position } == [0, 1, 2])
    }

    @Test func aFailedRemoveLeavesTheProgramAsItWas() throws {
        let store = try failingProgramStore()
        defer { store.remove() }
        let program = try #require(try store.context.fetch(FetchDescriptor<Program>()).first)
        let push = try #require(ProgramLibrary.orderedRoutines(of: program).first)

        #expect(throws: (any Error).self) {
            try ProgramLibrary(context: store.context).remove(push)
        }

        try expectProgramUnchanged(in: store.context)
    }

    @Test func aFailedDeleteOfAProgramRoutineLeavesTheProgramAsItWas() throws {
        let store = try failingProgramStore()
        defer { store.remove() }
        let program = try #require(try store.context.fetch(FetchDescriptor<Program>()).first)
        let push = try #require(ProgramLibrary.orderedRoutines(of: program).first)

        #expect(throws: (any Error).self) {
            try RoutineLibrary(context: store.context).delete(push)
        }

        try expectProgramUnchanged(in: store.context)
    }
}
