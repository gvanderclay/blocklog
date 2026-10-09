import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the routine's delete rules, the routine draft and saving routines against an in-memory store
/// seeded with the starters.
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

    private func exercise(_ name: String, in context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    @Test func deletingARoutineThroughTheLibraryKeepsItsWorkoutsWithTheLinkCleared() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        draft.name = "Push"
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        let library = RoutineLibrary(context: context)
        let routine = try #require(try library.save(draft, to: nil))
        let log = WorkoutLog(context: context)
        let workout = try #require(
            try RoutineStart(context: context).startWorkout(from: routine)?.workout)
        let set = try #require(workout.exercises.first?.sets.first)
        set.repsText = "10"
        try log.toggleCompleted(set)
        _ = try log.finish(workout, title: "Push")
        let workoutID = workout.id

        try library.delete(routine)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Routine>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<RoutineExercise>()) == 0)
        let kept = try #require(
            try fresh.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID }))
                .first)
        #expect(kept.routine == nil)
        #expect(kept.title == "Push")
        #expect(kept.exercises.first?.sets.map(\.reps) == [10])
    }

    @Test func aNewExerciseStartsWithOneNormalSetAtTheDefaults() throws {
        // Held for the whole test: models crash once their container is freed.
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))

        let entry = try #require(draft.exercises.first)
        #expect(entry.sets.map(\.type) == [.normal])
        #expect(entry.target == .repRange(8...12))
        draft.addExercise(try exercise("Plank", in: context))
        #expect(draft.exercises[1].target == .duration(seconds: 30))
    }

    @Test func theRepRangeEndsCantCrossAndStayWithinOneToFifty() throws {
        // Held for the whole test: models crash once their container is freed.
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        draft.exercises[0].repLow = 10
        draft.exercises[0].repHigh = 10

        let range = try #require(draft.exercises[0].target.repRange)
        #expect(range == 10...10)
        #expect(RoutineTarget.lowBounds(of: range) == 1...10)
        #expect(RoutineTarget.highBounds(of: range) == 10...50)
    }

    @Test func renamingARoutineKeepsStoredValuesOutsideTheStepperBounds() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Core", creationDate: .now)
        context.insert(routine)
        let plank = RoutineExercise(
            exercise: try exercise("Plank", in: context), position: 0, plannedSetTypes: [.normal],
            targetDurationSeconds: 900)
        let bench = RoutineExercise(
            exercise: try exercise("Dumbbell Bench Press", in: context), position: 1,
            plannedSetTypes: [.normal], repRangeLow: 60, repRangeHigh: 80)
        routine.exercises.append(contentsOf: [plank, bench])
        try context.save()

        var draft = RoutineDraft(routine: routine)
        draft.name = "Core Day"
        _ = try RoutineLibrary(context: context).save(draft, to: routine)

        let saved = RoutineLibrary.orderedExercises(of: routine)
        #expect(routine.name == "Core Day")
        #expect(saved[0].targetDurationSeconds == 900)
        #expect(saved[1].repRangeLow == 60)
        #expect(saved[1].repRangeHigh == 80)
    }

    @Test func aRoutineExerciseWithNoTargetSummarisesAsADashAndBareSets() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Empty", creationDate: .now)
        context.insert(routine)
        let sets: [SetType] = [.normal, .normal, .normal]
        let bench = RoutineExercise(
            exercise: try exercise("Dumbbell Bench Press", in: context), position: 0,
            plannedSetTypes: sets)
        let plank = RoutineExercise(
            exercise: try exercise("Plank", in: context), position: 1, plannedSetTypes: [.normal])
        routine.exercises.append(contentsOf: [bench, plank])
        try context.save()

        #expect(RoutineLibrary.summary(of: bench) == "3 × —")
        #expect(RoutineLibrary.spokenSummary(of: bench) == "3 sets")
        #expect(RoutineLibrary.summary(of: plank) == "1 × —")
        #expect(RoutineLibrary.spokenSummary(of: plank) == "1 set")
    }

    @Test(arguments: [
        (3, RoutineTarget?.some(.repRange(8...12)), "3 × 8–12", "3 sets of 8 to 12 reps"),
        (1, .duration(seconds: 45), "1 × 45 s", "1 set of 45 seconds"),
        (2, nil, "2 × —", "2 sets"),
    ])
    func aPlanOfSetsSummarisesItsTargetWrittenAndSpoken(
        count: Int, target: RoutineTarget?, written: String, spoken: String
    ) {
        #expect(RoutineLibrary.summary(setCount: count, target: target) == written)
        #expect(RoutineLibrary.spokenSummary(setCount: count, target: target) == spoken)
    }

    @Test func aRoutineExerciseWhoseExerciseIsGoneStillSummarisesItsStoredTarget() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Gone", creationDate: .now)
        context.insert(routine)
        let ranged = RoutineExercise(
            exercise: try exercise("Dumbbell Bench Press", in: context), position: 0,
            plannedSetTypes: [.normal, .normal], repRangeLow: 6, repRangeHigh: 10)
        let timed = RoutineExercise(
            exercise: try exercise("Plank", in: context), position: 1,
            plannedSetTypes: [.normal, .normal], targetDurationSeconds: 45)
        routine.exercises.append(contentsOf: [ranged, timed])
        try context.save()
        ranged.exercise = nil
        timed.exercise = nil

        #expect(RoutineLibrary.summary(of: ranged) == "2 × 6–10")
        #expect(RoutineLibrary.spokenSummary(of: ranged) == "2 sets of 6 to 10 reps")
        #expect(RoutineLibrary.summary(of: timed) == "2 × 45 s")
        #expect(RoutineLibrary.spokenSummary(of: timed) == "2 sets of 45 seconds")
    }

    @Test func openingARoutineExerciseWithNoTargetShowsTheDefaultsAndSavingStoresThem() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let routine = Routine(name: "Bare", creationDate: .now)
        context.insert(routine)
        routine.exercises.append(
            RoutineExercise(
                exercise: try exercise("Dumbbell Bench Press", in: context), position: 0,
                plannedSetTypes: [.normal]))
        routine.exercises.append(
            RoutineExercise(
                exercise: try exercise("Plank", in: context), position: 1,
                plannedSetTypes: [.normal]))
        try context.save()

        let draft = RoutineDraft(routine: routine)
        try RoutineLibrary(context: context).save(draft, to: routine)

        let saved = RoutineLibrary.orderedExercises(of: routine)
        #expect(saved.map(\.repRangeLow) == [8, nil])
        #expect(saved.map(\.repRangeHigh) == [12, nil])
        #expect(saved.map(\.targetDurationSeconds) == [nil, 30])
    }

    @Test func reorderingNeedsTwoExercises() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        #expect(!draft.canReorder)
        draft.addExercise(try exercise("Plank", in: context))
        #expect(!draft.canReorder)
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        #expect(draft.canReorder)
    }

    @Test func addSetCopiesTheLastSetsType() throws {
        // Held for the whole test: models crash once their container is freed.
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        draft.exercises[0].sets[0].type = .warmUp
        draft.exercises[0].addSet()
        #expect(draft.exercises[0].sets.map(\.type) == [.warmUp, .warmUp])
        draft.exercises[0].sets.removeAll()
        draft.exercises[0].addSet()

        #expect(draft.exercises[0].sets.map(\.type) == [.normal])
    }

    @Test func saveNeedsANameAndAnExercise() throws {
        // Held for the whole test: models crash once their container is freed.
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        var draft = RoutineDraft()
        #expect(!draft.canSave)
        draft.name = "  \n "
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        #expect(!draft.canSave)
        #expect(try RoutineLibrary(context: context).save(draft, to: nil) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 0)

        draft.name = " Push "
        #expect(draft.canSave)
        draft.exercises.removeAll()
        #expect(!draft.canSave)
    }

    @Test func savingWritesTheDraftAndEditingReplacesIt() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let library = RoutineLibrary(context: context)
        var draft = RoutineDraft()
        draft.name = " Push "
        draft.addExercise(try exercise("Dumbbell Bench Press", in: context))
        draft.exercises[0].sets[0].type = .warmUp
        draft.exercises[0].sets.append(RoutineDraft.PlannedSet(type: .normal))
        draft.exercises[0].repLow = 6
        draft.exercises[0].repHigh = 10
        draft.addExercise(try exercise("Plank", in: context))
        draft.exercises[1].targetDurationSeconds = 45
        let routine = try #require(try library.save(draft, to: nil))

        let fresh = ModelContext(container)
        let saved = try #require(try fresh.fetch(FetchDescriptor<Routine>()).first)
        #expect(saved.name == "Push")
        let entries = RoutineLibrary.orderedExercises(of: saved)
        #expect(entries.map { $0.exercise?.name } == ["Dumbbell Bench Press", "Plank"])
        #expect(entries[0].plannedSetTypeRawValues == ["warmUp", "normal"])
        #expect(entries[0].repRangeLow == 6)
        #expect(entries[0].repRangeHigh == 10)
        #expect(entries[0].targetDurationSeconds == nil)
        #expect(entries[1].repRangeLow == nil)
        #expect(entries[1].targetDurationSeconds == 45)
        #expect(entries.map(RoutineLibrary.summary(of:)) == ["2 × 6–10", "1 × 45 s"])
        #expect(
            entries.map(RoutineLibrary.spokenSummary(of:)) == [
                "2 sets of 6 to 10 reps", "1 set of 45 seconds",
            ])

        var edit = RoutineDraft(routine: routine)
        #expect(edit.name == "Push")
        #expect(edit.exercises.map(\.repLow) == [6, 8])
        #expect(edit.exercises.map(\.targetDurationSeconds) == [30, 45])
        edit.name = "Push Day"
        edit.exercises.reverse()
        edit.exercises[1].addSet()
        try library.save(edit, to: routine)

        let reread = ModelContext(container)
        #expect(try reread.fetchCount(FetchDescriptor<Routine>()) == 1)
        #expect(try reread.fetchCount(FetchDescriptor<RoutineExercise>()) == 2)
        let edited = try #require(try reread.fetch(FetchDescriptor<Routine>()).first)
        #expect(edited.name == "Push Day")
        #expect(
            RoutineLibrary.orderedExercises(of: edited).map(RoutineLibrary.summary(of:)) == [
                "1 × 45 s", "3 × 6–10",
            ])
    }

    @Test func aFailedRoutineEditRollsBackAndThrows() throws {
        let store = try ReadOnlyStore { context in
            let curl = Exercise(
                name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell, kind: .weightReps)
            let fly = Exercise(
                name: "Dumbbell Fly", muscleGroup: .chest, equipment: .dumbbell, kind: .weightReps)
            context.insert(curl)
            context.insert(fly)
            let routine = Routine(name: "Pull", creationDate: .now)
            context.insert(routine)
            let routineExercise = RoutineExercise(
                exercise: curl, position: 0, plannedSetTypes: [.warmUp, .normal], repRangeLow: 6,
                repRangeHigh: 10)
            context.insert(routineExercise)
            routine.exercises.append(routineExercise)
        }
        defer { store.remove() }
        let context = store.context
        let routine = try #require(try context.fetch(FetchDescriptor<Routine>()).first)
        let before = RoutineLibrary.orderedExercises(of: routine)
        let ids = before.map(\.persistentModelID)
        var draft = RoutineDraft()
        draft.name = "Renamed"
        let fly = try #require(
            try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Dumbbell Fly" })
        draft.addExercise(fly)

        #expect(throws: (any Error).self) {
            try RoutineLibrary(context: context).save(draft, to: routine)
        }

        let after = RoutineLibrary.orderedExercises(of: routine)
        #expect(!context.hasChanges)
        #expect(routine.name == "Pull")
        #expect(after.map(\.persistentModelID) == ids)
        #expect(
            after.map(\.plannedSetTypeRawValues) == [
                [SetType.warmUp.rawValue, SetType.normal.rawValue]
            ])
        #expect(after.map(\.repRangeLow) == [6])
        #expect(after.map(\.repRangeHigh) == [10])
        #expect(try context.fetchCount(FetchDescriptor<RoutineExercise>()) == 1)
    }
}
