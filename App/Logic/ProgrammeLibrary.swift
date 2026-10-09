import Foundation
import SwiftData

/// Creates, changes and deletes programmes, and works out up next. Every change saves at once and keeps each
/// programme's positions 0…n−1. A routine leaving a programme, or whose programme is deleted, moves to My
/// Routines.
@MainActor
struct ProgrammeLibrary {
    let context: ModelContext

    /// The routines in no programme (My Routines), sorted by name. Views use it in `@Query`.
    static var myRoutines: FetchDescriptor<Routine> {
        FetchDescriptor(
            predicate: #Predicate { $0.programme == nil }, sortBy: [SortDescriptor(\.name)])
    }

    /// Every programme, sorted by name. Views use it in `@Query`.
    static var programmesByName: FetchDescriptor<Programme> {
        FetchDescriptor(sortBy: [SortDescriptor(\.name)])
    }

    /// The programme's routines in position order.
    static func orderedRoutines(of programme: Programme) -> [Routine] {
        programme.routines
            .compactMap { routine in routine.membership.map { (routine, $0.position) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// The routine after the routine of the programme's newest finished workout, wrapping round; the first
    /// routine when none of its routines has a finished workout; nil for an empty programme. Workouts of
    /// routines outside the programme play no part.
    static func upNext(in programme: Programme) -> Routine? {
        let routines = orderedRoutines(of: programme)
        let newest = routines.indices
            .flatMap { index in
                routines[index].workouts.filter { $0.endDate != nil }.map { (index, $0.startDate) }
            }
            .max { $0.1 < $1.1 }
        guard let newest else { return routines.first }
        return routines[(newest.0 + 1) % routines.count]
    }

    /// Gives the routines the positions of their place in `ordered`, in `programme`. Doesn't save.
    static func place(_ ordered: [Routine], in programme: Programme) {
        for (position, routine) in ordered.enumerated() {
            routine.membership = ProgrammeMembership(programme: programme, position: position)
        }
    }

    /// Creates a programme with the trimmed name, holding a new routine for each draft that can be saved, in
    /// order, and saves once. Nil, changing nothing, when the name is blank.
    @discardableResult
    func create(named name: String, holding drafts: [RoutineDraft] = [], at date: Date = .now)
        throws -> Programme?
    {
        let name = ExerciseCatalog.normalized(name).trimmed
        guard !name.isEmpty else { return nil }
        let programme = Programme(name: name, creationDate: date)
        context.insert(programme)
        let routines = drafts.filter(\.canSave).map {
            RoutineLibrary(context: context).write($0, to: nil, at: date)
        }
        Self.place(routines, in: programme)
        try context.saveOrRollBack()
        return programme
    }

    /// Renames the programme to the trimmed name and saves. False, changing nothing, when the name is blank.
    @discardableResult
    func rename(_ programme: Programme, to name: String) throws -> Bool {
        let name = ExerciseCatalog.normalized(name).trimmed
        guard !name.isEmpty else { return false }
        programme.name = name
        try context.saveOrRollBack()
        return true
    }

    /// Deletes the programme and saves. Its routines move to My Routines.
    func delete(_ programme: Programme) throws {
        for routine in programme.routines { routine.membership = nil }
        context.delete(programme)
        try context.saveOrRollBack()
    }

    /// Saves the draft as a new routine at the end of the programme. A copy of a routine in My Routines is
    /// `RoutineDraft(routine:)`, and a starter routine's is `StarterLibrary.draft(of:)`. Nil, changing
    /// nothing, when the draft can't be saved.
    @discardableResult
    func add(_ draft: RoutineDraft, to programme: Programme, at date: Date = .now) throws
        -> Routine?
    {
        guard draft.canSave else { return nil }
        let ordered = Self.orderedRoutines(of: programme)
        let routine = RoutineLibrary(context: context).write(draft, to: nil, at: date)
        Self.place(ordered + [routine], in: programme)
        try context.saveOrRollBack()
        return routine
    }

    /// Gives the programme's routines the order of `ordered` and saves. False, changing nothing, unless
    /// `ordered` holds exactly the programme's routines.
    @discardableResult
    func reorder(_ ordered: [Routine], in programme: Programme) throws -> Bool {
        let current = Self.orderedRoutines(of: programme)
        guard ordered.count == current.count,
            Set(ordered.map(ObjectIdentifier.init)) == Set(current.map(ObjectIdentifier.init))
        else { return false }
        Self.place(ordered, in: programme)
        try context.saveOrRollBack()
        return true
    }

    /// Moves the routine out of its programme to My Routines, renumbers the routines left, and saves.
    func remove(_ routine: Routine) throws {
        guard let programme = routine.membership?.programme else { return }
        let others = Self.orderedRoutines(of: programme).filter { $0 !== routine }
        routine.membership = nil
        Self.place(others, in: programme)
        try context.saveOrRollBack()
    }
}
