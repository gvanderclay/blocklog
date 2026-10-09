import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks previous numbers and the tap-to-copy against an in-memory store seeded with the starters.
@MainActor
struct PreviousSetLookupTests {
    let container: ModelContainer
    let log: WorkoutLog

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
    }

    private func lookup(_ set: WorkoutSet) -> PreviousValues? {
        PreviousSetLookup(context: container.mainContext).previous(for: set)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    /// Logs a workout of `name` with one set per (type, weight, reps) entry, all checked off. It is finished
    /// one hour after `start`, or left in progress when `finished` is false.
    private func workout(
        starting start: Date, _ name: String = "Dumbbell Bench Press",
        sets: [(SetType, Double, Int)], finished: Bool = true
    ) throws -> Workout {
        let workout = try #require(try log.startEmptyWorkout(at: start))
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
        if finished {
            _ = try log.finish(workout, title: "Push Day", at: start.addingTimeInterval(3600))
        }
        return workout
    }

    /// The day with the given number in October 2026, at noon.
    private func day(_ number: Int) throws -> Date {
        try #require(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: number, hour: 12)))
    }

    /// The sets of the workout's first exercise with the given name, in position order.
    private func sets(of workout: Workout, _ name: String = "Dumbbell Bench Press") throws
        -> [WorkoutSet]
    {
        let match = try #require(
            WorkoutLog.orderedExercises(of: workout).first { $0.exercise?.name == name })
        return WorkoutLog.orderedSets(of: match)
    }

    @Test func theMostRecentFinishedWorkoutWins() throws {
        // The later workout is logged first, so the answer can't come from insertion order.
        _ = try workout(starting: try day(9), sets: [(.normal, 20, 8)])
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try workout(starting: try day(12), sets: [(.normal, 5, 1)], finished: false)

        let set = try #require(try sets(of: current).first)
        #expect(lookup(set)?.weight == 20)
        #expect(lookup(set)?.reps == 8)
    }

    @Test func warmUpsAreSkippedOnBothSides() throws {
        _ = try workout(
            starting: try day(7), sets: [(.warmUp, 5, 10), (.normal, 15, 8), (.normal, 20, 6)])
        let current = try workout(
            starting: try day(12), sets: [(.warmUp, 5, 10), (.normal, 5, 1), (.normal, 5, 1)],
            finished: false)

        let currentSets = try sets(of: current)
        #expect(lookup(currentSets[0]) == nil)
        #expect(lookup(currentSets[1])?.weight == 15)
        #expect(lookup(currentSets[1])?.reps == 8)
        #expect(lookup(currentSets[2])?.weight == 20)
        #expect(lookup(currentSets[2])?.reps == 6)
    }

    @Test func theWarmUpVariantPairsWarmUpsByOrderAmongWarmUps() throws {
        _ = try workout(
            starting: try day(7), sets: [(.warmUp, 5, 12), (.normal, 20, 6), (.warmUp, 10, 8)])
        let current = try workout(
            starting: try day(12),
            sets: [(.warmUp, 5, 1), (.normal, 5, 1), (.warmUp, 5, 1), (.warmUp, 5, 1)],
            finished: false)

        let warmUpLookup = PreviousSetLookup(context: container.mainContext)
        let currentSets = try sets(of: current)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[0])?.weight == 5)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[0])?.reps == 12)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[1]) == nil)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[2])?.weight == 10)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[2])?.reps == 8)
        #expect(warmUpLookup.previousWarmUp(for: currentSets[3]) == nil)
    }

    @Test func setsPastThePreviousCountGetNothing() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try workout(
            starting: try day(12), sets: [(.normal, 5, 1), (.normal, 5, 1)], finished: false)

        let currentSets = try sets(of: current)
        #expect(lookup(currentSets[0])?.weight == 15)
        #expect(lookup(currentSets[1]) == nil)
    }

    @Test func anInProgressWorkoutIsIgnored() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        // The workout being looked up is finished; a newer workout with the exercise is still in progress.
        let current = try workout(starting: try day(8), sets: [(.normal, 5, 1)])
        let inProgress = try workout(
            starting: try day(9), sets: [(.normal, 25, 5)], finished: false)
        #expect(inProgress.endDate == nil)

        #expect(lookup(try #require(try sets(of: current).first))?.weight == 15)
    }

    @Test func theWorkoutBeingEditedIsNotItsOwnPrevious() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let edited = try workout(starting: try day(9), sets: [(.normal, 25, 3)])

        let set = try #require(try sets(of: edited).first)
        #expect(lookup(set)?.weight == 15)
        #expect(lookup(set)?.reps == 10)
    }

    @Test func editingASetInTheSourceWorkoutChangesTheResult() throws {
        let source = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try workout(starting: try day(12), sets: [(.normal, 5, 1)], finished: false)
        let set = try #require(try sets(of: current).first)
        #expect(lookup(set)?.weight == 15)

        let sourceSet = try #require(try sets(of: source).first)
        try log.setWeight(20, of: sourceSet)
        sourceSet.repsText = "12"
        try log.context.saveOrRollBack()

        #expect(lookup(set)?.weight == 20)
        #expect(lookup(set)?.reps == 12)
    }

    @Test func deletingTheSourceWorkoutFallsBackToTheOneBefore() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let newer = try workout(starting: try day(9), sets: [(.normal, 20, 8)])
        let current = try workout(starting: try day(12), sets: [(.normal, 5, 1)], finished: false)
        let set = try #require(try sets(of: current).first)
        #expect(lookup(set)?.weight == 20)

        try log.discard(newer)

        #expect(lookup(set)?.weight == 15)
        #expect(lookup(set)?.reps == 10)
    }

    @Test func anExerciseNeverDoneGivesNothing() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try workout(
            starting: try day(12), "Hammer Curl", sets: [(.normal, 5, 1)], finished: false)

        #expect(lookup(try #require(try sets(of: current, "Hammer Curl").first)) == nil)
    }

    @Test func theFirstOccurrenceInTheSourceWorkoutWins() throws {
        // A finished workout with the bench twice: the first occurrence is 15 × 10, the second 30 × 2.
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        for (weight, reps) in [(15.0, 10), (30.0, 2)] {
            try log.addExercise(try exercise("Dumbbell Bench Press"), to: source)
            let added = try #require(WorkoutLog.orderedExercises(of: source).last)
            let set = try #require(WorkoutLog.orderedSets(of: added).first)
            try log.setWeight(weight, of: set)
            set.repsText = String(reps)
            try log.toggleCompleted(set)
        }
        _ = try log.finish(source, title: "Push Day", at: try day(7))
        let current = try workout(starting: try day(12), sets: [(.normal, 5, 1)], finished: false)

        #expect(lookup(try #require(try sets(of: current).first))?.weight == 15)
        #expect(lookup(try #require(try sets(of: current).first))?.reps == 10)
    }

    @Test func tappingPreviousCopiesItIntoAnUncheckedSet() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try #require(try log.startEmptyWorkout(at: try day(12)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: current)
        let set = try #require(current.exercises.first?.sets.first)
        #expect(set.weight == 5)

        #expect(try log.copyPrevious(to: set))
        #expect(set.weight == 15)
        #expect(set.reps == 10)
        #expect(!set.isCompleted)
    }

    @Test func dropAndFailureSetsPairLikeNormalSets() throws {
        _ = try workout(
            starting: try day(7),
            sets: [(.normal, 20, 8), (.drop, 15, 10), (.failure, 10, 12)])
        let current = try workout(
            starting: try day(12),
            sets: [(.normal, 5, 1), (.normal, 5, 1), (.normal, 5, 1), (.normal, 5, 1)],
            finished: false)

        let currentSets = try sets(of: current)
        #expect(lookup(currentSets[0])?.weight == 20)
        #expect(lookup(currentSets[1])?.weight == 15)
        #expect(lookup(currentSets[1])?.reps == 10)
        #expect(lookup(currentSets[2])?.weight == 10)
        #expect(lookup(currentSets[2])?.reps == 12)
        #expect(lookup(currentSets[3]) == nil)
    }

    @Test func tappingPreviousCopiesAddedWeightAndRepsForBodyweight() throws {
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise("Push-up"), to: source)
        let sourceSet = try #require(try sets(of: source, "Push-up").first)
        try log.setAddedWeight(10, of: sourceSet)
        sourceSet.repsText = "8"
        try log.toggleCompleted(sourceSet)
        _ = try log.finish(source, title: "Push Day", at: try day(7))

        let current = try #require(try log.startEmptyWorkout(at: try day(12)))
        try log.addExercise(try exercise("Push-up"), to: current)
        let set = try #require(try sets(of: current, "Push-up").first)
        #expect(set.weight == nil)

        #expect(try log.copyPrevious(to: set))
        #expect(set.weight == 10)
        #expect(set.reps == 8)
        #expect(set.durationSeconds == nil)
    }

    @Test func tappingPreviousCopiesTheDurationForADurationExercise() throws {
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise("Plank"), to: source)
        let sourceSet = try #require(try sets(of: source, "Plank").first)
        sourceSet.durationText = "45"
        try log.toggleCompleted(sourceSet)
        _ = try log.finish(source, title: "Core", at: try day(7))

        let current = try #require(try log.startEmptyWorkout(at: try day(12)))
        try log.addExercise(try exercise("Plank"), to: current)
        let set = try #require(try sets(of: current, "Plank").first)
        #expect(set.durationSeconds == nil)

        #expect(try log.copyPrevious(to: set))
        #expect(set.durationSeconds == 45)
        #expect(!set.isCompleted)
    }

    @Test func tappingPreviousOnACheckedSetChangesNothing() throws {
        _ = try workout(starting: try day(7), sets: [(.normal, 15, 10)])
        let current = try #require(try log.startEmptyWorkout(at: try day(12)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: current)
        let set = try #require(current.exercises.first?.sets.first)
        set.repsText = "3"
        try log.toggleCompleted(set)

        #expect(try log.copyPrevious(to: set) == false)
        #expect(set.weight == 5)
        #expect(set.reps == 3)
    }

    @Test func tappingPreviousWithNoPreviousChangesNothing() throws {
        let current = try #require(try log.startEmptyWorkout(at: try day(12)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: current)
        let set = try #require(current.exercises.first?.sets.first)

        #expect(try log.copyPrevious(to: set) == false)
        #expect(set.weight == 5)
        #expect(set.reps == nil)
    }

    @Test(arguments: [
        (
            ExerciseKind.weightReps, Double?.some(35), Int?.some(10), Int?.none, "35 lb × 10",
            "35 pounds times 10"
        ),
        (
            ExerciseKind.bodyweightReps, Double?.none, Int?.some(12), Int?.none, "BW × 12",
            "bodyweight times 12"
        ),
        (
            ExerciseKind.bodyweightReps, Double?.some(10), Int?.some(8), Int?.none, "+10 lb × 8",
            "10 pounds added times 8"
        ),
        (ExerciseKind.duration, Double?.none, Int?.none, Int?.some(45), "45 s", "45 seconds"),
    ])
    func previousValuesReadAsTheirDisplayFormats(
        kind: ExerciseKind, weight: Double?, reps: Int?, duration: Int?, shown: String,
        spoken: String
    ) {
        let values = PreviousValues(weight: weight, reps: reps, durationSeconds: duration)
        #expect(values.text(for: kind) == shown)
        #expect(values.spokenText(for: kind) == spoken)
    }
}
