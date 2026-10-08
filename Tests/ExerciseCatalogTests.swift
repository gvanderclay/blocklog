import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the picker's grouping and filtering, and creating custom exercises, against an in-memory store.
@MainActor
struct ExerciseCatalogTests {
    let container: ModelContainer
    let catalog: ExerciseCatalog

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        catalog = ExerciseCatalog(context: container.mainContext)
    }

    private func exercises(_ names: [(String, MuscleGroup, Equipment)]) -> [Exercise] {
        names.map { Exercise(name: $0.0, muscleGroup: $0.1, equipment: $0.2, kind: .weightReps) }
    }

    @Test func sectionsFollowMuscleGroupOrderSortByNameAndHideEmptyGroups() {
        let list = exercises([
            ("Shrug", .back, .dumbbell), ("Chest Fly", .chest, .dumbbell),
            ("Row", .back, .dumbbell), ("Bench Press", .chest, .dumbbell),
        ])
        let sections = ExerciseCatalog.sections(from: list, matching: "", equipment: nil)
        #expect(sections.map(\.muscleGroup) == [.chest, .back])
        #expect(sections[0].exercises.map(\.name) == ["Bench Press", "Chest Fly"])
        #expect(sections[1].exercises.map(\.name) == ["Row", "Shrug"])
    }

    @Test func searchMatchesIgnoringCaseAndDiacritics() {
        let list = exercises([("Café Row", .back, .dumbbell), ("Curl", .biceps, .dumbbell)])
        let names = ExerciseCatalog.sections(from: list, matching: " CAFE ", equipment: nil)
            .flatMap(\.exercises).map(\.name)
        #expect(names == ["Café Row"])
    }

    @Test func equipmentFilterKeepsOnlyThatEquipment() {
        let list = exercises([("Pull-up", .back, .pullUpBar), ("Row", .back, .dumbbell)])
        let names = ExerciseCatalog.sections(from: list, matching: "", equipment: .pullUpBar)
            .flatMap(\.exercises).map(\.name)
        #expect(names == ["Pull-up"])
    }

    @Test func emptyNameIsAProblemAndDuplicatesIgnoreCaseAndSpaces() {
        let list = exercises([("Dumbbell Bench Press", .chest, .dumbbell)])
        #expect(ExerciseCatalog.nameProblem(for: "  ", among: list) == .empty)
        #expect(
            ExerciseCatalog.nameProblem(for: " dumbbell BENCH press ", among: list) == .duplicate)
        #expect(ExerciseCatalog.nameProblem(for: "Test Row", among: list) == nil)
    }

    @Test func createsTrimmedCustomExerciseAndSaves() throws {
        let created = try #require(
            try catalog.createCustomExercise(
                named: "  Test Row  ", muscleGroup: .back, equipment: .dumbbell, kind: .weightReps))
        #expect(created.name == "Test Row")
        #expect(created.isCustom)
        #expect(created.muscleGroup == .back)

        let saved = try container.mainContext.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Test Row" }))
        #expect(saved.count == 1)
    }

    @Test func refusesDuplicatesButCreatesDurationExercises() throws {
        let before = try container.mainContext.fetchCount(FetchDescriptor<Exercise>())
        let duplicate = try catalog.createCustomExercise(
            named: "plank", muscleGroup: .core, equipment: .bodyweight, kind: .bodyweightReps)
        #expect(duplicate == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()) == before)

        let duration = try catalog.createCustomExercise(
            named: "Hollow Hold", muscleGroup: .core, equipment: .bodyweight, kind: .duration)
        #expect(duration?.kind == .duration)
    }
}
