import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the grey number in an empty reps or seconds field against an in-memory store seeded with the starters.
@MainActor
struct SetPlaceholderTests {
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

    private func day(_ number: Int) throws -> Date {
        try #require(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: number, hour: 12)))
    }

    private func placeholder(_ set: WorkoutSet) -> Int? {
        SetPlaceholder(context: container.mainContext).value(for: set)
    }

    /// Logs and finishes a workout of `name` whose sets have the given types and numbers (reps or seconds).
    private func logFinished(
        on date: Date, _ name: String = "Dumbbell Bench Press", sets: [(SetType, Int)]
    ) throws {
        let workout = try #require(try log.startEmptyWorkout(at: date))
        try log.addExercise(try exercise(name), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        for (index, spec) in sets.enumerated() {
            if index > 0 { try log.addSet(to: workoutExercise) }
            let set = WorkoutLog.orderedSets(of: workoutExercise)[index]
            try log.setType(spec.0, of: set)
            set.values = set.values.filling(spec.1)
            try log.toggleCompleted(set)
        }
        _ = try log.finish(workout, title: "Done", at: date.addingTimeInterval(3600))
    }

    /// An in-progress freeform workout of the exercise with `count` empty sets.
    private func freeform(_ name: String = "Dumbbell Bench Press", sets count: Int) throws
        -> [WorkoutSet]
    {
        let workout = try #require(try log.startEmptyWorkout(at: try day(20)))
        try log.addExercise(try exercise(name), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        for _ in 1..<count { try log.addSet(to: workoutExercise) }
        return WorkoutLog.orderedSets(of: workoutExercise)
    }

    @Test func theRepRangesLowEndWinsOverPrevious() throws {
        try logFinished(on: try day(5), sets: [(.normal, 12)])
        var draft = RoutineDraft()
        draft.name = "Push"
        draft.addExercise(try exercise("Dumbbell Bench Press"))
        draft.exercises[0].repLow = 6
        draft.exercises[0].repHigh = 10
        let routine = try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))
        let workout = try #require(
            try RoutineStart(context: container.mainContext).startWorkout(
                from: routine, at: try day(9))?.workout)
        let set = try #require(WorkoutLog.orderedExercises(of: workout).first?.sets.first)
        set.reps = nil

        #expect(placeholder(set) == 6)
    }

    @Test func previousIsUsedWithNoRange() throws {
        try logFinished(on: try day(5), sets: [(.normal, 12)])
        let sets = try freeform(sets: 1)
        #expect(placeholder(sets[0]) == 12)
    }

    @Test func aWarmUpUsesLastTimesWarmUp() throws {
        try logFinished(on: try day(5), sets: [(.warmUp, 15), (.normal, 8)])
        let sets = try freeform(sets: 2)
        try log.setType(.warmUp, of: sets[0])
        #expect(placeholder(sets[0]) == 15)
        #expect(placeholder(sets[1]) == 8)
    }

    @Test func theSetAboveIsUsedWithNoPrevious() throws {
        let sets = try freeform(sets: 2)
        sets[0].reps = 9
        #expect(placeholder(sets[1]) == 9)
    }

    @Test func aChainOfEmptySetsInheritsFromAbove() throws {
        let sets = try freeform(sets: 3)
        sets[0].reps = 9
        #expect(placeholder(sets[2]) == 9)
    }

    @Test func aFreeformFirstSetWithNoHistoryHasNone() throws {
        let sets = try freeform(sets: 1)
        #expect(placeholder(sets[0]) == nil)
    }

    @Test func aDurationSetUsesThePreviousSeconds() throws {
        try logFinished(on: try day(5), "Plank", sets: [(.normal, 45)])
        let sets = try freeform("Plank", sets: 1)
        sets[0].durationSeconds = nil
        #expect(placeholder(sets[0]) == 45)
    }

    @Test func aSummaryShowsWhatCheckingOffWouldLog() throws {
        let sets = try freeform(sets: 3)
        sets[0].reps = 9
        #expect(
            SetPlaceholder(context: container.mainContext).summaryValues(for: sets[1]).reps == 9)
        sets[1].reps = 0
        #expect(
            SetPlaceholder(context: container.mainContext).summaryValues(for: sets[1]).reps == 9)
        #expect(sets[1].reps == 0)
        #expect(
            SetPlaceholder(context: container.mainContext).summaryValues(for: sets[2]).reps == 9)
    }

    @Test func aCheckedSetsSummaryShowsItsOwnValues() throws {
        let sets = try freeform(sets: 2)
        sets[0].reps = 9
        sets[1].reps = nil
        sets[1].isCompleted = true  // a past set with no reps, as an import can hold
        let summary = SetPlaceholder(context: container.mainContext).summaryValues(for: sets[1])
        #expect(summary.reps == nil)
        #expect(
            SetPlaceholder(context: container.mainContext).summaryValues(for: sets[0]).reps == 9)
    }

    @Test func aSummaryWithNoPlaceholderShowsTheEmptyValue() throws {
        let sets = try freeform(sets: 1)
        let summary = SetPlaceholder(context: container.mainContext).summaryValues(for: sets[0])
        #expect(summary.text == "5 lb × —")
    }
}
