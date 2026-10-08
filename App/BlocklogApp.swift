import SwiftData
import SwiftUI

@main
struct BlocklogApp: App {
    private let container: ModelContainer
    private let uiTesting = CommandLine.arguments.contains("-ui-testing")

    init() {
        // XCTest waits for UIKit animations to finish after every tap; with them off, UI tests don't idle.
        if uiTesting { UIView.setAnimationsEnabled(false) }
        do {
            container = try Self.makeContainer(inMemory: uiTesting)
        } catch {
            fatalError("Could not open the store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .transaction { if uiTesting { $0.disablesAnimations = true } }
        }
        .modelContainer(container)
    }

    /// The store with every model, seeded with the starter exercises when it has none.
    /// In memory for UI tests (the `-ui-testing` launch argument) and unit tests; on disk otherwise.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, WorkoutSet.self, Routine.self,
            RoutineExercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        try StarterExercises.seedIfEmpty(container.mainContext)
        return container
    }
}
