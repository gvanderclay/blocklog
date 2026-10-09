import SwiftData
import SwiftUI

@main
struct BlocklogApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Self.makeContainer(inMemory: false)
        } catch {
            fatalError("Could not open the store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    /// The store with every model, seeded with the starter exercises when it has none.
    /// In memory for unit tests; on disk otherwise.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, WorkoutSet.self, Routine.self,
            RoutineExercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        try StarterExercises.seedIfEmpty(container.mainContext)
        return container
    }
}
