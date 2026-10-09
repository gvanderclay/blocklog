import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks which of a set's weight, reps and seconds apply for each exercise type, with plain values.
@MainActor
struct SetValuesTests {
    @Test(arguments: [
        (
            ExerciseType.weightReps, Double?.some(35), Int?.some(10), Int?.some(45),
            SetValues.weightReps(weight: 35, reps: 10)
        ),
        (.weightReps, nil, nil, nil, .weightReps(weight: 5, reps: nil)),
        (.bodyweightReps, 10, 8, 45, .bodyweightReps(addedWeight: 10, reps: 8)),
        (.bodyweightReps, nil, nil, nil, .bodyweightReps(addedWeight: nil, reps: nil)),
        (.duration, 35, 10, 45, .duration(seconds: 45)),
        (.duration, nil, nil, nil, .duration(seconds: nil)),
    ])
    func storedFieldsReadAsTheValuesOfTheirType(
        type: ExerciseType, weight: Double?, reps: Int?, seconds: Int?, expected: SetValues
    ) {
        #expect(SetValues(type: type, weight: weight, reps: reps, seconds: seconds) == expected)
    }

    @Test(arguments: [
        (ExerciseType.weightReps, SetValues.weightReps(weight: 5, reps: nil)),
        (.bodyweightReps, .bodyweightReps(addedWeight: nil, reps: nil)),
        (.duration, .duration(seconds: nil)),
    ])
    func aFirstSetStartsAtFivePoundsOrBodyweightOrEmptySeconds(
        type: ExerciseType, expected: SetValues
    ) {
        #expect(SetValues.first(for: type) == expected)
    }

    @Test(arguments: [
        (SetValues.weightReps(weight: 5, reps: nil), false, true),
        (.weightReps(weight: 5, reps: 0), false, false),
        (.weightReps(weight: 5, reps: 1), true, false),
        (.bodyweightReps(addedWeight: nil, reps: nil), false, true),
        (.bodyweightReps(addedWeight: 10, reps: 0), false, false),
        (.bodyweightReps(addedWeight: nil, reps: 12), true, false),
        (.duration(seconds: nil), false, true),
        (.duration(seconds: 0), false, false),
        (.duration(seconds: 30), true, false),
    ])
    func aSetChecksOffWithRepsOrSecondsAndItsFieldIsEmptyWhenNil(
        values: SetValues, canCheckOff: Bool, isFieldEmpty: Bool
    ) {
        #expect(values.canCheckOff == canCheckOff)
        #expect(values.isFieldEmpty == isFieldEmpty)
    }

    @Test(arguments: [
        (
            SetValues.weightReps(weight: 5, reps: 10), Double?.some(15),
            SetValues?.some(.weightReps(weight: 15, reps: 10))
        ),
        (.weightReps(weight: 5, reps: 10), 12.5, nil),
        (.weightReps(weight: 5, reps: 10), nil, nil),
        (.bodyweightReps(addedWeight: nil, reps: 8), 10, .bodyweightReps(addedWeight: 10, reps: 8)),
        (
            .bodyweightReps(addedWeight: 10, reps: 8), nil,
            .bodyweightReps(addedWeight: nil, reps: 8)
        ),
        (.bodyweightReps(addedWeight: 10, reps: 8), 12.5, nil),
        (.duration(seconds: 30), 15, nil),
        (.duration(seconds: 30), nil, nil),
    ])
    func aWeightChangeTheTypeCannotHoldGivesNothing(
        values: SetValues, newWeight: Double?, expected: SetValues?
    ) {
        #expect(values.settingWeight(newWeight) == expected)
    }

