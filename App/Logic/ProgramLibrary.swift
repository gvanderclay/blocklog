import Foundation
import SwiftData

/// Creates, changes and deletes programs, and works out up next. Every change saves at once and keeps each
/// program's positions 0…n−1. A routine leaving a program, or whose program is deleted, moves to My
/// Routines.
@MainActor
struct ProgramLibrary {
    let context: ModelContext

    /// The routines in no program (My Routines), sorted by name. Views use it in `@Query`.
    static var myRoutines: FetchDescriptor<Routine> {
        FetchDescriptor(
            predicate: #Predicate { $0.program == nil }, sortBy: [SortDescriptor(\.name)])
    }

    /// Every program, sorted by name. Views use it in `@Query`.
    static var programsByName: FetchDescriptor<Program> {
        FetchDescriptor(sortBy: [SortDescriptor(\.name)])
    }

    /// The program's routines in position order.
    static func orderedRoutines(of program: Program) -> [Routine] {
        program.routines
            .compactMap { routine in routine.membership.map { (routine, $0.position) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// The routine after the routine of the program's newest finished workout, wrapping round; the first
    /// routine when none of its routines has a finished workout; nil for an empty program. Workouts of
    /// routines outside the program play no part.
    static func upNext(in program: Program) -> Routine? {
        let routines = orderedRoutines(of: program)
        let newest = routines.indices
            .flatMap { index in
                routines[index].workouts.filter { $0.endDate != nil }.map { (index, $0.startDate) }
            }
            .max { $0.1 < $1.1 }
        guard let newest else { return routines.first }
        return routines[(newest.0 + 1) % routines.count]
    }

    /// The program of the workout's routine and the routine up next in it, for the finish summary. Nil when
    /// the workout has no routine or the routine is in no program. Read it after the finish is saved.
    static func nextInProgram(after workout: Workout) -> NextInProgram? {
        guard let program = workout.routine?.membership?.program,
            let routine = upNext(in: program)
        else { return nil }
        return NextInProgram(program: program.name, routine: routine.name)
    }

    /// Gives the routines the positions of their place in `ordered`, in `program`. Doesn't save.
    static func place(_ ordered: [Routine], in program: Program) {
        for (position, routine) in ordered.enumerated() {
            routine.membership = ProgramMembership(program: program, position: position)
        }
    }

    /// Creates a program with the trimmed name, holding a new routine for each draft that can be saved, in
    /// order, and saves once. Nil, changing nothing, when the name is blank.
    @discardableResult
    func create(named name: String, holding drafts: [RoutineDraft] = [], at date: Date = .now)
        throws -> Program?
    {
        let name = ExerciseCatalog.normalized(name).trimmed
        guard !name.isEmpty else { return nil }
        let program = Program(name: name, creationDate: date)
        context.insert(program)
        let routines = drafts.filter(\.canSave).map {
            RoutineLibrary(context: context).write($0, to: nil, at: date)
        }
        Self.place(routines, in: program)
        try context.saveOrRollBack()
        return program
    }

    /// Renames the program to the trimmed name and saves. False, changing nothing, when the name is blank.
    @discardableResult
    func rename(_ program: Program, to name: String) throws -> Bool {
        let name = ExerciseCatalog.normalized(name).trimmed
        guard !name.isEmpty else { return false }
        program.name = name
        try context.saveOrRollBack()
        return true
    }

    /// Deletes the program and saves. Its routines move to My Routines.
    func delete(_ program: Program) throws {
        for routine in program.routines { routine.membership = nil }
        context.delete(program)
        try context.saveOrRollBack()
    }

    /// Saves the draft as a new routine at the end of the program. A copy of a routine in My Routines is
    /// `RoutineDraft(routine:)`, and a starter routine's is `StarterLibrary.draft(of:)`. Nil, changing
    /// nothing, when the draft can't be saved.
    @discardableResult
    func add(_ draft: RoutineDraft, to program: Program, at date: Date = .now) throws
        -> Routine?
    {
        guard draft.canSave else { return nil }
        let ordered = Self.orderedRoutines(of: program)
        let routine = RoutineLibrary(context: context).write(draft, to: nil, at: date)
        Self.place(ordered + [routine], in: program)
        try context.saveOrRollBack()
        return routine
    }

    /// Gives the program's routines the order of `ordered` and saves. False, changing nothing, unless
    /// `ordered` holds exactly the program's routines.
    @discardableResult
    func reorder(_ ordered: [Routine], in program: Program) throws -> Bool {
        let current = Self.orderedRoutines(of: program)
        guard ordered.count == current.count,
            Set(ordered.map(ObjectIdentifier.init)) == Set(current.map(ObjectIdentifier.init))
        else { return false }
        Self.place(ordered, in: program)
        try context.saveOrRollBack()
        return true
    }

    /// Moves the routine out of its program to My Routines, renumbers the routines left, and saves.
    func remove(_ routine: Routine) throws {
        guard let program = routine.membership?.program else { return }
        let others = Self.orderedRoutines(of: program).filter { $0 !== routine }
        routine.membership = nil
        Self.place(others, in: program)
        try context.saveOrRollBack()
    }
}

/// The "Next in <program>: <routine>" line of the finish summary.
@MainActor
struct NextInProgram {
    let program: String
    let routine: String
}
