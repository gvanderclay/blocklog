import SwiftData
import Testing

@testable import Blocklog

@MainActor
struct SetNumberingTests {
    @Test func warmUpsDoNotAdvanceTheCount() {
        let types: [SetType] = [.warmUp, .warmUp, .normal, .drop, .failure]
        #expect(SetNumbering.labels(for: types) == ["W", "W", "1", "D", "F"])
        #expect(SetNumbering.countedNumbers(for: types) == [nil, nil, 1, 2, 3])
    }

    @Test func everyTypeButWarmUpIsCounted() {
        #expect(!SetNumbering.isCounted(.warmUp))
        for type in [SetType.normal, .drop, .failure] {
            #expect(SetNumbering.isCounted(type))
        }
    }

    @Test func spokenNamesCountWarmUpsApartFromCountedSets() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let log = WorkoutLog(context: container.mainContext)
        let workout = try #require(try log.startEmptyWorkout())
        let bench = try #require(
            container.mainContext.fetch(FetchDescriptor<Exercise>()).first)
        try log.addExercise(bench, to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        let types: [SetType] = [.warmUp, .warmUp, .normal, .failure, .drop]
        for _ in 1..<types.count { try log.addSet(to: workoutExercise) }
        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        for (set, type) in zip(sets, types) { try log.setType(type, of: set) }

        #expect(
            sets.map(SetNumbering.spokenName(of:)) == [
                "Warm-up 1", "Warm-up 2", "Set 1", "Failure set 2", "Drop set 3",
            ])
    }
}