    @Test(arguments: [
        // A duration set gets the target duration, or 30 s with none, whatever else is given.
        (
            ExerciseType.duration, SetValues?.none, (Double, Int)?.none, Int?.some(45),
            SetValues.duration(seconds: 45)
        ),
        (.duration, nil, nil, nil, .duration(seconds: 30)),
        (.duration, .duration(seconds: 60), (50, 8), 45, .duration(seconds: 45)),
        // A progression wins over last time.
        (
            .weightReps, .weightReps(weight: 30, reps: 12), (35, 8), nil,
            .weightReps(weight: 35, reps: 8)
        ),
        (
            .bodyweightReps, .bodyweightReps(addedWeight: nil, reps: 12), (10, 8), nil,
            .bodyweightReps(addedWeight: 10, reps: 8)
        ),
        // Otherwise last time's weight and reps.
        (
            .weightReps, .weightReps(weight: 30, reps: 12), nil, nil,
            .weightReps(weight: 30, reps: 12)
        ),
        (
            .bodyweightReps, .bodyweightReps(addedWeight: 10, reps: 8), nil, nil,
            .bodyweightReps(addedWeight: 10, reps: 8)
        ),
        (
            .bodyweightReps, .bodyweightReps(addedWeight: nil, reps: 8), nil, nil,
            .bodyweightReps(addedWeight: nil, reps: 8)
        ),
        // Nothing from last time: a first set.
        (.weightReps, nil, nil, nil, .weightReps(weight: 5, reps: nil)),
        (.bodyweightReps, nil, nil, nil, .bodyweightReps(addedWeight: nil, reps: nil)),
    ])
    func preFillingFollowsItsPriorities(
        type: ExerciseType, previous: SetValues?, progression: (Double, Int)?, target: Int?,
        expected: SetValues
    ) {
        let progression = progression.map { (weight: $0.0, reps: $0.1) }
        #expect(
            SetValues.prefilled(
                for: type, previous: previous, progression: progression, targetSeconds: target)
                == expected)
    }

    @Test(arguments: [
        (ExerciseType.weightReps, Double?.some(35), Int?.some(10), Int?.none, true),
        (.weightReps, nil, 10, nil, false),
        (.weightReps, 35, 0, nil, false),
        (.weightReps, 35, nil, nil, false),
        (.weightReps, 35, 10, 45, false),
        (.bodyweightReps, nil, 12, nil, true),
        (.bodyweightReps, 10, 1, nil, true),
        (.bodyweightReps, nil, nil, nil, false),
        (.bodyweightReps, nil, 12, 45, false),
        (.duration, nil, nil, 45, true),
        (.duration, nil, nil, 0, false),
        (.duration, 35, nil, 45, false),
        (.duration, nil, 10, 45, false),
    ])
    func aFinishedSetHoldsExactlyItsTypesValues(
        type: ExerciseType, weight: Double?, reps: Int?, seconds: Int?, isComplete: Bool
    ) {
        #expect(
            (SetValues(complete: type, weight: weight, reps: reps, seconds: seconds) != nil)
                == isComplete)
    }

    @Test func eachTypeSaysWhatItNeeds() {
        #expect(
            SetValues.requirement(of: .weightReps)
                == "that needs a weight and reps, and no duration")
        #expect(SetValues.requirement(of: .bodyweightReps) == "that needs reps and no duration")
        #expect(
            SetValues.requirement(of: .duration)
                == "that needs a duration and no weight or reps")
    }

    @Test func writingValuesToASetStoresThemAndClearsWhatItsTypeDoesNotRecord() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let plank = Exercise(
            name: "Plank", muscleGroup: .core, equipment: .bodyweight, type: .duration)
        let workoutExercise = WorkoutExercise(exercise: plank, position: 0)
        let set = WorkoutSet(position: 0, weight: 15, reps: 10)
        container.mainContext.insert(workoutExercise)
        container.mainContext.insert(set)
        workoutExercise.sets.append(set)

        // The stray weight and reps are not part of a duration set's values.
        #expect(set.values == .duration(seconds: nil))

        set.values = .duration(seconds: 45)
        #expect(set.durationSeconds == 45)
        #expect(set.weight == nil && set.reps == nil)
    }
}
