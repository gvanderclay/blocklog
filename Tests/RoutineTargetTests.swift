import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks which of a routine exercise's range ends and seconds apply for each exercise type, with plain values.
@MainActor
struct RoutineTargetTests {
    @Test(arguments: [
        (
            ExerciseType.weightReps, Int?.some(6), Int?.some(10), Int?.some(45),
            RoutineTarget?.some(.repRange(6...10))
        ),
        (.bodyweightReps, 5, 5, nil, .repRange(5...5)),
        (.weightReps, 60, 80, nil, .repRange(60...80)),
        (.weightReps, nil, nil, 45, nil),
        (.weightReps, 6, nil, nil, nil),
        (.weightReps, nil, 10, nil, nil),
        (.weightReps, 12, 8, nil, nil),
        (.duration, 6, 10, 45, .duration(seconds: 45)),
        (.duration, nil, nil, 900, .duration(seconds: 900)),
        (.duration, 6, 10, nil, nil),
    ])
    func storedFieldsReadAsTheTargetOfTheirType(
        type: ExerciseType, low: Int?, high: Int?, seconds: Int?, expected: RoutineTarget?
    ) {
        #expect(
            RoutineTarget(
                type: type, repRangeLow: low, repRangeHigh: high, durationSeconds: seconds)
                == expected)
    }

    @Test(arguments: [
        (Int?.some(6), Int?.some(10), Int?.some(45), RoutineTarget?.some(.duration(seconds: 45))),
        (nil, nil, 45, .duration(seconds: 45)),
        (6, 10, nil, .repRange(6...10)),
        (12, 8, nil, nil),
        (nil, nil, nil, nil),
    ])
    func withNoExerciseStoredSecondsReadAsADurationAndAnythingElseAsARange(
        low: Int?, high: Int?, seconds: Int?, expected: RoutineTarget?
    ) {
        #expect(
            RoutineTarget(type: nil, repRangeLow: low, repRangeHigh: high, durationSeconds: seconds)
                == expected)
    }

    @Test(arguments: [
        (ExerciseType.weightReps, RoutineTarget.repRange(8...12)),
        (.bodyweightReps, .repRange(8...12)),
        (.duration, .duration(seconds: 30)),
    ])
    func aNewRoutineExerciseStartsAtEightToTwelveOrThirtySeconds(
        type: ExerciseType, expected: RoutineTarget
    ) {
        #expect(RoutineTarget.standard(for: type) == expected)
    }

    @Test(arguments: [
        (
            RoutineTarget?.some(.repRange(6...10)), ExerciseType.weightReps,
            RoutineTarget.repRange(6...10)
        ),
        (.repRange(6...10), .bodyweightReps, .repRange(6...10)),
        (.duration(seconds: 45), .duration, .duration(seconds: 45)),
        (.duration(seconds: 45), .weightReps, .repRange(8...12)),
        (.repRange(6...10), .duration, .duration(seconds: 30)),
        (nil, .weightReps, .repRange(8...12)),
        (nil, .duration, .duration(seconds: 30)),
    ])
    func aTargetOfTheOtherCaseOrNoneFallsBackToTheStandard(
        target: RoutineTarget?, type: ExerciseType, expected: RoutineTarget
    ) {
        #expect(RoutineTarget.orStandard(target, for: type) == expected)
    }

    @Test(arguments: [
        (1, 12, RoutineTarget?.some(.repRange(1...12))),
        (8, 50, .repRange(8...50)),
        (5, 5, .repRange(5...5)),
        (12, 8, nil),
        (0, 12, nil),
        (8, 51, nil),
    ])
    func importAcceptsARangeOfOneToFiftyWithTheLowEndFirst(
        low: Int, high: Int, expected: RoutineTarget?
    ) {
        #expect(RoutineTarget(validRepRangeLow: low, high: high) == expected)
    }

    @Test(arguments: [
        (1, RoutineTarget?.some(.duration(seconds: 1))),
        (900, .duration(seconds: 900)),
        (0, nil),
        (-5, nil),
    ])
    func importAcceptsAnyDurationAboveZero(seconds: Int, expected: RoutineTarget?) {
        #expect(RoutineTarget(validDurationSeconds: seconds) == expected)
    }

    @Test func theEditorsBoundsKeepTheEndsFromCrossingAndKeepAStoredEndOutsideThem() {
        #expect(RoutineTarget.lowBounds(of: 8...12) == 1...12)
        #expect(RoutineTarget.highBounds(of: 8...12) == 8...50)
        #expect(RoutineTarget.lowBounds(of: 10...10) == 1...10)
        #expect(RoutineTarget.highBounds(of: 10...10) == 10...50)
        #expect(RoutineTarget.highBounds(of: 60...80) == 60...60)
    }

    @Test func settingAnEndHoldsItAtTheOtherEndAndIgnoresTheWrongCase() {
        let range = RoutineTarget.repRange(8...12)
        #expect(range.settingLow(6) == .repRange(6...12))
        #expect(range.settingLow(20) == .repRange(12...12))
        #expect(range.settingHigh(15) == .repRange(8...15))
        #expect(range.settingHigh(3) == .repRange(8...8))
        #expect(range.settingSeconds(60) == range)
        let duration = RoutineTarget.duration(seconds: 30)
        #expect(duration.settingSeconds(60) == .duration(seconds: 60))
        #expect(duration.settingLow(6) == duration)
        #expect(duration.settingHigh(15) == duration)
    }

    @Test func aRoutineExerciseReadsAndWritesItsTargetThroughItsStoredFields() throws {
        // Held for the whole test: models crash once their container is freed.
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let bench = try #require(exercises.first { $0.name == "Dumbbell Bench Press" })
        let routineExercise = RoutineExercise(
            exercise: bench, position: 0, plannedSetTypes: [.normal], repRangeLow: 6,
            repRangeHigh: 10, targetDurationSeconds: 45)
        #expect(routineExercise.target == .repRange(6...10))

        routineExercise.target = .duration(seconds: 60)
        #expect(routineExercise.repRangeLow == nil)
        #expect(routineExercise.repRangeHigh == nil)
        #expect(routineExercise.targetDurationSeconds == 60)

        routineExercise.target = .repRange(8...12)
        #expect(routineExercise.repRangeLow == 8)
        #expect(routineExercise.repRangeHigh == 12)
        #expect(routineExercise.targetDurationSeconds == nil)

        routineExercise.target = nil
        #expect(routineExercise.repRangeLow == nil)
        #expect(routineExercise.repRangeHigh == nil)
        #expect(routineExercise.targetDurationSeconds == nil)
        #expect(routineExercise.target == nil)
    }
}
