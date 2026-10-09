import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the routine difference and the routine update against an in-memory store seeded with the starters.
@MainActor
struct RoutineDifferenceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    /// Saves a routine with one entry per (exercise name, planned set types), each at 8–12 or a 30 s target.
    private func routine(_ entries: [(String, [SetType])]) throws -> Routine {
        var draft = RoutineDraft()
        draft.name = "Pull"
        for (name, types) in entries {
            draft.addExercise(try exercise(name))
            draft.exercises[draft.exercises.count - 1].sets = types.map {
                RoutineDraft.PlannedSet(type: $0)
            }
        }
        return try #require(try RoutineLibrary(context: context).save(draft, to: nil))
    }

    /// A finished workout linked to `routine`, with one entry per (exercise name, set types), every set
    /// checked, at 20 lb for 10 reps.
    private func finished(_ routine: Routine?, _ entries: [(String, [SetType])]) throws -> Workout {
        let workout = Workout(title: "Pull", startDate: .now, endDate: .now, routine: routine)
        context.insert(workout)
        for (position, entry) in entries.enumerated() {
            let workoutExercise = WorkoutExercise(
                exercise: try exercise(entry.0), position: position)
            context.insert(workoutExercise)
            workout.exercises.append(workoutExercise)
            for (index, type) in entry.1.enumerated() {
                let set = WorkoutSet(
                    position: index, setType: type, weight: 20, reps: 10, isCompleted: true)
                context.insert(set)
                workoutExercise.sets.append(set)
            }
        }
        try context.save()
        return workout
    }

    private let two: [SetType] = [.normal, .normal]

    private func differs(
        routine entries: [(String, [SetType])], workout done: [(String, [SetType])]
    ) throws -> Bool {
        let stored = try routine(entries)
        return RoutineDifference.isStructural(try finished(stored, done))
    }

    @Test func aWorkoutThatMatchesItsRoutineDoesNotDiffer() throws {
        #expect(
            try !differs(
                routine: [("Hammer Curl", two), ("Plank", [.normal])],
                workout: [("Hammer Curl", two), ("Plank", [.normal])]))
    }

    @Test func anAddedExerciseDiffers() throws {
        #expect(
            try differs(
                routine: [("Hammer Curl", two)],
                workout: [("Hammer Curl", two), ("Plank", [.normal])]))
    }

    @Test func aRemovedExerciseDiffers() throws {
        #expect(
            try differs(
                routine: [("Hammer Curl", two), ("Plank", [.normal])],
                workout: [("Hammer Curl", two)]))
    }

    @Test func aSwappedExerciseDiffers() throws {
        #expect(
            try differs(
                routine: [("Hammer Curl", two)], workout: [("Dumbbell Bench Press", two)]))
    }

    @Test func aReorderedExerciseDiffers() throws {
        #expect(
            try differs(
                routine: [("Hammer Curl", two), ("Plank", two)],
                workout: [("Plank", two), ("Hammer Curl", two)]))
    }

    @Test func oneExtraOrOneFewerSetDiffers() throws {
        #expect(
            try differs(
                routine: [("Hammer Curl", two)], workout: [("Hammer Curl", two + [.normal])]))
        #expect(try differs(routine: [("Hammer Curl", two)], workout: [("Hammer Curl", [.normal])]))
    }

    @Test func changedSetTypesDoNotDiffer() throws {
        #expect(
            try !differs(
                routine: [("Hammer Curl", two)], workout: [("Hammer Curl", [.warmUp, .failure])]))
    }

    @Test func aWorkoutWithOnlyWeightAndRepChangesDoesNotDiffer() throws {
        let stored = try routine([("Hammer Curl", two)])
        let workout = try finished(stored, [("Hammer Curl", two)])
        for set in workout.exercises.flatMap(\.sets) {
            set.weight = 35
            set.reps = 3
        }
        #expect(!RoutineDifference.isStructural(workout))
    }

    @Test func aWorkoutWithoutARoutineNeverDiffers() throws {
        #expect(!RoutineDifference.isStructural(try finished(nil, [("Hammer Curl", two)])))
    }

    @Test func aRoutineExerciseWhoseExerciseWasDeletedIsIgnored() throws {
        let stored = try routine([("Hammer Curl", two), ("Plank", [.normal])])
        let plank = try #require(
            RoutineLibrary.orderedExercises(of: stored).last)
        plank.exercise = nil
        #expect(!RoutineDifference.isStructural(try finished(stored, [("Hammer Curl", two)])))
    }

    // MARK: Updating

    /// The routine's exercises in order: name, set types, rep range and target duration.
    private func plan(_ routine: Routine) -> [String] {
        RoutineLibrary.orderedExercises(of: routine).map { entry in
            let types = entry.plannedSetTypeRawValues.joined(separator: ",")
            let range = entry.repRangeLow.map { "\($0)–\(entry.repRangeHigh ?? 0)" } ?? "-"
            return
                "\(entry.exercise?.name ?? "?") \(types) \(range) \(entry.targetDurationSeconds ?? 0)"
        }
    }

    @Test func updatingKeepsRangesGivesNewExercisesTheDefaultsAndCopiesSetTypes() throws {
        let stored = try routine([("Hammer Curl", two), ("Dumbbell Bench Press", two)])
        let curl = try #require(RoutineLibrary.orderedExercises(of: stored).first)
        curl.repRangeLow = 6
        curl.repRangeHigh = 10
        let workout = try finished(
            stored,
            [
                ("Plank", [.normal]), ("Hammer Curl", [.warmUp, .normal, .failure]),
                ("Dumbbell Fly", [.drop]),
            ])

        try RoutineDifference(context: context).update(stored, toMatch: workout)

        #expect(
            plan(stored) == [
                "Plank normal - 30", "Hammer Curl warmUp,normal,failure 6–10 0",
                "Dumbbell Fly drop 8–12 0",
            ])
        // Saved: a fresh context reads the same, and the dropped routine exercise is gone.
        let id = stored.id
        let fresh = ModelContext(container)
        let saved = try #require(
            try fresh.fetch(FetchDescriptor<Routine>(predicate: #Predicate { $0.id == id })).first)
        #expect(saved.exercises.count == 3)
        #expect(try fresh.fetchCount(FetchDescriptor<RoutineExercise>()) == 3)
        #expect(!RoutineDifference.isStructural(workout))
    }

    @Test func updatingMatchesAnExerciseThatAppearsTwiceInOrder() throws {
        let stored = try routine([("Hammer Curl", two), ("Plank", two), ("Hammer Curl", two)])
        let routineExercises = RoutineLibrary.orderedExercises(of: stored)
        routineExercises[0].repRangeLow = 6
        routineExercises[0].repRangeHigh = 8
        routineExercises[2].repRangeLow = 12
        routineExercises[2].repRangeHigh = 15
        let ids = routineExercises.map(\.id)
        let workout = try finished(
            stored, [("Hammer Curl", [.normal]), ("Hammer Curl", [.drop]), ("Plank", two)])

        try RoutineDifference(context: context).update(stored, toMatch: workout)

        #expect(
            plan(stored) == [
                "Hammer Curl normal 6–8 0", "Hammer Curl drop 12–15 0",
                "Plank normal,normal - 30",
            ])
        // The first curl and the plank are reused; the third routine exercise is reused for the second curl.
        let after = RoutineLibrary.orderedExercises(of: stored).map(\.id)
        #expect(after == [ids[0], ids[2], ids[1]])
        #expect(try context.fetchCount(FetchDescriptor<RoutineExercise>()) == 3)
    }

    @Test func updatingKeepsANonDefaultTargetAndDeletesAnOrphanedRoutineExercise() throws {
        let stored = try routine([("Plank", two), ("Hammer Curl", two)])
        let entries = RoutineLibrary.orderedExercises(of: stored)
        entries[0].targetDurationSeconds = 60
        entries[1].exercise = nil
        let workout = try finished(stored, [("Plank", [.normal])])

        try RoutineDifference(context: context).update(stored, toMatch: workout)

        let id = stored.id
        let fresh = ModelContext(container)
        let saved = try #require(
            try fresh.fetch(FetchDescriptor<Routine>(predicate: #Predicate { $0.id == id })).first)
        #expect(plan(saved) == ["Plank normal - 60"])
        #expect(try fresh.fetchCount(FetchDescriptor<RoutineExercise>()) == 1)
    }

    @Test func updatingAddsASecondOccurrenceOfAnExercise() throws {
        let stored = try routine([("Hammer Curl", two)])
        let workout = try finished(stored, [("Hammer Curl", two), ("Hammer Curl", [.normal])])

        try RoutineDifference(context: context).update(stored, toMatch: workout)

        #expect(plan(stored) == ["Hammer Curl normal,normal 8–12 0", "Hammer Curl normal 8–12 0"])
    }

    @Test func aFailedUpdateRollsBackAndThrows() throws {
        let store = try ReadOnlyStore { context in
            let curl = Exercise(
                name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell, kind: .weightReps)
            let fly = Exercise(
                name: "Dumbbell Fly", muscleGroup: .chest, equipment: .dumbbell, kind: .weightReps)
            let routine = Routine(name: "Pull", creationDate: .now)
            context.insert(routine)
            let routineExercise = RoutineExercise(
                exercise: curl, position: 0, plannedSetTypes: [.normal, .normal], repRangeLow: 6,
                repRangeHigh: 10)
            context.insert(routineExercise)
            routine.exercises.append(routineExercise)
            let workout = Workout(title: "Pull", startDate: .now, endDate: .now, routine: routine)
            context.insert(workout)
            for (position, exercise) in [fly, curl].enumerated() {
                let workoutExercise = WorkoutExercise(exercise: exercise, position: position)
                context.insert(workoutExercise)
                workout.exercises.append(workoutExercise)
                let set = WorkoutSet(position: 0, weight: 20, reps: 10, isCompleted: true)
                context.insert(set)
                workoutExercise.sets.append(set)
            }
        }
        defer { store.remove() }
        let routine = try #require(try store.context.fetch(FetchDescriptor<Routine>()).first)
        let workout = try #require(try store.context.fetch(FetchDescriptor<Workout>()).first)

        #expect(throws: (any Error).self) {
            try RoutineDifference(context: store.context).update(routine, toMatch: workout)
        }

        #expect(!store.context.hasChanges)
        #expect(plan(routine) == ["Hammer Curl normal,normal 6–10 0"])
        #expect(try store.context.fetchCount(FetchDescriptor<RoutineExercise>()) == 1)
        #expect(RoutineDifference.isStructural(workout))
    }
}
