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
    }

    /// Inserts every starter exercise and saves, only when the store has no exercises.
    static func seedIfEmpty(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Exercise>()) == 0 else { return }
        guard let url = Bundle.main.url(forResource: "starter-exercises", withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
        for entry in entries {
            context.insert(
                Exercise(
                    name: entry.name, muscleGroup: entry.muscleGroup, equipment: entry.equipment,
                    kind: entry.kind))
        }
        try context.save()
    }
}
