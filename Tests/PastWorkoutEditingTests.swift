import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Editing and deleting finished workouts, against an in-memory store seeded with the starters.
@MainActor
struct PastWorkoutEditingTests {
    /// Held so the store outlives the context.
    let container: ModelContainer
    let context: ModelContext
    let log: WorkoutLog
    let editing: PastWorkoutEditing

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        context = container.mainContext
        log = WorkoutLog(context: context)
        editing = PastWorkoutEditing(context: context)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    /// A finished workout of one bench-press set, 15 lb × `reps`, started `daysAgo` days before a fixed day.
    private func finished(reps: Int, daysAgo: Int = 0) throws -> Workout {
        let start = Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(
            Double(-daysAgo) * 86400)
        let workout = try #require(try log.startEmptyWorkout(at: start))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        try log.setWeight(15, of: set)
        set.repsText = String(reps)
        try log.toggleCompleted(set)
        _ = try log.finish(workout, title: "Push", at: start.addingTimeInterval(3600))
        return workout
    }

    /// The previous value a new workout's first bench-press set shows.
    private func previousValue() throws -> SetValues? {
        let workout = try #require(
            try log.startEmptyWorkout(at: Date(timeIntervalSince1970: 1_900_000_000)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        let value = PreviousSetLookup(context: context).previous(for: set)
        try log.discard(workout)
        return value
    }

    @Test func editedRepsChangeThePreviousValue() throws {
        let workout = try finished(reps: 10)
        #expect(try previousValue()?.text == "15 lb × 10")
        let set = try #require(workout.exercises.first?.sets.first)
        set.repsText = "12"
        try editing.saveEdit(of: set)
        #expect(try previousValue()?.text == "15 lb × 12")
    }

    @Test func deletingTheNewerWorkoutFallsBackToTheOlder() throws {
        _ = try finished(reps: 8, daysAgo: 3)
        let newer = try finished(reps: 10)
        #expect(try previousValue()?.text == "15 lb × 10")
        try log.discard(newer)
        #expect(try previousValue()?.text == "15 lb × 8")
    }

    @Test func lookupSkipsACompletedSetWithoutReps() throws {
        let workout = try finished(reps: 10)
        let workoutExercise = try #require(workout.exercises.first)
        try log.addSet(to: workoutExercise, completed: true)
        let incomplete = try #require(WorkoutLog.orderedSets(of: workoutExercise).last)
        incomplete.reps = nil
        try context.save()
        #expect(incomplete.isCompleted)
        let next = try #require(try log.startEmptyWorkout(at: .now))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: next)
        try log.addSet(to: try #require(next.exercises.first))
        let sets = WorkoutLog.orderedSets(of: try #require(next.exercises.first))
        let lookup = PreviousSetLookup(context: context)
        #expect(lookup.previous(for: sets[0])?.text == "15 lb × 10")
        #expect(lookup.previous(for: sets[1]) == nil)
        #expect(lookup.lastProgressionSets(for: try #require(next.exercises.first)).count == 1)
    }

    @Test func addedExerciseWithoutRepsBlocksDone() throws {
        let workout = try finished(reps: 10)
        #expect(PastWorkoutEditing.canFinishEditing(workout))
        try log.addExercise(try exercise("Dumbbell Curl"), to: workout, completed: true)
        let added = try #require(WorkoutLog.orderedExercises(of: workout).last?.sets.first)
        #expect(added.isCompleted)
        #expect(!PastWorkoutEditing.isValid(added))
        #expect(PastWorkoutEditing.hint(for: added) == "Add reps")
        #expect(!PastWorkoutEditing.canFinishEditing(workout))
        #expect(try !editing.finishEditing(workout))
        added.repsText = "8"
        try editing.saveEdit(of: added)
        #expect(PastWorkoutEditing.canFinishEditing(workout))
        #expect(PastWorkoutEditing.hint(for: added) == nil)
    }

    @Test func durationSetNeedsADuration() throws {
        let workout = try finished(reps: 10)
        try log.addExercise(try exercise("Plank"), to: workout, completed: true)
        let set = try #require(WorkoutLog.orderedExercises(of: workout).last?.sets.first)
        set.durationSeconds = nil
        #expect(PastWorkoutEditing.hint(for: set) == "Add a duration")
        set.durationSeconds = 30
        #expect(PastWorkoutEditing.isValid(set))
    }

    @Test func clearingRepsKeepsTheSetCompletedAndInvalid() throws {
        let workout = try finished(reps: 10)
        let set = try #require(workout.exercises.first?.sets.first)
        set.repsText = ""
        try editing.saveEdit(of: set)
        #expect(set.isCompleted)
        #expect(!PastWorkoutEditing.canFinishEditing(workout))
    }

    @Test func addSetAndDuplicateCreateCompletedCopies() throws {
        let workout = try finished(reps: 10)
        let workoutExercise = try #require(workout.exercises.first)
        try log.addSet(to: workoutExercise, completed: true)
        try log.duplicateSet(
            try #require(WorkoutLog.orderedSets(of: workoutExercise).first), completed: true)
        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.isCompleted })
        let expected = SetValues.weightReps(weight: 15, reps: 10)
        #expect(sets.allSatisfy { $0.values == expected })
    }

    @Test func doneRemovesExercisesWithNoSetsAndKeepsTitle() throws {
        let workout = try finished(reps: 10)
        try log.addExercise(try exercise("Dumbbell Curl"), to: workout, completed: true)
        let added = try #require(WorkoutLog.orderedExercises(of: workout).last)
        try log.deleteSet(try #require(added.sets.first))
        #expect(try editing.finishEditing(workout))
        #expect(workout.exercises.count == 1)
        workout.title = "  "
        #expect(try editing.finishEditing(workout))
        #expect(workout.title == WorkoutLog.defaultTitle(startingAt: workout.startDate))
    }

    @Test func deletingAWorkoutRemovesItsExercisesAndSets() throws {
        let workout = try finished(reps: 10)
        try log.discard(workout)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
    }
}
