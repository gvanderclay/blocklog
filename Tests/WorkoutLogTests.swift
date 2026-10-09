import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class ManualClock {
    var date = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

/// Lets the rest timer schedule without touching the system notification center.
@MainActor
private final class QuietNotifications: RestNotifying {
    func schedule(at date: Date, exerciseName: String?) {}
    func cancel() {}
}

/// Checks starting, logging and finishing workouts against an in-memory store seeded with the starters.
@MainActor
struct WorkoutLogTests {
    private let clock = ManualClock()
    let container: ModelContainer
    let restTimer: RestTimer
    let log: WorkoutLog

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        let clock = clock
        restTimer = RestTimer(now: { clock.date }, notifications: QuietNotifications())
        log = WorkoutLog(context: container.mainContext, restTimer: restTimer)
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
        try log.context.saveOrRollBack()
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

    @Test func finishWithClockBeforeStartEndsAtStartAndStillExports() throws {
        let workout = try workout(sets: 1)
        try log.toggleCompleted(try #require(workout.exercises.first?.sets.first))

        let summary = try #require(
            try log.finish(
                workout, title: "Push Day", at: workout.startDate.addingTimeInterval(-3600)))

        #expect(workout.endDate == workout.startDate)
        #expect(summary.duration == .zero)
        _ = try Backup(context: container.mainContext).export(at: .now)
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

    @Test func aWeightTheSetsExerciseTypeCannotHoldChangesNothingAndSavesNothing() throws {
        let store = try ReadOnlyStore { context in
            let workout = Workout(title: "Core", startDate: .now)
            context.insert(workout)
            for (position, kind) in [ExerciseKind.duration, .weightReps].enumerated() {
                let workoutExercise = WorkoutExercise(
                    exercise: Exercise(
                        name: "Exercise \(position)", muscleGroup: .core, equipment: .dumbbell,
                        kind: kind),
                    position: position)
                workout.exercises.append(workoutExercise)
                workoutExercise.sets.append(
                    WorkoutSet(
                        position: 0, weight: kind == .weightReps ? 5 : nil,
                        durationSeconds: kind == .duration ? 30 : nil))
            }
        }
        defer { store.remove() }
        let log = WorkoutLog(context: store.context)
        let exercises = WorkoutLog.orderedExercises(of: try #require(log.inProgressWorkout()))
        let timed = try #require(exercises[0].sets.first)
        let dumbbell = try #require(exercises[1].sets.first)

        // A save would throw, because the store is read-only; neither call saves.
        try log.setWeight(15, of: timed)
        try log.setWeight(nil, of: dumbbell)

        #expect(timed.weight == nil)
        #expect(dumbbell.weight == 5)
        #expect(!store.context.hasChanges)
        #expect(throws: (any Error).self) { try log.setWeight(10, of: dumbbell) }
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

    @Test func checkingOffAdvancesToTheNextEmptySetThenTheNextExerciseThenNothing() throws {
        let workout = try workout(sets: 2)
        try log.addExercise(try exercise("Hammer Curl"), to: workout)
        let bench = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        let curl = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[1])
        for set in bench + curl { set.repsText = "10" }
        bench[1].repsText = ""
        curl[0].repsText = ""

        #expect(try log.checkOffAndAdvance(bench[0], in: workout) === bench[1])
        bench[1].repsText = "8"
        #expect(try log.checkOffAndAdvance(bench[1], in: workout) === curl[0])
        curl[0].repsText = "5"
        #expect(try log.checkOffAndAdvance(curl[0], in: workout) == nil)
        #expect(curl[0].isCompleted)
    }

    @Test func checkOffAndAdvanceLeavesUncheckableAndCheckedSetsAlone() throws {
        let workout = try workout(sets: 2)
        let sets = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        sets[0].repsText = ""
        #expect(try log.checkOffAndAdvance(sets[0], in: workout) == nil)
        #expect(!sets[0].isCompleted)

        sets[0].repsText = "10"
        try log.toggleCompleted(sets[0])
        sets[1].repsText = ""
        #expect(try log.checkOffAndAdvance(sets[0], in: workout) === sets[1])
        #expect(sets[0].isCompleted)
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
        #expect(!plank.values.canCheckOff)

        plank.durationText = "45"
        try log.toggleCompleted(plank)
        #expect(plank.isCompleted)
        plank.durationText = ""
        #expect(!plank.isCompleted)

        try log.setWeight(5, of: pullUp)
        try log.addSet(to: exercises[0])
        #expect(WorkoutLog.orderedSets(of: exercises[0]).last?.weight == 5)
        try log.setWeight(12.5, of: pullUp)
        #expect(pullUp.weight == 5)
        try log.setWeight(nil, of: pullUp)
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
        try log.context.saveOrRollBack()
        #expect(set.isCompleted == false)
        #expect(try log.finish(workout, title: "Push Day") == nil)

        set.repsText = "10"
        try log.toggleCompleted(set)
        set.repsText = "0"
        #expect(set.isCompleted == false)
    }

    @Test func secondsTextKeepsAtMostFourDigitsAndClearingOrZeroingUnchecksADurationSet() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Plank"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)

        set.durationText = "12a345"
        #expect(set.durationSeconds == 1234)
        #expect(set.durationText == "1234")
        try log.toggleCompleted(set)
        #expect(set.isCompleted)

        set.durationText = "0"
        #expect(set.durationSeconds == 0)
        #expect(!set.isCompleted)
        #expect(!set.values.canCheckOff)

        set.durationText = "30"
        try log.toggleCompleted(set)
        set.durationText = ""
        #expect(set.durationSeconds == nil)
        #expect(!set.isCompleted)
    }

    @Test func repsTextKeepsAtMostThreeDigits() throws {
        let set = try #require(try workout(sets: 1).exercises.first?.sets.first)
        set.repsText = "12345"
        #expect(set.reps == 123)
    }

    @Test func aBodyweightSetChecksOffOnlyWithReps() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Pull-up"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        #expect(!set.values.canCheckOff)
        try log.toggleCompleted(set)
        #expect(!set.isCompleted)

        set.repsText = "6"
        try log.toggleCompleted(set)
        #expect(set.isCompleted)
        set.repsText = ""
        #expect(!set.isCompleted)
    }

    @Test func addSetOnADurationExerciseCopiesTheSecondsAndHasNoWeightOrReps() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Plank"), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        let first = try #require(workoutExercise.sets.first)
        #expect(first.weight == nil && first.reps == nil)
        first.durationText = "45"
        try log.setType(.drop, of: first)

        try log.addSet(to: workoutExercise)

        let second = WorkoutLog.orderedSets(of: workoutExercise)[1]
        #expect(second.durationSeconds == 45)
        #expect(second.weight == nil && second.reps == nil)
        #expect(second.setType == .drop)
        #expect(!second.isCompleted)
    }

    @Test func duplicatingCopiesTheValuesOfABodyweightSetAndADurationSet() throws {
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(try exercise("Pull-up"), to: workout)
        try log.addExercise(try exercise("Plank"), to: workout)
        let exercises = WorkoutLog.orderedExercises(of: workout)
        let pullUp = try #require(WorkoutLog.orderedSets(of: exercises[0]).first)
        let plank = try #require(WorkoutLog.orderedSets(of: exercises[1]).first)
        try log.setWeight(10, of: pullUp)
        pullUp.repsText = "6"
        plank.durationText = "45"
        try log.toggleCompleted(pullUp)
        try log.toggleCompleted(plank)

        try log.duplicateSet(pullUp)
        try log.duplicateSet(plank)

        let pullUpCopy = WorkoutLog.orderedSets(of: exercises[0])[1]
        #expect(pullUpCopy.weight == 10 && pullUpCopy.reps == 6)
        #expect(pullUpCopy.durationSeconds == nil && !pullUpCopy.isCompleted)
        let plankCopy = WorkoutLog.orderedSets(of: exercises[1])[1]
        #expect(plankCopy.durationSeconds == 45)
        #expect(plankCopy.weight == nil && plankCopy.reps == nil && !plankCopy.isCompleted)
    }

    @Test func finishJoinsTitleLinesWithSpaces() throws {
        let workout = try workout(sets: 1)
        try log.toggleCompleted(try #require(workout.exercises.first?.sets.first))
        _ = try log.finish(workout, title: "Push\nDay ")
        #expect(workout.title == "Push Day")
    }

    @Test func finishThrowsAndGivesNoSummaryWhenSavingFails() throws {
        let store = try ReadOnlyStore { context in
            let workout = Workout(title: "Push Day", startDate: .now)
            let workoutExercise = WorkoutExercise(
                exercise: Exercise(
                    name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell,
                    kind: .weightReps),
                position: 0)
            let checked = WorkoutSet(position: 0, weight: 20, reps: 10, isCompleted: true)
            let unchecked = WorkoutSet(position: 1, weight: 20, reps: 10)
            context.insert(workout)
            workout.exercises.append(workoutExercise)
            workoutExercise.sets.append(contentsOf: [checked, unchecked])
        }
        defer { store.remove() }
        let log = WorkoutLog(context: store.context)
        let workout = try #require(log.inProgressWorkout())
        let setIDs = Set(workout.exercises.flatMap(\.sets).map(\.id))
        #expect(setIDs.count == 2)

        #expect(throws: (any Error).self) {
            _ = try log.finish(workout, title: "Leg Day")
        }

        // The workout is still in progress, unchanged, and nothing is pending for a later save.
        #expect(!store.context.hasChanges)
        let resumed = try #require(log.inProgressWorkout())
        #expect(resumed.id == workout.id)
        #expect(resumed.title == "Push Day")
        #expect(resumed.endDate == nil)
        #expect(Set(resumed.exercises.flatMap(\.sets).map(\.id)) == setIDs)
        #expect(try store.context.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
        #expect(log.finishedWorkoutCount() == 0)
    }

    @Test func discardDeletesTheWorkoutWithItsSets() throws {
        let workout = try workout(sets: 2)
        try log.discard(workout)
        #expect(log.inProgressWorkout() == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
    }

    @Test func removingAnExerciseNeedsConfirmationOnlyWithACheckedSet() throws {
        let workout = try workout(sets: 2)
        let bench = try #require(workout.exercises.first)
        #expect(!WorkoutLog.needsRemovalConfirmation(bench))

        try log.toggleCompleted(WorkoutLog.orderedSets(of: bench)[1])
        #expect(WorkoutLog.needsRemovalConfirmation(bench))

        try log.toggleCompleted(WorkoutLog.orderedSets(of: bench)[1])
        #expect(!WorkoutLog.needsRemovalConfirmation(bench))
    }

    @Test func reorderingNeedsAtLeastTwoExercises() throws {
        let workout = try workout(sets: 1)
        #expect(!WorkoutLog.canReorder(workout))

        try log.addExercise(try exercise("Hammer Curl"), to: workout)
        #expect(WorkoutLog.canReorder(workout))
    }

    @Test func theInProgressDescriptorFindsOnlyAWorkoutWithNoEndDate() throws {
        let context = container.mainContext
        #expect(try context.fetch(WorkoutLog.inProgressWorkouts).isEmpty)

        let workout = try workout(sets: 1)
        #expect(try context.fetch(WorkoutLog.inProgressWorkouts) == [workout])

        try log.toggleCompleted(try #require(workout.exercises.first?.sets.first))
        _ = try log.finish(workout, title: "Push Day")
        #expect(try context.fetch(WorkoutLog.inProgressWorkouts).isEmpty)
    }

    @Test func checkingOffTheLastUncheckedSetStartsNoRestAndReportsAllSetsDone() throws {
        let workout = try workout(sets: 2)
        let sets = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        sets[1].repsText = ""
        #expect(try log.checkOff(sets[0], in: workout, defaultRest: 90) == .focus(sets[1]))
        #expect(restTimer.isRunning)
        restTimer.skip()

        sets[1].repsText = "5"
        #expect(try log.checkOff(sets[1], in: workout, defaultRest: 90) == .allSetsDone)
        #expect(sets[1].isCompleted)
        #expect(!restTimer.isRunning)
    }

    @Test func checkingOffAnEarlierSetStartsTheRestAndReportsNoneDone() throws {
        let workout = try workout(sets: 2)
        let sets = WorkoutLog.orderedSets(of: WorkoutLog.orderedExercises(of: workout)[0])
        sets[1].repsText = ""
        #expect(try log.checkOff(sets[0], in: workout, defaultRest: 90) == .focus(sets[1]))
        #expect(restTimer.isRunning)
        #expect(restTimer.remaining == 90)
        #expect(restTimer.checkedSet === sets[0])
    }

    @Test func aSetThatCannotBeCheckedOffChangesNothingAndStartsNoRest() throws {
        let workout = try workout(sets: 1)
        let set = try #require(workout.exercises.first?.sets.first)
        set.repsText = ""
        #expect(try log.checkOff(set, in: workout, defaultRest: 90) == .focus(nil))
        #expect(!set.isCompleted)
        #expect(!restTimer.isRunning)
    }
}
