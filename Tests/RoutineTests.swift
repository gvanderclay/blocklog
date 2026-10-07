import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the routine's delete rules against an in-memory store seeded with the starters.
@MainActor
struct RoutineTests {
    @Test func deletingARoutineDeletesItsRoutineExercisesAndKeepsItsWorkouts() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let exercise = try #require(try context.fetch(FetchDescriptor<Exercise>()).first)
        let routine = Routine(name: "Push Day", creationDate: .now)
        context.insert(routine)
        routine.exercises.append(
            RoutineExercise(exercise: exercise, position: 0, plannedSetTypes: [.normal, .normal]))
        let workout = Workout(title: "Push Day", startDate: .now, endDate: .now, routine: routine)
        context.insert(workout)
        let workoutExercise = WorkoutExercise(exercise: exercise, position: 0)
        workout.exercises.append(workoutExercise)
        workoutExercise.sets.append(
            WorkoutSet(position: 0, weight: 20, reps: 10, isCompleted: true))
        try context.save()
        let workoutID = workout.id

        context.delete(routine)
        try context.save()

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Routine>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<RoutineExercise>()) == 0)
        let kept = try #require(
            try fresh.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID }))
                .first)
        #expect(kept.routine == nil)
        #expect(kept.exercises.first?.sets.map(\.reps) == [10])
    }
}
