import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled templates, and starting and adding them, against an in-memory store seeded with the
/// starters.
@MainActor
struct TemplateTests {
    let container: ModelContainer
    let log: WorkoutLog
    let library: TemplateLibrary

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
        library = TemplateLibrary(context: container.mainContext)
    }

    private func template(_ name: String) throws -> Template {
        try #require(try Template.load().first { $0.name == name })
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    @Test func theFileLoadsAndNamesOnlyStarterExercisesOfTheRightKind() throws {
        let templates = try Template.load()
        #expect(templates.count == 7)
        #expect(Set(templates.map(\.name)).count == templates.count)
        let starters = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        let kinds = Dictionary(uniqueKeysWithValues: starters.map { ($0.name, $0.kind) })
        for template in templates {
            #expect(!template.why.isEmpty)
            #expect((template.programme == nil) == (template.kind == .oneOff))
            for entry in template.exercises {
                let kind = try #require(kinds[entry.exercise], "\(entry.exercise) isn't a starter")
                #expect(!entry.sets.isEmpty)
                if kind == .duration {
                    #expect(entry.targetDurationSeconds != nil && entry.repRange == nil)
                } else {
                    let range = try #require(entry.repRange)
                    #expect(range.count == 2 && range[0] <= range[1])
                }
            }
        }
    }

    @Test func groupsProgrammesOneOffsAndSuggestions() throws {
        let templates = try Template.load()
        let programmes = Template.programmes(in: templates)
        #expect(programmes.map(\.name) == ["Full Body", "Upper/Lower", "Push/Pull/Legs"])
        #expect(
            programmes.map { $0.sessions.map(\.name) } == [
                ["Full Body"], ["Upper Body", "Lower Body"], ["Push", "Pull", "Legs"],
            ])
        #expect(Template.oneOffs(in: templates).map(\.name) == ["Golden Six"])
        #expect(Template.suggestions(in: templates).map(\.name) == ["Full Body", "Upper Body"])
        #expect(
            Template.programme(of: try template("Lower Body"), in: templates)?.name
                == "Upper/Lower")
        #expect(Template.programme(of: try template("Golden Six"), in: templates) == nil)
    }

    @Test func estimatesEverySetAsItsRestPlusFortySeconds() throws {
        let fullBody = try template("Full Body")
        #expect(fullBody.setCount == 18)
        // 18 × (90 + 40) s = 39 min.
        #expect(fullBody.estimatedMinutes(restSeconds: 90) == 39)
        // 18 × (60 + 40) s = 30 min.
        #expect(fullBody.estimatedMinutes(restSeconds: 60) == 30)
        #expect(fullBody.summary(restSeconds: 90) == "7 exercises · about 39 min")
    }

    @Test func startingAOneOffGivesAnUnlinkedWorkoutInOrderPrefilledFromHistory() throws {
        let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let past = try #require(try log.startEmptyWorkout(at: day))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: past)
        let pastSet = try #require(past.exercises.first?.sets.first)
        try log.setWeight(35, of: pastSet)
        pastSet.repsText = "10"
        try log.toggleCompleted(pastSet)
        _ = try log.finish(past, title: "Logged", at: day.addingTimeInterval(3600))
        let goldenSix = try template("Golden Six")

        let started = try #require(
            try library.startWorkout(from: goldenSix, at: day.addingTimeInterval(86_400)))

        let workout = started.workout
        #expect(workout.title == "Golden Six")
        #expect(workout.routine == nil)
        #expect(workout.endDate == nil)
        let exercises = WorkoutLog.orderedExercises(of: workout)
        #expect(exercises.map { $0.exercise?.name } == goldenSix.exercises.map(\.exercise))
        #expect(
            exercises.map { WorkoutLog.orderedSets(of: $0).map(\.setType) }
                == goldenSix.exercises.map(\.sets))
        let bench = WorkoutLog.orderedSets(of: exercises[1])
        #expect(bench[0].weight == 35)
        #expect(bench[0].reps == 10)
        // No set from last time: it starts like a new set.
        #expect(bench[1].weight == 5)
        #expect(bench[1].reps == nil)
        #expect(started.progressions.note(for: exercises[1]) == nil)
    }

    @Test func aTimedEntryStartsAtItsTargetDuration() throws {
        let started = try #require(try library.startWorkout(from: try template("Full Body")))
        let plank = try #require(
            WorkoutLog.orderedExercises(of: started.workout).first {
                $0.exercise?.name == "Plank"
            })
        #expect(plank.sets.allSatisfy { $0.durationSeconds == 45 })
    }

    @Test func startingIsRefusedWhileAWorkoutIsInProgress() throws {
        let inProgress = try #require(try log.startEmptyWorkout())
        container.mainContext.delete(try exercise("Chin-up"))
        try container.mainContext.save()

        #expect(try library.startWorkout(from: try template("Golden Six")) == nil)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(log.inProgressWorkout() === inProgress)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func addProgrammeSavesEverySessionAsARoutine() throws {
        let upperLower = try #require(
            Template.programmes(in: try Template.load()).first { $0.name == "Upper/Lower" })

        try library.addProgramme(upperLower)

        let fresh = ModelContext(container)
        let routines = try fresh.fetch(RoutineLibrary.routinesByName)
        #expect(routines.map(\.name) == ["Lower Body", "Upper Body"])
        let lower = try #require(routines.first)
        let entries = RoutineLibrary.orderedExercises(of: lower)
        #expect(
            entries.map { $0.exercise?.name } == upperLower.sessions[1].exercises.map(\.exercise))
        #expect(RoutineLibrary.summary(of: entries[0]) == "3 × 8–12")
        #expect(RoutineLibrary.summary(of: entries[5]) == "2 × 45 s")
    }

    @Test func aDraftCarriesTheTemplateForTheEditor() throws {
        let draft = try library.draft(of: try template("Full Body"))
        #expect(draft.name == "Full Body")
        #expect(draft.canSave)
        #expect(draft.exercises.map(\.exercise.name).first == "Dumbbell Goblet Squat")
        #expect(draft.exercises[5].repLow == 12)
        #expect(draft.exercises[5].repHigh == 20)
        #expect(draft.exercises[6].targetDurationSeconds == 45)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Routine>()) == 0)
    }

    @Test func aMissingStarterExerciseIsInsertedOnUse() throws {
        let context = container.mainContext
        context.delete(try exercise("Chin-up"))
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<Exercise>())

        let started = try #require(try library.startWorkout(from: try template("Golden Six")))

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Exercise>()) == count + 1)
        let chinUp = try exercise("Chin-up")
        #expect(chinUp.kind == .bodyweightReps)
        #expect(!chinUp.isCustom)
        #expect(WorkoutLog.orderedExercises(of: started.workout)[2].exercise === chinUp)
    }

    @Test func anExistingExerciseIsReusedIgnoringCaseAndAMissingOneIsInsertedOnce() throws {
        let context = container.mainContext
        try exercise("Dumbbell Goblet Squat").name = "dumbbell goblet squat"
        context.delete(try exercise("Chin-up"))
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<Exercise>())

        _ = try StarterExercises.exercises(
            named: ["Dumbbell Goblet Squat", "Chin-up", "chin-up"], in: context)
        try context.save()

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Exercise>()) == count + 1)
    }
}
