import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks double progression when starting a workout from a routine, against an in-memory store seeded with
/// the starters. Routines here use the default range, 8–12.
@MainActor
struct ProgressionTests {
    let container: ModelContainer
    let log: WorkoutLog
    let start: RoutineStart

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
        start = RoutineStart(context: container.mainContext)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    private func day(_ number: Int) throws -> Date {
        try #require(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: number, hour: 12)))
    }

    /// Logs and finishes a workout of `name` with one checked set per (type, weight, reps) entry; a nil
    /// weight is bodyweight.
    private func logFinished(
        _ name: String = "Dumbbell Bench Press", sets: [(SetType, Double?, Int)]
    ) throws {
        let workout = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise(name), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        for (index, spec) in sets.enumerated() {
            if index > 0 { try log.addSet(to: workoutExercise) }
            let set = WorkoutLog.orderedSets(of: workoutExercise)[index]
            try log.setType(spec.0, of: set)
            try log.setWeight(spec.1, of: set)
            set.repsText = String(spec.2)
            try log.toggleCompleted(set)
        }
        _ = try log.finish(workout, title: "Logged", at: try day(7).addingTimeInterval(3600))
    }

    /// Starts a routine of `name` with the given planned set types and returns its workout exercise and the
    /// progressions the start applied.
    private func started(
        _ name: String = "Dumbbell Bench Press", types: [SetType] = [.normal, .normal, .normal]
    ) throws -> (WorkoutExercise, AppliedProgressions) {
        let started = try startedWorkout(name, types: types)
        return (try #require(started.workout.exercises.first), started.progressions)
    }

    private func startedWorkout(
        _ name: String = "Dumbbell Bench Press", types: [SetType] = [.normal, .normal, .normal]
    ) throws -> RoutineStart.Started {
        var draft = RoutineDraft()
        draft.name = "Routine"
        draft.addExercise(try exercise(name))
        draft.exercises[0].sets = types.map { RoutineDraft.PlannedSet(type: $0) }
        let routine = try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))
        return try #require(try start.startWorkout(from: routine, at: try day(9)))
    }

    @Test func topOfTheRangeOnEverySetStepsUpAcrossTheGap() throws {
        try logFinished(sets: [(.normal, 10, 12), (.normal, 10, 12), (.normal, 10, 12)])

        let (workoutExercise, progressions) = try started()

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [15, 15, 15])
        #expect(sets.map(\.reps) == [8, 8, 8])
        #expect(
            progressions.note(for: workoutExercise)?.note
                == "↑ Up from 10 lb: you hit 12 on every set")
    }

    @Test func oneSetShortKeepsLastTimeAndGivesNoNote() throws {
        try logFinished(sets: [(.normal, 10, 12), (.normal, 10, 11), (.normal, 10, 12)])

        let (workoutExercise, progressions) = try started()

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [10, 10, 10])
        #expect(sets.map(\.reps) == [12, 11, 12])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func warmUpsAndDropSetsAreIgnoredForTheDecisionAndPreFilledAsLastTime() throws {
        try logFinished(
            sets: [(.warmUp, 5, 5), (.normal, 20, 12), (.normal, 20, 12), (.drop, 7.5, 6)])

        let (workoutExercise, progressions) = try started(types: [.warmUp, .normal, .normal, .drop])

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [5, 25, 25, 7.5])
        #expect(sets.map(\.reps) == [5, 8, 8, 6])
        #expect(
            progressions.note(for: workoutExercise)?.note
                == "↑ Up from 20 lb: you hit 12 on every set")
    }

    @Test func aFailureSetCountsAndIsStepped() throws {
        try logFinished(sets: [(.normal, 20, 12), (.failure, 20, 12)])

        let (workoutExercise, _) = try started(types: [.normal, .failure])

        #expect(WorkoutLog.orderedSets(of: workoutExercise).map(\.weight) == [25, 25])
    }

    @Test func aFailureSetShortOfTheTopStopsProgression() throws {
        try logFinished(sets: [(.normal, 20, 12), (.failure, 20, 9)])

        let (workoutExercise, progressions) = try started(types: [.normal, .failure])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func noProgressionSetsLastTimeProgressesNothing() throws {
        try logFinished(sets: [(.warmUp, 5, 12), (.drop, 10, 12)])

        let (workoutExercise, progressions) = try started(types: [.warmUp, .normal])

        #expect(progressions.note(for: workoutExercise) == nil)
        // The normal set pairs with last time's first counted set, the drop set.
        #expect(WorkoutLog.orderedSets(of: workoutExercise).map(\.weight) == [5, 10])
    }

    @Test func atNinetyPoundsNothingChanges() throws {
        try logFinished(sets: [(.normal, 90, 12), (.normal, 90, 12)])

        let (workoutExercise, progressions) = try started(types: [.normal, .normal])

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [90, 90])
        #expect(sets.map(\.reps) == [12, 12])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func mixedWeightsStepUpFromTheHeaviest() throws {
        try logFinished(sets: [(.normal, 30, 12), (.normal, 35, 12)])

        let (workoutExercise, progressions) = try started(types: [.normal, .normal])

        #expect(WorkoutLog.orderedSets(of: workoutExercise).map(\.weight) == [37.5, 37.5])
        #expect(
            progressions.note(for: workoutExercise)?.note
                == "↑ Up from 35 lb: you hit 12 on every set")
    }

    @Test func addedWeightProgressesLikeDumbbells() throws {
        try logFinished("Push-up", sets: [(.normal, 10, 12), (.normal, 10, 12)])

        let (workoutExercise, progressions) = try started("Push-up", types: [.normal, .normal])

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [15, 15])
        #expect(sets.map(\.reps) == [8, 8])
        #expect(
            progressions.note(for: workoutExercise)?.note
                == "↑ Up from +10 lb: you hit 12 on every set")
    }

    @Test func bodyweightWithNoAddedWeightGetsOnlyTheNote() throws {
        try logFinished("Push-up", sets: [(.normal, nil, 12), (.normal, nil, 13)])

        let (workoutExercise, progressions) = try started("Push-up", types: [.normal, .normal])

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [nil, nil])
        #expect(sets.map(\.reps) == [12, 13])
        let note = try #require(progressions.note(for: workoutExercise))
        #expect(note.note == "You hit 12 on every set: consider adding weight")
        #expect(!note.showsArrow)
    }

    @Test func bodyweightShortOfTheTopGetsNoNote() throws {
        try logFinished("Push-up", sets: [(.normal, nil, 12), (.normal, nil, 10)])

        let (workoutExercise, progressions) = try started("Push-up", types: [.normal, .normal])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func aTimedExerciseGetsNoNote() throws {
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise("Plank"), to: source)
        let logged = try #require(source.exercises.first?.sets.first)
        logged.durationText = "60"
        try log.toggleCompleted(logged)
        _ = try log.finish(source, title: "Core", at: try day(7))

        let (workoutExercise, progressions) = try started("Plank", types: [.normal])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func aFreeformWorkoutGetsNoNote() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        let workout = try #require(try log.startEmptyWorkout(at: try day(9)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)

        let workoutExercise = try #require(workout.exercises.first)
        #expect(Progression(context: container.mainContext).suggestion(for: workoutExercise) == nil)
    }

    @Test func theMostRecentWorkoutDecides() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        let later = try #require(try log.startEmptyWorkout(at: try day(8)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: later)
        let set = try #require(later.exercises.first?.sets.first)
        try log.setWeight(15, of: set)
        set.repsText = "9"
        try log.toggleCompleted(set)
        _ = try log.finish(later, title: "Later", at: try day(8))

        let (workoutExercise, progressions) = try started(types: [.normal])
        #expect(progressions.note(for: workoutExercise) == nil)
    }

    @Test func decreasingTheProgressedWeightStepsBackToTheOldOne() throws {
        try logFinished(sets: [(.normal, 10, 12), (.normal, 10, 12)])
        var (workoutExercise, progressions) = try started(types: [.normal, .normal])
        let first = try #require(WorkoutLog.orderedSets(of: workoutExercise).first)
        #expect(progressions.isHighlighted(first))

        try log.setWeight(try #require(PowerBlockTable.stepDown(from: first.weight)), of: first)
        progressions.weightChanged(of: first)

        #expect(first.weight == 10)
        #expect(!progressions.isHighlighted(first))
    }

    @Test func onlyTheSetsProgressionPreFilledStartHighlighted() throws {
        try logFinished(
            sets: [(.warmUp, 5, 5), (.normal, 20, 12), (.failure, 20, 12), (.drop, 7.5, 6)])

        let (workoutExercise, progressions) = try started(
            types: [.warmUp, .normal, .failure, .drop])

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(progressions.isHighlighted) == [false, true, true, false])
    }

    @Test func returningToTheSuggestedWeightDoesNotBringTheHighlightBack() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        var (workoutExercise, progressions) = try started(types: [.normal])
        let set = try #require(WorkoutLog.orderedSets(of: workoutExercise).first)

        try log.setWeight(10, of: set)
        progressions.weightChanged(of: set)
        try log.setWeight(15, of: set)
        progressions.weightChanged(of: set)

        #expect(set.weight == 15)
        #expect(!progressions.isHighlighted(set))
    }

    @Test func uncheckingASetDoesNotBringTheHighlightBack() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        var (workoutExercise, progressions) = try started(types: [.normal])
        let set = try #require(WorkoutLog.orderedSets(of: workoutExercise).first)

        try log.toggleCompleted(set)
        progressions.checkedOff(set)
        #expect(!progressions.isHighlighted(set))
        try log.toggleCompleted(set)
        progressions.checkedOff(set)

        #expect(!set.isCompleted)
        #expect(!progressions.isHighlighted(set))
    }

    @Test func aSetAddedOrDuplicatedLaterIsNotHighlighted() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        let (workoutExercise, progressions) = try started(types: [.normal])
        let first = try #require(WorkoutLog.orderedSets(of: workoutExercise).first)

        try log.duplicateSet(first)
        try log.addSet(to: workoutExercise)

        let sets = WorkoutLog.orderedSets(of: workoutExercise)
        #expect(sets.map(\.weight) == [15, 15, 15])
        #expect(sets.map(progressions.isHighlighted) == [true, false, false])
    }

    @Test func aWorkoutWithoutProgressionHighlightsNothing() throws {
        try logFinished(sets: [(.normal, 10, 11)])

        let (workoutExercise, progressions) = try started(types: [.normal])

        #expect(
            WorkoutLog.orderedSets(of: workoutExercise).map(progressions.isHighlighted) == [false])
    }

    @Test func bodyweightWithNoAddedWeightHighlightsNothing() throws {
        try logFinished("Push-up", sets: [(.normal, nil, 12)])

        let (workoutExercise, progressions) = try started("Push-up", types: [.normal])

        #expect(progressions.note(for: workoutExercise) != nil)
        #expect(
            WorkoutLog.orderedSets(of: workoutExercise).map(progressions.isHighlighted) == [false])
    }

    @Test func anExerciseRemovedAndAddedAgainGetsNoNote() throws {
        try logFinished(sets: [(.normal, 10, 12)])
        let routineStart = try startedWorkout(types: [.normal])
        let workout = routineStart.workout
        let original = try #require(workout.exercises.first)
        #expect(routineStart.progressions.note(for: original) != nil)

        try log.removeExercise(original)
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)

        let readded = try #require(workout.exercises.first)
        #expect(routineStart.progressions.note(for: readded) == nil)
        #expect(routineStart.progressions.isHighlighted(try #require(readded.sets.first)) == false)
    }

    @Test func changingTheRangeAfterStartingAddsNoNote() throws {
        try logFinished(sets: [(.normal, 10, 10)])
        let routineStart = try startedWorkout(types: [.normal])
        let workoutExercise = try #require(routineStart.workout.exercises.first)
        #expect(routineStart.progressions.note(for: workoutExercise) == nil)

        let routineExercise = try #require(routineStart.workout.routine?.exercises.first)
        routineExercise.repRangeHigh = 10

        #expect(routineStart.progressions.note(for: workoutExercise) == nil)
        #expect(!routineStart.progressions.isHighlighted(try #require(workoutExercise.sets.first)))
    }
}
