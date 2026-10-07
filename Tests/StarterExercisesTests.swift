import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled starter list through the seeded store.
@MainActor
struct StarterExercisesTests {
    @Test func seedsAboutSixtyExercisesCoveringEveryGroupEquipmentAndKind() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())

        #expect((55...70).contains(exercises.count))
        #expect(Set(exercises.map(\.muscleGroup)) == Set(MuscleGroup.allCases))
        #expect(Set(exercises.map(\.equipment)) == Set(Equipment.allCases))
        #expect(Set(exercises.map(\.kind)) == Set(ExerciseKind.allCases))
        #expect(Set(exercises.map(\.name)).count == exercises.count)
        #expect(exercises.allSatisfy { !$0.isCustom })
    }

    @Test func seedsOnlyAnEmptyStore() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let count = try container.mainContext.fetchCount(FetchDescriptor<Exercise>())
        try StarterExercises.seedIfEmpty(container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()) == count)
    }
}
