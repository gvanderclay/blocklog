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
}
