import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the routine and workout format readings, the AMRAP round, and the routine draft's format switch against
/// an in-memory store seeded with the starters.
@MainActor
struct RoutineFormatTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    private func starterRoutine(_ name: String) throws -> StarterRoutine {
        try #require(try StarterRoutine.load().first { $0.name == name })
    }

    /// A saved routine of the draft.
    private func saved(_ draft: RoutineDraft) throws -> Routine {
        try #require(try RoutineLibrary(context: context).save(draft, to: nil))
    }

    // MARK: Routine format

    @Test(arguments: [
        (String?.none, Int?.none, RoutineFormat.sets),
        ("stretch", nil, .stretch),
        ("timedAMRAP", 1200, .timedAMRAP(timeCapSeconds: 1200)),
        ("timedAMRAP", 60, .timedAMRAP(timeCapSeconds: 60)),
        ("timedAMRAP", 3600, .timedAMRAP(timeCapSeconds: 3600)),
    ])
    func storedFieldsReadAsTheFormat(raw: String?, timeCap: Int?, expected: RoutineFormat) {
        let format = RoutineFormat(rawValue: raw, timeCapSeconds: timeCap)
        #expect(format == expected)
        #expect(format?.rawValue == raw)
        #expect(format?.timeCapSeconds == timeCap)
    }

    @Test(arguments: [
        // A time cap on Sets or Stretch, an AMRAP without one, outside 1 to 60 minutes or not whole minutes, and
        // unknown raw values (Sets is stored as nil, never "sets").
        (String?.none, Int?.some(600)), ("stretch", 600), ("timedAMRAP", nil), ("timedAMRAP", 0),
        ("timedAMRAP", 3660), ("timedAMRAP", 90), ("timedAMRAP", -60), ("sets", nil),
        ("ladder", nil),
    ])
    func invalidStoredFieldsDontReadAsAFormat(raw: String?, timeCap: Int?) {
        #expect(RoutineFormat(rawValue: raw, timeCapSeconds: timeCap) == nil)
    }

    @Test func aRoutineWritesAndReadsBackEachFormat() throws {
        let routine = Routine(name: "R", creationDate: .now)
        context.insert(routine)
        #expect(routine.format == .sets)

        routine.format = .timedAMRAP(timeCapSeconds: 600)
        #expect(routine.formatRawValue == "timedAMRAP")
        #expect(routine.timeCapSeconds == 600)
        #expect(routine.format == .timedAMRAP(timeCapSeconds: 600))

        routine.format = .stretch
        #expect(routine.formatRawValue == "stretch")
        #expect(routine.timeCapSeconds == nil)
        #expect(routine.format == .stretch)

        routine.format = .sets
        #expect(routine.formatRawValue == nil)
        #expect(routine.timeCapSeconds == nil)
    }

    @Test func unreadableStoredFieldsReadAsSets() {
        let routine = Routine(name: "R", creationDate: .now)
        routine.formatRawValue = "stretch"
        routine.timeCapSeconds = 600
        #expect(routine.format == .sets)
    }

    @Test func aTimeCapIsHeldWithinOneToSixtyMinutes() {
        #expect(RoutineFormat.timedAMRAP(minutes: 0) == .timedAMRAP(timeCapSeconds: 60))
        #expect(RoutineFormat.timedAMRAP(minutes: 61) == .timedAMRAP(timeCapSeconds: 3600))
        #expect(RoutineFormat.timedAMRAP(minutes: 10).timeCapMinutes == 10)
    }

    @Test func eachFormatAllowsItsExerciseTypes() {
        #expect(RoutineFormat.sets.allowedTypes == ExerciseType.allCases)
        #expect(
            RoutineFormat.timedAMRAP(minutes: 20).allowedTypes == [.weightReps, .bodyweightReps])
        #expect(RoutineFormat.stretch.allowedTypes == [.duration])
    }

    @Test func theFormatSummaryNamesTheTimeCap() {
        #expect(RoutineFormat.timedAMRAP(minutes: 10).summary == "Timed AMRAP · 10 min")
        #expect(RoutineFormat.timedAMRAP(minutes: 10).spokenSummary == "Timed AMRAP, 10 minutes")
        #expect(RoutineFormat.timedAMRAP(minutes: 1).spokenSummary == "Timed AMRAP, 1 minute")
        #expect(RoutineFormat.stretch.summary == "Stretch")
        #expect(RoutineFormat.sets.summary == nil)
    }

    // MARK: Workout format

    @Test func workoutFieldsReadAsTheFormatAndWriteBack() {
        #expect(WorkoutFormat(rawValue: nil, rounds: nil, extraReps: nil) == .sets)
        #expect(
            WorkoutFormat(rawValue: "timedAMRAP", rounds: 14, extraReps: 7)
                == .timedAMRAP(rounds: 14, extraReps: 7))
        #expect(
            WorkoutFormat(rawValue: "timedAMRAP", rounds: 0, extraReps: 0)
                == .timedAMRAP(rounds: 0, extraReps: 0))
        for (raw, rounds, extraReps) in [
            (String?.none, Int?.some(3), Int?.some(2)), ("timedAMRAP", nil, 2),
            ("timedAMRAP", 3, nil),
            ("timedAMRAP", -1, 0), ("timedAMRAP", 0, -1), ("stretch", nil, nil), (nil, nil, 0),
        ] {
            #expect(WorkoutFormat(rawValue: raw, rounds: rounds, extraReps: extraReps) == nil)
        }

        let workout = Workout(title: "Cindy", startDate: .now)
        workout.format = .timedAMRAP(rounds: 14, extraReps: 7)
        #expect(workout.formatRawValue == "timedAMRAP")
        #expect(workout.amrapRounds == 14)
        #expect(workout.amrapExtraReps == 7)
        workout.format = .sets
        #expect(workout.formatRawValue == nil)
        #expect(workout.amrapRounds == nil)
        #expect(workout.amrapExtraReps == nil)
    }

    // MARK: AMRAP round

    @Test func cindyBuildsAnAMRAPRoundOfThirtyReps() throws {
        let cindy = try starterRoutine("Cindy")
        #expect(cindy.format == .timedAMRAP(timeCapSeconds: 1200))
        #expect(cindy.summary(restSeconds: 90) == "3 exercises · Timed AMRAP · 20 min")
        let routine = try saved(try StarterLibrary(context: context).draft(of: cindy))
        #expect(routine.format == .timedAMRAP(timeCapSeconds: 1200))

        let round = try #require(AMRAPRound(routine.exercises))

        #expect(round.entries.map(\.exercise.name) == ["Pull-up", "Push-up", "Squat"])
        #expect(round.entries.map(\.reps) == [5, 10, 15])
        #expect(round.repsPerRound == 30)
        #expect(
            RoutineLibrary.orderedExercises(of: routine).map(RoutineLibrary.summary(of:)) == [
                "5 reps", "10 reps", "15 reps",
            ])
    }

    @Test func aStretchRoutineSummarisesEachStretchAsItsHold() {
        let target = RoutineTarget.duration(seconds: 30)
        #expect(RoutineLibrary.summary(setCount: 3, target: target, in: .stretch) == "30 s")
        #expect(
            RoutineLibrary.spokenSummary(setCount: 3, target: target, in: .stretch) == "30 seconds")
        #expect(RoutineLibrary.summary(setCount: 3, target: target, in: .sets) == "3 × 30 s")
    }

    /// A saved copy of Cindy.
    private func cindy() throws -> Routine {
        try saved(try StarterLibrary(context: context).draft(of: starterRoutine("Cindy")))
    }

    @Test func anAMRAPRoundRefusesADurationExercise() throws {
        let routine = try cindy()
        let plank = RoutineExercise(
            exercise: try exercise("Plank"), position: 3, plannedSetTypes: [.normal],
            targetDurationSeconds: 30)
        context.insert(plank)
        routine.exercises.append(plank)
        #expect(AMRAPRound(routine.exercises) == nil)
    }

    @Test func anAMRAPRoundRefusesTwoPlannedSets() throws {
        let routine = try cindy()
        RoutineLibrary.orderedExercises(of: routine)[1].plannedSetTypeRawValues = [
            "normal", "normal",
        ]
        #expect(AMRAPRound(routine.exercises) == nil)
    }

    @Test func anAMRAPRoundRefusesARangeWithLowBelowHigh() throws {
        let routine = try cindy()
        RoutineLibrary.orderedExercises(of: routine)[2].target = .repRange(10...15)
        #expect(AMRAPRound(routine.exercises) == nil)
    }

    @Test func anAMRAPRoundRefusesNoExercisesOrNoTarget() throws {
        #expect(AMRAPRound([]) == nil)
        let routine = try cindy()
        RoutineLibrary.orderedExercises(of: routine)[0].target = nil
        #expect(AMRAPRound(routine.exercises) == nil)
    }

    // MARK: Editor format switch

    @Test func switchingToTimedAMRAPCollapsesEachExerciseToOneSetAtItsHighEnd() throws {
        var draft = RoutineDraft()
        draft.name = "Mine"
        draft.addExercise(try exercise("Push-up"))
        draft.addExercise(try exercise("Dumbbell Bench Press"))
        draft.exercises[0].addSet()
        draft.exercises[0].sets[1].type = .warmUp
        draft.exercises[1].repLow = 6
        draft.exercises[1].repHigh = 10

        #expect(draft.switchFormat(to: .timedAMRAP) == nil)

        #expect(draft.format == .timedAMRAP(timeCapSeconds: 1200))
        #expect(draft.exercises.map { $0.sets.map(\.type) } == [[.normal], [.normal]])
        #expect(draft.exercises.map(\.target) == [.repRange(12...12), .repRange(10...10)])
        #expect(draft.canSave)
    }

    @Test func aTimedAMRAPDraftSetsItsTimeCapAndRepsAndSavesThem() throws {
        var draft = RoutineDraft()
        draft.name = "Ten"
        draft.switchFormat(to: .timedAMRAP)
        draft.timeCapMinutes = 10
        #expect(draft.addExercise(try exercise("Push-up")))
        #expect(draft.exercises[0].target == .repRange(12...12))
        draft.exercises[0].reps = 10
        #expect(draft.exercises[0].target == .repRange(10...10))
        draft.timeCapMinutes = 90
        #expect(draft.timeCapMinutes == 60)
        draft.timeCapMinutes = 10

        let routine = try saved(draft)

        #expect(routine.format == .timedAMRAP(timeCapSeconds: 600))
        #expect(AMRAPRound(routine.exercises)?.repsPerRound == 10)
        #expect(RoutineDraft(routine: routine).format == .timedAMRAP(timeCapSeconds: 600))
    }

    @Test func switchingIsRefusedWhileAnExerciseDoesntFitTheFormat() throws {
        var draft = RoutineDraft()
        draft.name = "Mixed"
        draft.addExercise(try exercise("Push-up"))
        draft.addExercise(try exercise("Plank"))
        draft.exercises[0].addSet()

        #expect(
            draft.switchFormat(to: .timedAMRAP)
                == "Timed AMRAP takes only rep exercises. Remove Plank first.")
        #expect(
            draft.switchFormat(to: .stretch)
                == "Stretch takes only timed exercises. Remove Push-up first.")

        // Nothing changed.
        #expect(draft.format == .sets)
        #expect(draft.exercises[0].sets.count == 2)
        #expect(draft.exercises[0].target == .repRange(8...12))
    }

    @Test func switchingToStretchOrBackToSetsKeepsTheExercises() throws {
        var draft = RoutineDraft()
        draft.name = "Holds"
        draft.addExercise(try exercise("Plank"))
        #expect(draft.switchFormat(to: .stretch) == nil)
        #expect(draft.format == .stretch)
        #expect(draft.exercises[0].target == .duration(seconds: 30))
        #expect(draft.canSave)
        #expect(draft.switchFormat(to: .sets) == nil)
        #expect(draft.format == .sets)
        #expect(draft.exercises.count == 1)
    }

    @Test func aFormatOffersOnlyTheExercisesItAllows() throws {
        var draft = RoutineDraft()
        draft.switchFormat(to: .timedAMRAP)
        #expect(!draft.addExercise(try exercise("Plank")))
        draft.switchFormat(to: .stretch)
        #expect(!draft.addExercise(try exercise("Push-up")))
        #expect(draft.exercises.isEmpty)

        let all = try context.fetch(FetchDescriptor<Exercise>())
        let offered = ExerciseCatalog.sections(
            from: all, matching: "", equipment: nil, types: RoutineFormat.stretch.allowedTypes
        ).flatMap(\.exercises)
        #expect(!offered.isEmpty)
        #expect(offered.allSatisfy { $0.type == .duration })
    }

    @Test func aDraftThatBreaksItsFormatCantBeSaved() throws {
        var draft = RoutineDraft()
        draft.name = "Broken"
        draft.switchFormat(to: .timedAMRAP)
        draft.addExercise(try exercise("Push-up"))
        // Set lists aren't shown in a Timed AMRAP, but the draft still refuses one with two sets.
        draft.exercises[0].addSet()
        #expect(!draft.canSave)
        #expect(try RoutineLibrary(context: context).save(draft, to: nil) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 0)
    }

    @Test func aGuidedRoutineDoesntStartAsAWorkoutOfSets() throws {
        let routine = try cindy()
        #expect(try RoutineStart(context: context).startWorkout(from: routine) == nil)
        #expect(
            try StarterLibrary(context: context).startWorkout(from: starterRoutine("Cindy")) == nil)
        #expect(WorkoutLog(context: context).inProgressWorkout() == nil)
    }
}
