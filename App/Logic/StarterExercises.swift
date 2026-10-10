import Foundation
import SwiftData

/// The bundled home exercises and stretches in `starter-exercises.json`, seeded into the store.
@MainActor
enum StarterExercises {
    /// One entry of the JSON file.
    private struct Entry: Decodable {
        let name: String
        let muscleGroup: MuscleGroup
        let equipment: Equipment
        let type: ExerciseType
        /// Written only for a per-side exercise.
        let isPerSide: Bool?

        func makeExercise() -> Exercise {
            Exercise(
                name: name, muscleGroup: muscleGroup, equipment: equipment, type: type,
                isPerSide: isPerSide)
        }
    }

    private static func entries() throws -> [Entry] {
        guard let url = Bundle.main.url(forResource: "starter-exercises", withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    /// The names of the starter exercises done on each side, or none when the file can't be read (a unit test
    /// checks that it can).
    static let perSideNames: Set<String> = Set(
        ((try? entries()) ?? []).filter { $0.isPerSide == true }.map(\.name))

    /// Inserts each starter exercise whose name, ignoring case, no stored exercise has, and saves. Stored
    /// exercises are left as they are, so a store seeded before new starters were added gains only those.
    static func seedMissing(_ context: ModelContext) throws {
        let stored = Set(
            try context.fetch(FetchDescriptor<Exercise>()).map {
                ExerciseCatalog.normalized($0.name).key
            })
        let missing = try entries().filter {
            !stored.contains(ExerciseCatalog.normalized($0.name).key)
        }
        guard !missing.isEmpty else { return }
        for entry in missing {
            context.insert(entry.makeExercise())
        }
        try context.saveOrRollBack()
    }

    /// The stored exercises with these names, matched ignoring case, keyed by the name asked for. A starter
    /// exercise the store lacks (deleted, or added to the starters after the store was seeded) is inserted
    /// without saving; the caller saves. A name that is neither stored nor a starter is left out.
    static func exercises(named names: [String], in context: ModelContext) throws -> [String:
        Exercise]
    {
        let stored = try context.fetch(FetchDescriptor<Exercise>())
        var byKey: [String: Exercise] = [:]
        for exercise in stored where byKey[ExerciseCatalog.normalized(exercise.name).key] == nil {
            byKey[ExerciseCatalog.normalized(exercise.name).key] = exercise
        }
        let starters = try entries()
        var result: [String: Exercise] = [:]
        for name in names {
            let key = ExerciseCatalog.normalized(name).key
            if byKey[key] == nil,
                let entry = starters.first(where: { ExerciseCatalog.normalized($0.name).key == key }
                )
            {
                let exercise = entry.makeExercise()
                context.insert(exercise)
                byKey[key] = exercise
            }
            result[name] = byKey[key]
        }
        return result
    }
}
