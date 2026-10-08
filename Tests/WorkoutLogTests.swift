import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks starting, logging and finishing workouts against an in-memory store seeded with the starters.
@MainActor
struct WorkoutLogTests {
    let container: ModelContainer
    let log: WorkoutLog

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    /// Starts a workout with one exercise holding `count` sets, the nth set having n reps.
    private func workout(sets count: Int, of name: String = "Dumbbell Bench Press") throws
        -> Workout
    {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise(name), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        for _ in 1..<count { try log.addSet(to: workoutExercise) }
        for (index, set) in WorkoutLog.orderedSets(of: workoutExercise).enumerated() {
            set.reps = index + 1
        }
        try log.save()
        return workout
    }

    @Test func savedWorkoutReadsBackWithSetsInPositionOrder() throws {
        let id = try workout(sets: 5).id

        let fresh = ModelContext(container)
        let workout = try #require(
            try fresh.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first)
        let workoutExercise = try #require(workout.exercises.first)
        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.reps) == [1, 2, 3, 4, 5])
        #expect(sets.map(\.position) == [0, 1, 2, 3, 4])
    }

    @Test func finishDeletesUncheckedSetsAndEmptyExercises() throws {
        let workout = try workout(sets: 3)
        try log.addExercise(try exercise("Hammer Curl"), to: workout)
        let bench = WorkoutLog.orderedExercises(of: workout)[0]
        let benchSets = WorkoutLog.orderedSets(of: bench)
        try log.toggleCompleted(benchSets[0])
        try log.toggleCompleted(benchSets[2])

        let start = workout.startDate
        let summary = try #require(
            try log.finish(workout, title: "Push Day", at: start.addingTimeInterval(45 * 60)))

        #expect(
            WorkoutLog.orderedExercises(of: workout).map(\.exercise?.name) == [
                "Dumbbell Bench Press"
            ])
        let kept = WorkoutLog.orderedSets(of: bench)
        #expect(kept.map(\.reps) == [1, 3])
        #expect(kept.map(\.position) == [0, 1])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WorkoutExercise>()) == 1)
        #expect(workout.endDate == start.addingTimeInterval(45 * 60))
        #expect(workout.title == "Push Day")
        #expect(log.inProgressWorkout() == nil)
        #expect(summary.workoutNumber == 1)
        #expect(summary.duration == .seconds(45 * 60))
        #expect(summary.completedSetCount == 2)
        #expect(summary.exerciseCount == 1)
    }

    @Test func finishWithNoCheckedSetChangesNothing() throws {
        let workout = try workout(sets: 2)
        #expect(try log.finish(workout, title: "Push Day") == nil)
        #expect(workout.endDate == nil)
        #expect(workout.exercises.first?.sets.count == 2)
    }

    @Test func finishWithABlankTitleUsesTheDefault() throws {
        let workout = try workout(sets: 1)
        try log.toggleCompleted(try #require(workout.exercises.first?.sets.first))
        _ = try log.finish(workout, title: "  ")
        #expect(workout.title == WorkoutLog.defaultTitle(startingAt: workout.startDate))
    }

    @Test(arguments: [
        (4, 59, "Evening Workout"),
        (5, 0, "Morning Workout"),
        (11, 59, "Morning Workout"),
        (12, 0, "Afternoon Workout"),
        (16, 59, "Afternoon Workout"),
        (17, 0, "Evening Workout"),
    ])
    func defaultTitleChangesWithTheStartTime(hour: Int, minute: Int, title: String) throws {
        let date = try #require(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: 7, hour: hour, minute: minute)))
        #expect(WorkoutLog.defaultTitle(startingAt: date) == title)
    }

    @Test func onlyOneWorkoutCanBeInProgress() throws {
        let first = try #require(try log.startEmptyWorkout())
        #expect(try log.startEmptyWorkout() == nil)
        #expect(log.inProgressWorkout() === first)
    }

    @Test func firstSetStartsAtFivePoundsWithEmptyRepsAndAddSetCopiesTheLastSet() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        let first = try #require(workoutExercise.sets.first)
        #expect(first.weight == 5)
        #expect(first.reps == nil)

        try log.setWeight(15, of: first)
        first.reps = 10
        try log.addSet(to: workoutExercise)

        let second = WorkoutLog.orderedSets(of: workoutExercise)[1]
        #expect(second.weight == 15)
        #expect(second.reps == 10)
        #expect(second.setType == first.setType)
        #expect(second.isCompleted == false)
    }

    @Test func weightOnlyTakesPowerBlockSettings() throws {
        let set = try #require(try workout(sets: 1).exercises.first?.sets.first)
        try log.setWeight(12.5, of: set)
        #expect(set.weight == 5)
    }

    @Test func aSetChecksOffOnlyWithRepsAndCanBeUnchecked() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)

        try log.toggleCompleted(set)
        #expect(set.isCompleted == false)

        set.repsText = "8"
        try log.toggleCompleted(set)
        #expect(set.isCompleted == true)
        try log.toggleCompleted(set)
        #expect(set.isCompleted == false)
    }

    @Test func repsTextKeepsOnlyDigits() throws {
        let set = try #require(try workout(sets: 1).exercises.first?.sets.first)
        set.repsText = "1a2"
        #expect(set.reps == 12)
        set.repsText = ""
        #expect(set.reps == nil)
        #expect(set.repsText == "")
    }

    @Test func nextEmptySetSkipsFilledSetsAcrossExercises() throws {
        let workout = try workout(sets: 2)
        try log.addExercise(try exercise("Hammer Curl"), to: workout)
        let bench = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        let curl = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[1])

        #expect(WorkoutLog.nextEmptySet(after: bench[0].id, in: workout) === curl[0])
        #expect(WorkoutLog.nextEmptySet(after: curl[0].id, in: workout) == nil)
    }

    @Test func nextEmptySetFindsEmptyDurationFieldsAndSkipsFilledOnes() throws {
        let workout = try workout(sets: 1)
        try log.addExercise(try exercise("Plank"), to: workout)
        let bench = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        let plank = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[1])
        #expect(plank[0].durationSeconds == nil)
        #expect(WorkoutLog.nextEmptySet(after: bench[0].id, in: workout) === plank[0])

        plank[0].durationText = "45"
        #expect(WorkoutLog.nextEmptySet(after: bench[0].id, in: workout) == nil)
    }

    @Test func setsAreNumberedInPositionOrderAndRenumberedAfterFinish() throws {
        let workout = try workout(sets: 3)
        let sets = WorkoutLog.orderedSets(of: try #require(workout.exercises.first))
        #expect(sets.map(SetNumbering.countedNumber(of:)) == [1, 2, 3])

        try log.toggleCompleted(sets[0])
        try log.toggleCompleted(sets[2])
        _ = try log.finish(workout, title: "Push Day")
        #expect([sets[0], sets[2]].map(SetNumbering.countedNumber(of:)) == [1, 2])
    }

    @Test func addableExercisesIncludeDurationAndBodyweightSortedByName() throws {
        let addable = try container.mainContext.fetch(WorkoutLog.addableExercises)
        #expect(addable.contains { $0.kind == .duration })
        #expect(addable.contains { $0.name == "Push-up" })
        #expect(addable.map(\.name) == addable.map(\.name).sorted())

        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Plank"), to: workout)
        #expect(workout.exercises.count == 1)
    }

    @Test func firstSetsStartEmptyForBodyweightAndDuration() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Pull-up"), to: workout)
        try log.addExercise(try exercise("Plank"), to: workout)
        let exercises = WorkoutLog.orderedExercises(of: workout)
        let pullUp = try #require(WorkoutLog.orderedSets(of: exercises[0]).first)
        let plank = try #require(WorkoutLog.orderedSets(of: exercises[1]).first)
        #expect(pullUp.weight == nil && pullUp.reps == nil)
        #expect(plank.durationSeconds == nil)
        #expect(!WorkoutLog.canCheckOff(plank))

        plank.durationText = "45"
        try log.toggleCompleted(plank)
        #expect(plank.isCompleted)
        plank.durationText = ""
        #expect(!plank.isCompleted)

        try log.setAddedWeight(5, of: pullUp)
        try log.addSet(to: exercises[0])
        #expect(WorkoutLog.orderedSets(of: exercises[0]).last?.weight == 5)
        try log.setAddedWeight(12.5, of: pullUp)
        #expect(pullUp.weight == 5)
        try log.setAddedWeight(nil, of: pullUp)
        #expect(pullUp.weight == nil)
    }

    @Test func deletingASetRenumbersPositions() throws {
        let workout = try workout(sets: 3)
        let workoutExercise = try #require(workout.exercises.first)
        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        try log.deleteSet(sets[1])
        #expect(WorkoutLog.orderedSets(of: workoutExercise).map(\.position) == [0, 1])
        #expect(WorkoutLog.orderedSets(of: workoutExercise).map(\.reps) == [1, 3])
    }

    @Test func duplicatingASetInsertsAnUncheckedCopyRightAfterIt() throws {
        let workout = try workout(sets: 3)
        let workoutExercise = try #require(workout.exercises.first)
        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        sets[0].setType = .drop
        try log.toggleCompleted(sets[0])
        try log.duplicateSet(sets[0])
        let after = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(after.map(\.reps) == [1, 1, 2, 3])
        #expect(after.map(\.position) == [0, 1, 2, 3])
        #expect(after[1].setType == .drop)
        #expect(!after[1].isCompleted)
    }

    @Test func removingAnExerciseRenumbersTheOthersAndReorderingAppliesPositions() throws {
        let workout = try #require(try log.startEmptyWorkout())
        for name in ["Dumbbell Bench Press", "Hammer Curl", "Plank"] {
            try log.addExercise(try exercise(name), to: workout)
        }
        let ordered = WorkoutLog.orderedExercises(of: workout)
        let (bench, curl, plank) = (ordered[0], ordered[1], ordered[2])
        try log.reorderExercises([plank, bench, curl])
        #expect(
            WorkoutLog.orderedExercises(of: workout).map { $0.exercise?.name }
                == ["Plank", "Dumbbell Bench Press", "Hammer Curl"])
        try log.removeExercise(bench)
        let remaining = WorkoutLog.orderedExercises(of: workout)
        #expect(remaining.map(\.position) == [0, 1])
        #expect(remaining.map { $0.exercise?.name } == ["Plank", "Hammer Curl"])
    }

    @Test func settingATypeChangesTheNumbering() throws {
        let workout = try workout(sets: 2)
        let sets = WorkoutLog.orderedSets(of: try #require(workout.exercises.first))
        try log.setType(.warmUp, of: sets[0])
        #expect(sets.map(SetNumbering.label(of:)) == ["W", "1"])
    }

    @Test func clearingTheRepsOfACheckedSetUnchecksIt() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)

        set.repsText = "10"
        try log.toggleCompleted(set)
        #expect(set.isCompleted)
        set.repsText = ""
        try log.save()
        #expect(set.isCompleted == false)
        #expect(try log.finish(workout, title: "Push Day") == nil)

        set.repsText = "10"
        try log.toggleCompleted(set)
        set.repsText = "0"
        #expect(set.isCompleted == false)
    }

    @Test func finishJoinsTitleLinesWithSpaces() throws {
        let workout = try workout(sets: 1)
        try log.toggleCompleted(try #require(workout.exercises.first?.sets.first))
        _ = try log.finish(workout, title: "Push\nDay ")
        #expect(workout.title == "Push Day")
    }

    @Test func finishThrowsAndGivesNoSummaryWhenSavingFails() throws {
        // A store opened read-only stands in for a full disk. Read-only needs an existing store file.
        let url = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let schema = Schema([
            Exercise.self, Workout.self, WorkoutExercise.self, WorkoutSet.self, Routine.self,
            RoutineExercise.self,
        ])
        _ = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let readOnly = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false))
        let context = readOnly.mainContext
        let workout = Workout(title: "Push Day", startDate: .now)
        let workoutExercise = WorkoutExercise(
            exercise: Exercise(
                name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell, kind: .weightReps),
            position: 0)
        let set = WorkoutSet(position: 0, weight: 20, reps: 10, isCompleted: true)
        context.insert(workout)
        workout.exercises.append(workoutExercise)
        workoutExercise.sets.append(set)

        #expect(throws: (any Error).self) {
            _ = try WorkoutLog(context: context).finish(workout, title: "Push Day")
        }
    }

    @Test func discardDeletesTheWorkoutWithItsSets() throws {
        let workout = try workout(sets: 2)
        try log.discard(workout)
        #expect(log.inProgressWorkout() == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
    }
}
