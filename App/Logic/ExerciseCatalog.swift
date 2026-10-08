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

    // TODO(ticket 08): offer duration once its sets log seconds instead of reps.
    /// The kinds a custom exercise can take: the ones a workout can log now.
    static let creatableKinds: [ExerciseKind] = [.weightReps, .bodyweightReps]

    let context: ModelContext

    /// The exercises whose name contains the query, ignoring case and diacritics, and that use the
    /// equipment (nil for all), grouped by muscle group in `MuscleGroup` order. Each group is sorted by
    /// name, and groups with no matching exercise are left out.
    static func sections(
        from exercises: [Exercise], matching query: String, equipment: Equipment?
    ) -> [Section] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = exercises.filter { exercise in
            (equipment == nil || exercise.equipment == equipment)
                && (query.isEmpty || exercise.name.localizedStandardContains(query))
        }
        return MuscleGroup.allCases.compactMap { group in
            let inGroup = matches.filter { $0.muscleGroup == group }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return inGroup.isEmpty ? nil : Section(muscleGroup: group, exercises: inGroup)
        }
    }

    /// Why the name can't name a new exercise alongside the existing ones, or nil when it can. The name is
    /// trimmed first, and it is a duplicate when an existing name matches it ignoring case.
    static func nameProblem(for name: String, among exercises: [Exercise]) -> NameProblem? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .empty }
        let taken = exercises.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        return taken ? .duplicate : nil
    }

    /// Creates a custom exercise with the trimmed name and saves it. Nil, creating nothing, when the name
    /// has a problem or the kind isn't one of `creatableKinds`.
    func createCustomExercise(
        named name: String, muscleGroup: MuscleGroup, equipment: Equipment, kind: ExerciseKind
    ) throws -> Exercise? {
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        guard Self.nameProblem(for: name, among: existing) == nil,
            Self.creatableKinds.contains(kind)
        else { return nil }
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines), muscleGroup: muscleGroup,
            equipment: equipment, kind: kind, isCustom: true)
        context.insert(exercise)
        try context.save()
        return exercise
    }
}
