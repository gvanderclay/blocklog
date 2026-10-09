import Foundation
import SwiftData

/// The bundled home exercises in `starter-exercises.json`, seeded into an empty store.
@MainActor
enum StarterExercises {
    /// One entry of the JSON file.
    private struct Entry: Decodable {
        let name: String
        let muscleGroup: MuscleGroup
        let equipment: Equipment
        let kind: ExerciseKind

        func makeExercise() -> Exercise {
            Exercise(name: name, muscleGroup: muscleGroup, equipment: equipment, kind: kind)
        }
    }

    private static func entries() throws -> [Entry] {
        guard let url = Bundle.main.url(forResource: "starter-exercises", withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    /// Inserts every starter exercise and saves, only when the store has no exercises.
    static func seedIfEmpty(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Exercise>()) == 0 else { return }
        for entry in try entries() {
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
