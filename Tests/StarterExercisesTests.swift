import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled starter list through the seeded store.
@MainActor
struct StarterExercisesTests {
    /// The stretches `docs/research/stretch-routines.md` holds on each side.
    static let perSideStretches: Set<String> = [
        "Hip Flexor Stretch", "Figure-Four Stretch", "Seated Side Bend", "Standing Active Twist",
        "Supine Hamstring Stretch", "Knee-to-Chest Stretch", "Cross-Body Shoulder Stretch",
        "Overhead Triceps Stretch", "Neck Side Bend",
    ]

    @Test func seedsTheExercisesAndStretchesCoveringEveryGroupEquipmentAndType() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())

        #expect(exercises.count == 86)
        #expect(Set(exercises.map(\.muscleGroup)) == Set(MuscleGroup.allCases))
        #expect(Set(exercises.map(\.equipment)) == Set(Equipment.allCases))
        #expect(Set(exercises.map(\.type)) == Set(ExerciseType.allCases))
        #expect(Set(exercises.map(\.name)).count == exercises.count)
        #expect(exercises.allSatisfy { !$0.isCustom })
    }

    @Test func stretchesAreDurationExercisesMarkedPerSideWhereTheResearchSays() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let stretches = try container.mainContext.fetch(FetchDescriptor<Exercise>())
            .filter { $0.muscleGroup == .stretching }

        #expect(stretches.count == 20)
        #expect(stretches.allSatisfy { $0.type == .duration && $0.equipment == .bodyweight })
        #expect(Set(stretches.filter { $0.isPerSide == true }.map(\.name)) == Self.perSideStretches)
        #expect(StarterExercises.perSideNames == Self.perSideStretches)
    }

    @Test func seedingAgainChangesNothing() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let before = try Backup(context: container.mainContext).export()
        try StarterExercises.seedMissing(container.mainContext)
        #expect(try Backup(context: container.mainContext).export(at: before.exportedAt) == before)
    }

    @Test func seedingAStoreThatPredatesTheStretchesAddsOnlyTheMissingStarters() throws {
        let fixture = try FixtureStore("before-32a")
        defer { fixture.remove() }
        let context = fixture.context
        let before = try Backup(context: context).export()

        try StarterExercises.seedMissing(context)

        let after = try Backup(context: context).export(at: before.exportedAt)
        let beforeIDs = Set(before.exercises.map(\.id))
        // Every record already stored is unchanged.
        #expect(after.exercises.filter { beforeIDs.contains($0.id) } == before.exercises)
        #expect(after.routines == before.routines)
        #expect(after.workouts == before.workouts)
        #expect(after.programs == before.programs)
        // The stretches are added, except Cat-Cow, which the store already has as the custom "cat-cow".
        let added = after.exercises.filter { !beforeIDs.contains($0.id) }
        #expect(added.count == 19)
        #expect(
            added.allSatisfy { $0.muscleGroup == MuscleGroup.stretching.rawValue && !$0.isCustom })
        #expect(!added.contains { $0.name == "Cat-Cow" })
        // The additions are saved, not left pending.
        #expect(!context.hasChanges)
    }
}
