import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the bundled starter routines, and starting and adding them, against an in-memory store seeded with the
/// starters.
@MainActor
struct StarterRoutineTests {
    let container: ModelContainer
    let log: WorkoutLog
    let library: StarterLibrary

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
        library = StarterLibrary(context: container.mainContext)
    }

    private func starterRoutine(_ name: String) throws -> StarterRoutine {
        try #require(try StarterRoutine.load().first { $0.name == name })
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    @Test func theFileLoadsAndNamesOnlyStarterExercisesOfTheRightType() throws {
        let starterRoutines = try StarterRoutine.load()
        #expect(starterRoutines.count == 11)
        #expect(Set(starterRoutines.map(\.name)).count == starterRoutines.count)
        let starters = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        let types = Dictionary(uniqueKeysWithValues: starters.map { ($0.name, $0.type) })
        for starterRoutine in starterRoutines {
            #expect(!starterRoutine.why.isEmpty)
            for entry in starterRoutine.exercises {
                let type = try #require(types[entry.exercise], "\(entry.exercise) isn't a starter")
                #expect(!entry.sets.isEmpty)
                if type == .duration {
                    #expect(entry.target?.seconds != nil)
                } else {
                    #expect(entry.target?.repRange != nil)
                }
            }
        }
    }

    /// The one-entry starter routine `{"exercise": "Plank", "sets": ["normal"], <fields>}` as JSON.
    private func decoded(_ fields: String) throws -> StarterRoutine {
        let json = """
            {"name": "T", "why": "w",
             "exercises": [{"exercise": "Plank", "sets": ["normal"]\(fields)}]}
            """
        return try JSONDecoder().decode(StarterRoutine.self, from: Data(json.utf8))
    }

    @Test func anEntryReadsItsRepRangeOrDurationAsATarget() throws {
        #expect(try decoded(#", "repRange": [8, 12]"#).exercises[0].target == .repRange(8...12))
        #expect(try decoded(#", "repRange": [5, 5]"#).exercises[0].target == .repRange(5...5))
        #expect(
            try decoded(#", "targetDurationSeconds": 45"#).exercises[0].target
                == .duration(seconds: 45))
        #expect(try decoded("").exercises[0].target == nil)
    }

    @Test(arguments: [
        #", "repRange": [12]"#, #", "repRange": [12, 8]"#, #", "repRange": [8, 12, 15]"#,
        #", "repRange": []"#, #", "repRange": [0, 12]"#, #", "repRange": [8, 51]"#,
        #", "targetDurationSeconds": 0"#, #", "repRange": [8, 12], "targetDurationSeconds": 45"#,
    ])
    func anEntryWithAMalformedTargetFailsToLoad(fields: String) {
        #expect(throws: DecodingError.self) { try decoded(fields) }
    }

    @Test func groupsProgrammesStandalonesAndSuggestions() throws {
        let starterRoutines = try StarterRoutine.load()
        let programmes = StarterRoutine.programmes(in: starterRoutines)
        #expect(programmes.map(\.name) == ["Full Body", "Upper/Lower", "Push/Pull/Legs"])
        #expect(
            programmes.map { $0.routines.map(\.name) } == [
                ["Full Body"], ["Upper Body", "Lower Body"], ["Push", "Pull", "Legs"],
            ])
        #expect(StarterRoutine.standalone(in: starterRoutines).map(\.name) == ["Golden Six"])
        #expect(
            StarterRoutine.stretching(in: starterRoutines).map(\.name) == [
                "Full-Body Quick Stretch", "Dynamic Lifting Warm-Up", "Hips and Lower Back",
                "Upper Body Reset",
            ])
        #expect(StarterRoutine.copyable(in: starterRoutines).count == 7)
        #expect(!StarterRoutine.copyable(in: starterRoutines).contains { $0.format == .stretch })
        #expect(
            StarterRoutine.suggestions(in: starterRoutines).map(\.name) == [
                "Full Body", "Upper Body",
            ])
        #expect(
            StarterRoutine.programme(of: try starterRoutine("Lower Body"), in: starterRoutines)?
                .name
                == "Upper/Lower")
        #expect(
            StarterRoutine.programme(of: try starterRoutine("Golden Six"), in: starterRoutines)
                == nil)
    }

    @Test func estimatesEverySetAsItsRestPlusFortySeconds() throws {
        let fullBody = try starterRoutine("Full Body")
        #expect(fullBody.setCount == 18)
        // 18 × (90 + 40) s = 39 min.
        #expect(fullBody.estimatedMinutes(restSeconds: 90) == 39)
        // 18 × (60 + 40) s = 30 min.
        #expect(fullBody.estimatedMinutes(restSeconds: 60) == 30)
        #expect(fullBody.summary(restSeconds: 90) == "7 exercises · about 39 min")
    }

    @Test func stretchRoutinesHoldOneTimedSetOfAStretchPerEntryAndNoProgramme() throws {
        let stretchRoutines = StarterRoutine.stretching(in: try StarterRoutine.load())
        let stretches = Dictionary(
            uniqueKeysWithValues: try container.mainContext.fetch(FetchDescriptor<Exercise>())
                .filter { $0.muscleGroup == .stretching }.map { ($0.name, $0) })
        for routine in stretchRoutines {
            #expect(routine.programme == nil)
            for entry in routine.exercises {
                #expect(stretches[entry.exercise] != nil, "\(entry.exercise) isn't a stretch")
                #expect(entry.sets == [.normal])
                #expect(entry.target?.seconds != nil)
                #expect(entry.isPerSide == (stretches[entry.exercise]?.isPerSide == true))
            }
        }
    }

    /// The research's timer contract: each hold, twice for a per-side stretch, plus a 10 s lead-in before each.
    @Test func estimatesAStretchRoutineAsOneRoundOfHoldsAndLeadIns() throws {
        let quick = try starterRoutine("Full-Body Quick Stretch")
        // 4:40 of holds over 11 timed windows, plus 11 × 10 s of lead-ins = 6:30.
        #expect(quick.stretchRoundSeconds == 390)
        #expect(quick.estimatedMinutes(restSeconds: 90) == 7)
        #expect(quick.summary(restSeconds: 90) == "7 stretches · about 7 min")
        #expect(try starterRoutine("Dynamic Lifting Warm-Up").stretchRoundSeconds == 410)
        #expect(try starterRoutine("Hips and Lower Back").stretchRoundSeconds == 460)
        #expect(try starterRoutine("Upper Body Reset").stretchRoundSeconds == 400)
        let twist = try #require(quick.exercises.last)
        #expect(twist.holdSummary == "5 s per side")
        #expect(twist.spokenHoldSummary == "5 seconds per side")
        #expect(quick.exercises[1].holdSummary == "30 s")
    }

    @Test func startingAStandaloneGivesAnUnlinkedWorkoutInOrderPrefilledFromHistory() throws {
        let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let past = try #require(try log.startEmptyWorkout(at: day))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: past)
        let pastSet = try #require(past.exercises.first?.sets.first)
        try log.setWeight(35, of: pastSet)
        pastSet.repsText = "10"
        try log.toggleCompleted(pastSet)
        _ = try log.finish(past, title: "Logged", at: day.addingTimeInterval(3600))
        let goldenSix = try starterRoutine("Golden Six")

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
        let started = try #require(try library.startWorkout(from: try starterRoutine("Full Body")))
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

        #expect(try library.startWorkout(from: try starterRoutine("Golden Six")) == nil)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(log.inProgressWorkout() === inProgress)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func addProgrammeCreatesAProgrammeHoldingCopiesOfItsRoutinesInOrder() throws {
        let upperLower = try #require(
            StarterRoutine.programmes(in: try StarterRoutine.load()).first {
                $0.name == "Upper/Lower"
            })

        try library.addProgramme(upperLower)

        let fresh = ModelContext(container)
        let programme = try #require(try fresh.fetch(FetchDescriptor<Programme>()).first)
        #expect(programme.name == "Upper/Lower")
        let routines = ProgrammeLibrary.orderedRoutines(of: programme)
        #expect(routines.map(\.name) == upperLower.routines.map(\.name))
        #expect(routines.map { $0.membership?.position } == [0, 1])
        #expect(try fresh.fetchCount(FetchDescriptor<Routine>()) == 2)
        let lower = try #require(routines.first { $0.name == "Lower Body" })
        let entries = RoutineLibrary.orderedExercises(of: lower)
        #expect(
            entries.map { $0.exercise?.name } == upperLower.routines[1].exercises.map(\.exercise))
        #expect(RoutineLibrary.summary(of: entries[0]) == "3 × 8–12")
        #expect(RoutineLibrary.summary(of: entries[5]) == "2 × 45 s")
    }

    @Test func aDraftCarriesTheStarterRoutineForTheEditor() throws {
        let draft = try library.draft(of: try starterRoutine("Full Body"))
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

        let started = try #require(try library.startWorkout(from: try starterRoutine("Golden Six")))

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Exercise>()) == count + 1)
        let chinUp = try exercise("Chin-up")
        #expect(chinUp.type == .bodyweightReps)
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

    /// Asserts a failed save left nothing behind: no exercise, workout or routine, stored or pending.
    private func expectNothingSaved(in store: ReadOnlyStore) throws {
        let context = store.context
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Routine>()).isEmpty)
        // A fresh context reads what the store holds on disk.
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<Exercise>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Routine>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Programme>()) == 0)
    }

    // Each test starts from an empty store, so every starter the starter routine names is inserted on use.

    @Test func aFailedDraftRollsBackTheInsertedStarters() throws {
        let store = try ReadOnlyStore()
        defer { store.remove() }
        let failing = StarterLibrary(context: store.context)

        #expect(throws: (any Error).self) { try failing.draft(of: try starterRoutine("Full Body")) }

        try expectNothingSaved(in: store)
    }

    @Test func aFailedStartRollsBackTheInsertedStarters() throws {
        let store = try ReadOnlyStore()
        defer { store.remove() }
        let failing = StarterLibrary(context: store.context)

        #expect(throws: (any Error).self) {
            try failing.startWorkout(from: try starterRoutine("Golden Six"))
        }

        try expectNothingSaved(in: store)
    }

    @Test func aFailedAddProgrammeRollsBackTheInsertedStarters() throws {
        let store = try ReadOnlyStore()
        defer { store.remove() }
        let failing = StarterLibrary(context: store.context)
        let upperLower = try #require(
            StarterRoutine.programmes(in: try StarterRoutine.load()).first {
                $0.name == "Upper/Lower"
            })

        #expect(throws: (any Error).self) { try failing.addProgramme(upperLower) }

        try expectNothingSaved(in: store)
    }
}
