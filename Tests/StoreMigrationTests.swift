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
}
