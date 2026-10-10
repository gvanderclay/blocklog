import Foundation
import SwiftData

/// Groups and filters the exercises the picker lists, and creates custom exercises.
@MainActor
struct ExerciseCatalog {
    /// Why a name can't be saved for a new exercise.
    enum NameProblem: Equatable {
        case empty
        case duplicate
    }

    /// The exercises of one muscle group, sorted by name.
    struct Section: Identifiable {
        let muscleGroup: MuscleGroup
        let exercises: [Exercise]

        var id: MuscleGroup { muscleGroup }
    }

    let context: ModelContext

    /// The exercises whose name contains the query, ignoring case and diacritics, that use the equipment
    /// (nil for all) and are of one of the types, grouped by muscle group in `MuscleGroup` order. Each group is
    /// sorted by name, and groups with no matching exercise are left out.
    static func sections(
        from exercises: [Exercise], matching query: String, equipment: Equipment?,
        types: [ExerciseType] = ExerciseType.allCases
    ) -> [Section] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = exercises.filter { exercise in
            (equipment == nil || exercise.equipment == equipment)
                && types.contains(exercise.type)
                && (query.isEmpty || exercise.name.localizedStandardContains(query))
        }
        return MuscleGroup.allCases.compactMap { group in
            let inGroup = matches.filter { $0.muscleGroup == group }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return inGroup.isEmpty ? nil : Section(muscleGroup: group, exercises: inGroup)
        }
    }

    /// The name trimmed, and the key two names are compared by: the trimmed name ignoring case.
    static func normalized(_ name: String) -> (trimmed: String, key: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed, trimmed.folding(options: .caseInsensitive, locale: nil))
    }

    /// Why the name can't name a new exercise alongside the existing ones, or nil when it can. The name is
    /// trimmed first, and it is a duplicate when an existing name matches it ignoring case.
    static func nameProblem(for name: String, among exercises: [Exercise]) -> NameProblem? {
        let name = normalized(name)
        if name.trimmed.isEmpty { return .empty }
        let taken = exercises.contains { normalized($0.name).key == name.key }
        return taken ? .duplicate : nil
    }

    /// Creates a custom exercise with the trimmed name and saves it. Nil, creating nothing, when the name
    /// has a problem.
    func createCustomExercise(
        named name: String, muscleGroup: MuscleGroup, equipment: Equipment, type: ExerciseType
    ) throws -> Exercise? {
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        guard Self.nameProblem(for: name, among: existing) == nil else { return nil }
        let exercise = Exercise(
            name: Self.normalized(name).trimmed, muscleGroup: muscleGroup,
            equipment: equipment, type: type, isCustom: true)
        context.insert(exercise)
        try context.saveOrRollBack()
        return exercise
    }
}
