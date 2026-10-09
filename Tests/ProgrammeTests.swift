import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the programme library and up next against an in-memory store seeded with the starters.
@MainActor
struct ProgrammeTests {
    let container: ModelContainer
    let library: ProgrammeLibrary
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        library = ProgrammeLibrary(context: container.mainContext)
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

    /// A programme holding a new routine for each name, in order.
    private func programme(_ names: [String]) throws -> Programme {
        try #require(try library.create(named: "PPL", holding: names.map(draft)))
    }

    private func names(in programme: Programme) -> [String] {
        ProgrammeLibrary.orderedRoutines(of: programme).map(\.name)
    }

    private func positions(in programme: Programme) -> [Int?] {
        ProgrammeLibrary.orderedRoutines(of: programme).map { $0.membership?.position }
    }

    private func routine(_ name: String, in programme: Programme) throws -> Routine {
        try #require(ProgrammeLibrary.orderedRoutines(of: programme).first { $0.name == name })
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

    // MARK: Create, rename and delete

    @Test func createSavesATrimmedNameAndRefusesABlankOne() throws {
        let programme = try #require(try library.create(named: "  Push Pull Legs \n", at: start))

        let fresh = try ModelContext(container).fetch(FetchDescriptor<Programme>())
        #expect(fresh.map(\.name) == ["Push Pull Legs"])
        #expect(programme.creationDate == start)
        #expect(programme.routines.isEmpty)
        #expect(try library.create(named: " \n ") == nil)
        #expect(try context.fetchCount(FetchDescriptor<Programme>()) == 1)
    }

    @Test func renameSavesATrimmedNameAndRefusesABlankOne() throws {
        let programme = try programme([])

        #expect(try library.rename(programme, to: " Upper/Lower "))
        #expect(!(try library.rename(programme, to: "   ")))

        let fresh = try ModelContext(container).fetch(FetchDescriptor<Programme>())
        #expect(fresh.map(\.name) == ["Upper/Lower"])
    }

    @Test func deleteMovesItsRoutinesToMyRoutines() throws {
        let programme = try programme(["Push", "Pull"])

        try library.delete(programme)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Programme>()) == 0)
        let routines = try fresh.fetch(RoutineLibrary.routinesByName)
        #expect(routines.map(\.name) == ["Pull", "Push"])
        #expect(routines.allSatisfy { $0.programme == nil && $0.programmePosition == nil })
    }

    // MARK: Adding

    @Test func createHoldsTheDraftsInOrder() throws {
        let programme = try programme(["Push", "Pull", "Legs"])

        #expect(names(in: programme) == ["Push", "Pull", "Legs"])
        #expect(positions(in: programme) == [0, 1, 2])
    }

    @Test func addCopiesFromMyRoutinesAStarterRoutineOrANewRoutineToTheEnd() throws {
        let programme = try programme(["Push"])
        let mine = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))
        let goldenSix = try #require(try StarterRoutine.load().first { $0.name == "Golden Six" })

        let copy = try #require(try library.add(RoutineDraft(routine: mine), to: programme))
        try library.add(StarterLibrary(context: context).draft(of: goldenSix), to: programme)
        try library.add(draft("Legs"), to: programme)

        #expect(names(in: programme) == ["Push", "Arms", "Golden Six", "Legs"])
        #expect(positions(in: programme) == [0, 1, 2, 3])
        #expect(copy !== mine)
        #expect(mine.membership == nil)
        #expect(RoutineLibrary.orderedExercises(of: copy).count == 1)
        let fresh = try ModelContext(container).fetch(FetchDescriptor<Programme>())
        #expect(fresh.first?.routines.count == 4)
    }

    @Test func addRefusesADraftThatCannotBeSaved() throws {
        let programme = try programme(["Push"])

        #expect(try library.add(RoutineDraft(), to: programme) == nil)

        #expect(names(in: programme) == ["Push"])
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
    }

    // MARK: Reordering and removing

    @Test func reorderGivesThePositionsOfTheNewOrder() throws {
        let programme = try programme(["Push", "Pull", "Legs"])
        let routines = ProgrammeLibrary.orderedRoutines(of: programme)

        #expect(try library.reorder([routines[2], routines[0], routines[1]], in: programme))

        #expect(names(in: programme) == ["Legs", "Push", "Pull"])
        #expect(positions(in: programme) == [0, 1, 2])
    }

    @Test func reorderRefusesAListThatIsNotExactlyTheProgrammesRoutines() throws {
        let programme = try programme(["Push", "Pull"])
        let routines = ProgrammeLibrary.orderedRoutines(of: programme)
        let other = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))

        #expect(!(try library.reorder([routines[1]], in: programme)))
        #expect(!(try library.reorder([routines[1], other], in: programme)))
        #expect(!(try library.reorder([routines[1], routines[1]], in: programme)))

        #expect(names(in: programme) == ["Push", "Pull"])
        #expect(other.membership == nil)
    }

    @Test func removeMovesTheRoutineToMyRoutinesAndRenumbersTheRest() throws {
        let programme = try programme(["Push", "Pull", "Legs"])
        let pull = try routine("Pull", in: programme)

        try library.remove(pull)

        #expect(names(in: programme) == ["Push", "Legs"])
        #expect(positions(in: programme) == [0, 1])
        #expect(pull.programme == nil && pull.programmePosition == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Routine>()) == 3)
    }

    @Test func deletingAProgrammesRoutineRenumbersTheRest() throws {
        let programme = try programme(["Push", "Pull", "Legs"])

        try RoutineLibrary(context: context).delete(try routine("Push", in: programme))

        #expect(names(in: programme) == ["Pull", "Legs"])
        #expect(positions(in: programme) == [0, 1])
    }

    // MARK: Up next

    @Test func upNextIsTheFirstRoutineWithNoWorkoutsAndNoneForAnEmptyProgramme() throws {
        #expect(ProgrammeLibrary.upNext(in: try programme(["Push", "Pull"]))?.name == "Push")
        #expect(ProgrammeLibrary.upNext(in: try programme([])) == nil)
    }

    @Test func upNextFollowsTheNewestProgrammeWorkoutAndWrapsRound() throws {
        let programme = try programme(["Push", "Pull", "Legs"])

        try finishWorkout(of: try routine("Push", in: programme), hours: 0)
        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Pull")

        try finishWorkout(of: try routine("Legs", in: programme), hours: 24)
        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Push")
    }

    @Test func upNextIgnoresWorkoutsOutsideTheProgrammeAndInProgress() throws {
        let programme = try programme(["Push", "Pull", "Legs"])
        let mine = try #require(try RoutineLibrary(context: context).save(draft("Arms"), to: nil))
        try finishWorkout(of: try routine("Push", in: programme), hours: 0)

        try finishWorkout(of: mine, hours: 24)
        try finishWorkout(of: try routine("Pull", in: programme), hours: 48, finished: false)

        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Pull")
    }

    @Test func upNextFallsBackWhenTheNewestProgrammeWorkoutIsDeleted() throws {
        let programme = try programme(["Push", "Pull", "Legs"])
        try finishWorkout(of: try routine("Push", in: programme), hours: 0)
        let newest = try finishWorkout(of: try routine("Pull", in: programme), hours: 24)
        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Legs")

        context.delete(newest)
        try context.save()

        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Pull")
    }

    @Test func upNextFollowsTheOrderAfterAReorder() throws {
        let programme = try programme(["Push", "Pull", "Legs"])
        let routines = ProgrammeLibrary.orderedRoutines(of: programme)
        try finishWorkout(of: routines[0], hours: 0)

        try library.reorder([routines[0], routines[2], routines[1]], in: programme)

        #expect(ProgrammeLibrary.upNext(in: programme)?.name == "Legs")
    }

    /// A read-only store holding a programme of Push, Pull and Legs, so every save fails.
    private func failingProgrammeStore() throws -> ReadOnlyStore {
        try ReadOnlyStore { context in
            let programme = Programme(name: "PPL", creationDate: start)
            context.insert(programme)
            for (position, name) in ["Push", "Pull", "Legs"].enumerated() {
                let routine = Routine(name: name, creationDate: start)
                context.insert(routine)
                routine.membership = ProgrammeMembership(programme: programme, position: position)
            }
        }
    }

    private func expectProgrammeUnchanged(in context: ModelContext) throws {
        #expect(!context.hasChanges)
        let programme = try #require(try context.fetch(FetchDescriptor<Programme>()).first)
        let ordered = ProgrammeLibrary.orderedRoutines(of: programme)
        #expect(ordered.map(\.name) == ["Push", "Pull", "Legs"])
        #expect(ordered.map { $0.membership?.position } == [0, 1, 2])
    }

    @Test func aFailedRemoveLeavesTheProgrammeAsItWas() throws {
        let store = try failingProgrammeStore()
        defer { store.remove() }
        let programme = try #require(try store.context.fetch(FetchDescriptor<Programme>()).first)
        let push = try #require(ProgrammeLibrary.orderedRoutines(of: programme).first)

        #expect(throws: (any Error).self) {
            try ProgrammeLibrary(context: store.context).remove(push)
        }

        try expectProgrammeUnchanged(in: store.context)
    }

    @Test func aFailedDeleteOfAProgrammeRoutineLeavesTheProgrammeAsItWas() throws {
        let store = try failingProgrammeStore()
        defer { store.remove() }
        let programme = try #require(try store.context.fetch(FetchDescriptor<Programme>()).first)
        let push = try #require(ProgrammeLibrary.orderedRoutines(of: programme).first)

        #expect(throws: (any Error).self) {
            try RoutineLibrary(context: store.context).delete(push)
        }

        try expectProgrammeUnchanged(in: store.context)
    }
}
