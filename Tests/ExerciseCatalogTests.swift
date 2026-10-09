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
        names.map { Exercise(name: $0.0, muscleGroup: $0.1, equipment: $0.2, type: .weightReps) }
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
                named: "  Test Row  ", muscleGroup: .back, equipment: .dumbbell, type: .weightReps))
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
            named: "plank", muscleGroup: .core, equipment: .bodyweight, type: .bodyweightReps)
        #expect(duplicate == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()) == before)

        let duration = try catalog.createCustomExercise(
            named: "Hollow Hold", muscleGroup: .core, equipment: .bodyweight, type: .duration)
        #expect(duration?.type == .duration)
    }

    // Moved from the UI suite (ticket 10a): the same expectations against the seeded starter list.

    private func starterNames(matching text: String = "", equipment: Equipment? = nil) throws
        -> [String]
    {
        let all = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        return ExerciseCatalog.sections(from: all, matching: text, equipment: equipment)
            .flatMap(\.exercises).map(\.name)
    }

    @Test func searchingCurlFindsOnlyNamesContainingCurl() throws {
        let names = try starterNames(matching: "curl")
        #expect(names.contains("Dumbbell Curl"))
        #expect(!names.contains("Dumbbell Bench Press"))
        #expect(!names.isEmpty)
        #expect(names.allSatisfy { $0.localizedCaseInsensitiveContains("curl") })
    }

    @Test func pullUpBarFilterKeepsTheFiveStarterPullUpBarExercises() throws {
        #expect(
            Set(try starterNames(equipment: .pullUpBar))
                == ["Chin-up", "Pull-up", "Hanging Knee Raise", "Hanging Leg Raise", "Dead Hang"])
    }

    @Test func aCreatedShouldersExerciseListsAloneUnderShoulders() throws {
        _ = try catalog.createCustomExercise(
            named: "Test Row", muscleGroup: .shoulders, equipment: .dumbbell, type: .weightReps)
        let all = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        let sections = ExerciseCatalog.sections(from: all, matching: "Test Row", equipment: nil)
        #expect(sections.map(\.muscleGroup) == [.shoulders])
        #expect(sections.flatMap(\.exercises).map(\.name) == ["Test Row"])
    }

    @Test func aCustomExerciseWhoseSaveFailsLeavesNothingAndItsNameStaysFree() throws {
        let store = try ReadOnlyStore()
        defer { store.remove() }
        let catalog = ExerciseCatalog(context: store.context)

        #expect(throws: (any Error).self) {
            _ = try catalog.createCustomExercise(
                named: "Zottman Curl", muscleGroup: .biceps, equipment: .dumbbell,
                type: .weightReps)
        }

        #expect(!store.context.hasChanges)
        let existing = try store.context.fetch(FetchDescriptor<Exercise>())
        #expect(existing.isEmpty)
        // Retrying gets as far as saving again; a pending leftover would make it return nil (a duplicate).
        #expect(throws: (any Error).self) {
            _ = try catalog.createCustomExercise(
                named: "zottman curl", muscleGroup: .biceps, equipment: .dumbbell,
                type: .weightReps)
        }
    }
}
