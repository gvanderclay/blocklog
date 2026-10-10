import SwiftData
import Testing

@testable import Blocklog

/// Opens committed stores written by earlier versions of the models with the current schema.
@MainActor
struct StoreMigrationTests {
    @Test func everyExerciseKeepsItsTypeAfterTheKindToTypeRename() throws {
        let fixture = try FixtureStore("before-35")
        defer { fixture.remove() }
        let exercises = try fixture.context.fetch(FetchDescriptor<Exercise>())

        let types = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0.type) })
        #expect(
            types == [
                "Dumbbell Bench Press": .weightReps, "Pull-Up": .bodyweightReps, "Plank": .duration,
            ])
        #expect(exercises.first { $0.name == "Plank" }?.isCustom == true)
    }

    @Test func routinesSurviveTheProgrammeChangeInMyRoutines() throws {
        let fixture = try FixtureStore("before-34a")
        defer { fixture.remove() }
        let routines = try fixture.context.fetch(RoutineLibrary.routinesByName)

        #expect(routines.map(\.name) == ["Core", "Pull", "Push"])
        #expect(routines.allSatisfy { $0.membership == nil })
        #expect(routines.map { RoutineLibrary.orderedExercises(of: $0).count } == [1, 1, 2])
        #expect(routines.last?.workouts.count == 1)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Programme>()) == 0)
    }

    @Test func exercisesSurviveThePerSideFieldWithNoneMarkedPerSide() throws {
        let fixture = try FixtureStore("before-32a")
        defer { fixture.remove() }
        let exercises = try fixture.context.fetch(FetchDescriptor<Exercise>())

        #expect(exercises.count == 67)
        #expect(exercises.allSatisfy { $0.isPerSide == nil })
        #expect(!exercises.contains { $0.muscleGroup == .stretching })
        let bench = try #require(exercises.first { $0.name == "Dumbbell Bench Press" })
        #expect(bench.restOverrideSeconds == 120)
        #expect(bench.workoutExercises.count == 1)
        #expect(bench.routineExercises.count == 1)
        #expect(exercises.first { $0.name == "cat-cow" }?.isCustom == true)
    }

    @Test func routinesAndWorkoutsSurviveTheFormatFieldsAsSets() throws {
        let fixture = try FixtureStore("before-33a")
        defer { fixture.remove() }
        let routines = try fixture.context.fetch(RoutineLibrary.routinesByName)

        #expect(routines.map(\.name) == ["Core", "Push"])
        #expect(routines.allSatisfy { $0.formatRawValue == nil && $0.timeCapSeconds == nil })
        #expect(routines.allSatisfy { $0.format == .sets })
        let push = try #require(routines.last)
        #expect(push.membership?.programme.name == "PPL")
        #expect(
            RoutineLibrary.orderedExercises(of: push).map(RoutineLibrary.summary(of:)) == [
                "2 × 8–12"
            ])
        let workout = try #require(try fixture.context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.routine === push)
        #expect(workout.formatRawValue == nil)
        #expect(workout.amrapRounds == nil)
        #expect(workout.amrapExtraReps == nil)
        #expect(workout.format == .sets)
        #expect(workout.exercises.first?.sets.first?.reps == 12)
    }
}
