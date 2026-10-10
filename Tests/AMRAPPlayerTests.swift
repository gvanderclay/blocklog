import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class ManualClock {
    var date = Date(timeIntervalSince1970: 2_000_000)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

/// Checks the AMRAP score, set totals, last time's score, and the AMRAP player's phases, events and logging, on an
/// injected clock against an in-memory store seeded with the starters.
@MainActor
struct AMRAPPlayerTests {
    private let clock = ManualClock()
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    private func starterCindy() throws -> StarterRoutine {
        try #require(StarterRoutine.bundled.first { $0.name == "Cindy" })
    }

    /// Cindy's round: 5 pull-ups, 10 push-ups, 15 squats.
    private func cindyRound() throws -> AMRAPRound {
        try #require(
            AMRAPRound(draft: try StarterLibrary(context: context).draft(of: try starterCindy())))
    }

    /// A saved Timed AMRAP of 1 minute: 10 Dumbbell Thrusters then 5 Push-ups.
    private func myAMRAP(name: String = "Mine") throws -> Routine {
        var draft = RoutineDraft()
        draft.name = name
        draft.switchFormat(to: .timedAMRAP)
        draft.timeCapMinutes = 1
        draft.addExercise(try exercise("Dumbbell Bench Press"))
        draft.addExercise(try exercise("Push-up"))
        draft.exercises[0].reps = 10
        draft.exercises[1].reps = 5
        return try #require(try RoutineLibrary(context: context).save(draft, to: nil))
    }

    private func start(_ routine: Routine) throws -> AMRAPPlayer {
        let clock = clock
        return try #require(AMRAPPlayer.start(routine, in: context, now: { clock.date }))
    }

    private func startCindy() throws -> AMRAPPlayer {
        let clock = clock
        return try #require(
            try AMRAPPlayer.start(try starterCindy(), in: context, now: { clock.date }))
    }

    /// Moves the clock a second at a time, advancing the player, and returns the signals given.
    @discardableResult
    private func run(_ player: AMRAPPlayer, seconds: Int) -> [PhasedCountdown<AMRAPPlayer.Step>
        .Signal]
    {
        (0..<seconds).compactMap { _ in
            clock.advance(1)
            return player.advance()
        }
    }

    private func score(_ rounds: Int, _ extraReps: Int) throws -> AMRAPScore {
        try #require(AMRAPScore(storedRounds: rounds, extraReps: extraReps))
    }

    /// Each logged exercise's name with its sets' values, in order.
    private func logged(_ workout: Workout) -> [String: [SetValues]] {
        Dictionary(
            uniqueKeysWithValues: WorkoutLog.orderedExercises(of: workout).map {
                ($0.exercise?.name ?? "", WorkoutLog.orderedSets(of: $0).map(\.values))
            })
    }

    // MARK: Score

    @Test func aScoreOfARoundKeepsItsExtraRepsBelowOneRound() throws {
        let round = try cindyRound()
        #expect(AMRAPScore(rounds: 14, extraReps: 7, of: round)?.rounds == 14)
        #expect(AMRAPScore(rounds: 0, extraReps: 29, of: round)?.extraReps == 29)
        #expect(AMRAPScore(rounds: 0, extraReps: 0, of: round) != nil)
        #expect(AMRAPScore(rounds: 3, extraReps: 30, of: round) == nil)
        #expect(AMRAPScore(rounds: -1, extraReps: 0, of: round) == nil)
        #expect(AMRAPScore(rounds: 3, extraReps: -1, of: round) == nil)
    }

    @Test func aStoredScoreChecksOnlyThatBothAreZeroOrMore() {
        #expect(AMRAPScore(storedRounds: 14, extraReps: 40)?.extraReps == 40)
        #expect(AMRAPScore(storedRounds: 0, extraReps: 0) != nil)
        #expect(AMRAPScore(storedRounds: -1, extraReps: 0) == nil)
        #expect(AMRAPScore(storedRounds: 0, extraReps: -1) == nil)
    }

    @Test func theScoreTextAlwaysHasBothParts() throws {
        #expect(try score(14, 7).text == "14 rounds + 7 reps")
        #expect(try score(1, 1).text == "1 round + 1 rep")
        #expect(try score(0, 0).text == "0 rounds + 0 reps")
        #expect(try score(14, 7).spokenText == "14 rounds plus 7 reps")
    }

    // MARK: Set totals

    @Test func setTotalsGiveTheExtraRepsOutInRoundOrder() throws {
        let round = try cindyRound()
        #expect(round.totalReps(for: try score(14, 7)) == [75, 142, 210])
        #expect(round.totalReps(for: try score(0, 0)) == [0, 0, 0])
        #expect(round.totalReps(for: try score(0, 7)) == [5, 2, 0])
        #expect(round.totalReps(for: try score(2, 29)) == [15, 30, 44])
    }

    // MARK: Last time's score

    /// Inserts a finished Timed AMRAP workout with the score.
    private func addAMRAPWorkout(
        title: String, routine: Routine?, score: AMRAPScore, daysAgo: Double
    ) {
        let start = clock.date.addingTimeInterval(-daysAgo * 86_400)
        let workout = Workout(
            title: title, startDate: start, endDate: start.addingTimeInterval(1_200),
            routine: routine)
        context.insert(workout)
        workout.format = .timedAMRAP(score)
    }

    private func finishedWorkouts() throws -> [Workout] {
        try context.fetch(WorkoutHistory.finishedWorkouts)
    }

    @Test func lastTimesScoreIsTheNewestOfTheSameRoutine() throws {
        let mine = try myAMRAP()
        let other = try myAMRAP(name: "Other")
        addAMRAPWorkout(title: "Mine", routine: mine, score: try score(10, 2), daysAgo: 7)
        addAMRAPWorkout(title: "Mine", routine: mine, score: try score(12, 3), daysAgo: 2)
        addAMRAPWorkout(title: "Other", routine: other, score: try score(20, 0), daysAgo: 1)
        addAMRAPWorkout(title: "Mine", routine: nil, score: try score(30, 0), daysAgo: 1)
        let unfinished = Workout(title: "Mine", startDate: clock.date, routine: mine)
        context.insert(unfinished)
        unfinished.format = .timedAMRAP(try score(40, 0))

        let workouts = try finishedWorkouts() + [unfinished]
        #expect(AMRAPScore.last(of: mine, titled: "Mine", in: workouts) == (try score(12, 3)))
        #expect(AMRAPScore.last(of: try myAMRAP(name: "New"), titled: "New", in: workouts) == nil)
    }

    @Test func aStarterRoutinesLastScoreMatchesUnlinkedWorkoutsByTitle() throws {
        let mine = try myAMRAP(name: "Cindy")
        addAMRAPWorkout(title: "Cindy", routine: nil, score: try score(14, 7), daysAgo: 3)
        addAMRAPWorkout(title: "Cindy", routine: mine, score: try score(18, 0), daysAgo: 1)
        addAMRAPWorkout(title: "Mary", routine: nil, score: try score(9, 0), daysAgo: 1)
        let sets = Workout(
            title: "Cindy", startDate: clock.date, endDate: clock.date.addingTimeInterval(60))
        context.insert(sets)

        #expect(
            AMRAPScore.last(of: nil, titled: "Cindy", in: try finishedWorkouts())
                == (try score(14, 7)))
    }

    // MARK: Starting

    @Test func startingIsRefusedWhileAWorkoutIsInProgress() throws {
        let routine = try myAMRAP()
        _ = try WorkoutLog(context: context).startEmptyWorkout()
        #expect(AMRAPPlayer.start(routine, in: context) == nil)
        #expect(try AMRAPPlayer.start(try starterCindy(), in: context) == nil)
    }

    @Test func startingIsRefusedForAnotherFormatOrARoutineWithoutARound() throws {
        let routine = try myAMRAP()
        RoutineLibrary.orderedExercises(of: routine)[0].plannedSetTypeRawValues = [
            "normal", "normal",
        ]
        #expect(AMRAPPlayer.start(routine, in: context) == nil)
        routine.format = .sets
        #expect(AMRAPPlayer.start(routine, in: context) == nil)
        let goldenSix = try #require(StarterRoutine.bundled.first { $0.format == .sets })
        #expect(try AMRAPPlayer.start(goldenSix, in: context) == nil)
    }

    @Test func beforeStartTheWeightsComeFromThePreviousNumbersAndLastTimesScore() throws {
        let routine = try myAMRAP()
        let log = WorkoutLog(context: context)
        let workout = try #require(
            try log.startEmptyWorkout(at: clock.date.addingTimeInterval(-86_400)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        try log.setWeight(35, of: set)
        set.repsText = "10"
        try log.toggleCompleted(set)
        _ = try log.finish(workout, title: "Bench", at: clock.date.addingTimeInterval(-80_000))
        addAMRAPWorkout(title: "Mine", routine: routine, score: try score(6, 4), daysAgo: 3)

        let player = try start(routine)

        #expect(player.phase == .setup)
        #expect(player.weights == [35, nil])
        #expect(player.dumbbellEntries == [0])
        #expect(player.lastScore == (try score(6, 4)))
        #expect(player.timeCapSeconds == 60)
    }

    @Test func aWeightChangesOnlyBeforeStartAndOnlyToAPowerBlockSetting() throws {
        let player = try start(try myAMRAP())
        #expect(player.weights == [5, nil])

        player.send(.setWeight(entry: 0, weight: 27.5))
        player.send(.setWeight(entry: 0, weight: 6))
        player.send(.setWeight(entry: 1, weight: 10))
        #expect(player.weights == [27.5, nil])

        player.send(.start)
        player.send(.setWeight(entry: 0, weight: 30))
        #expect(player.weights == [27.5, nil])
    }

    // MARK: Phases

    @Test func thePhasesRunGetReadyThenTheTimeCapThenTimeUp() throws {
        let player = try start(try myAMRAP())
        #expect(player.countdown == nil)
        #expect(player.send(.roundDone) == .setup)

        #expect(player.send(.start) == .getReady)
        #expect(player.countdown?.remaining(at: clock.date) == 10)
        #expect(player.send(.roundDone) == .getReady)
        #expect(player.score.rounds == 0)
        #expect(run(player, seconds: 10).isEmpty)
        #expect(player.phase == .running)
        #expect(player.countdown?.remaining(at: clock.date) == 60)
        #expect(player.roundNumber == 1)

        #expect(player.send(.roundDone) == .running)
        #expect(player.send(.roundDone) == .running)
        #expect(player.roundNumber == 3)

        #expect(run(player, seconds: 54).isEmpty)
        #expect(run(player, seconds: 5) == [.tick, .tick, .tick, .tick, .tick])
        #expect(run(player, seconds: 1) == [.chime])
        #expect(player.phase == .timeUp)
        #expect(player.send(.roundDone) == .timeUp)
        #expect(player.send(.pause) == .timeUp)
        #expect(player.score == AMRAPScore(rounds: 2, extraReps: 0, of: player.round))
    }

    @Test func pauseStopsTheClockAndRefusesRoundDone() throws {
        let player = try start(try myAMRAP())
        player.send(.start)
        #expect(player.send(.pause) == .paused)
        run(player, seconds: 30)
        #expect(player.countdown?.remaining(at: clock.date) == 10)
        #expect(player.send(.resume) == .getReady)
        run(player, seconds: 10)
        run(player, seconds: 20)
        #expect(player.send(.pause) == .paused)
        #expect(player.send(.roundDone) == .paused)
        #expect(player.score.rounds == 0)
        run(player, seconds: 120)
        #expect(player.phase == .paused)
        #expect(player.countdown?.remaining(at: clock.date) == 40)
        #expect(player.send(.resume) == .running)
        #expect(player.send(.roundDone) == .running)
        #expect(player.score.rounds == 1)
    }

    @Test func extraRepsAreSetOnlyAtTimeUpAndHeldBelowOneRound() throws {
        let player = try start(try myAMRAP())
        player.send(.start)
        player.send(.setExtraReps(3))
        run(player, seconds: 10)
        player.send(.setExtraReps(3))
        #expect(player.score.extraReps == 0)
        run(player, seconds: 60)
        #expect(player.phase == .timeUp)

        player.send(.setExtraReps(3))
        #expect(player.score.extraReps == 3)
        player.send(.setExtraReps(40))
        #expect(player.score.extraReps == 14)
        player.send(.setExtraReps(-2))
        #expect(player.score.extraReps == 0)
    }

    // MARK: Logging

    @Test func saveAtTimeUpLogsTheScoreAndATotalSetPerExercise() throws {
        let routine = try myAMRAP()
        let player = try start(routine)
        let started = clock.date
        player.send(.setWeight(entry: 0, weight: 25))
        player.send(.start)
        run(player, seconds: 10)
        for _ in 0..<3 { player.send(.roundDone) }
        run(player, seconds: 60)
        player.send(.setExtraReps(12))

        let workout = try #require(try player.log(in: context))

        #expect(player.phase == .finished)
        #expect(workout.title == "Mine")
        #expect(workout.routine === routine)
        #expect(workout.startDate == started)
        #expect(workout.endDate == clock.date)
        #expect(workout.format == .timedAMRAP(try score(3, 12)))
        #expect(
            logged(workout) == [
                "Dumbbell Bench Press": [.weightReps(weight: 25, reps: 40)],
                "Push-up": [.bodyweightReps(addedWeight: nil, reps: 17)],
            ])
        #expect(workout.exercises.flatMap(\.sets).allSatisfy { $0.isCompleted })
        #expect(try player.log(in: context) === workout)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(
            AMRAPScore.last(of: routine, titled: "Mine", in: try finishedWorkouts())
                == (try score(3, 12)))
    }

    @Test func cindyLogsUnlinkedAndTitledWithItsName() throws {
        let player = try startCindy()
        player.send(.start)
        run(player, seconds: 10)
        for _ in 0..<14 { player.send(.roundDone) }
        run(player, seconds: 1_200)
        player.send(.setExtraReps(7))

        let workout = try #require(try player.log(in: context))

        #expect(workout.title == "Cindy")
        #expect(workout.routine == nil)
        #expect(workout.format.score == (try score(14, 7)))
        #expect(
            logged(workout) == [
                "Pull-up": [.bodyweightReps(addedWeight: nil, reps: 75)],
                "Push-up": [.bodyweightReps(addedWeight: nil, reps: 142)],
                "Squat": [.bodyweightReps(addedWeight: nil, reps: 210)],
            ])
        #expect(try startCindy().lastScore == (try score(14, 7)))
    }

    @Test func quittingEarlyLogsTheRoundsDoneWithNoExtraReps() throws {
        let player = try startCindy()
        #expect(!player.hasSomethingToSave)
        player.send(.start)
        run(player, seconds: 10)
        #expect(!player.hasSomethingToSave)
        player.send(.roundDone)
        player.send(.roundDone)
        run(player, seconds: 300)
        #expect(player.hasSomethingToSave)

        let workout = try #require(try player.log(in: context))

        #expect(workout.format.score == (try score(2, 0)))
        #expect(
            logged(workout) == [
                "Pull-up": [.bodyweightReps(addedWeight: nil, reps: 10)],
                "Push-up": [.bodyweightReps(addedWeight: nil, reps: 20)],
                "Squat": [.bodyweightReps(addedWeight: nil, reps: 30)],
            ])
    }

    @Test func anExerciseWithNoRepsIsLeftOutAndNothingLogsBeforeStart() throws {
        let player = try startCindy()
        #expect(try player.log(in: context) == nil)
        player.send(.start)
        run(player, seconds: 1_210)
        player.send(.setExtraReps(7))

        let workout = try #require(try player.log(in: context))

        #expect(workout.format.score == (try score(0, 7)))
        #expect(
            logged(workout) == [
                "Pull-up": [.bodyweightReps(addedWeight: nil, reps: 5)],
                "Push-up": [.bodyweightReps(addedWeight: nil, reps: 2)],
            ])
    }

    @Test func aScoreOfNothingLogsNothingAndQuitsWithoutAsking() throws {
        let player = try startCindy()
        player.send(.start)
        run(player, seconds: 1_210)
        #expect(player.phase == .timeUp)

        #expect(!player.hasSomethingToSave)
        #expect(try player.log(in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        player.send(.setExtraReps(1))
        #expect(player.hasSomethingToSave)
    }

    @Test func aFailedSaveRollsBackAndLeavesTheRoutineReadable() throws {
        let store = try ReadOnlyStore { context in
            let pushUp = Exercise(
                name: "Push-up", muscleGroup: .chest, equipment: .bodyweight,
                type: .bodyweightReps)
            context.insert(pushUp)
            let routine = Routine(name: "Quick", creationDate: .now)
            context.insert(routine)
            routine.format = .timedAMRAP(minutes: 1)
            let routineExercise = RoutineExercise(
                exercise: pushUp, position: 0, plannedSetTypes: [.normal], repRangeLow: 10,
                repRangeHigh: 10)
            context.insert(routineExercise)
            routine.exercises.append(routineExercise)
        }
        defer { store.remove() }
        let routine = try #require(try store.context.fetch(FetchDescriptor<Routine>()).first)
        let clock = clock
        let player = try #require(
            AMRAPPlayer.start(routine, in: store.context, now: { clock.date }))
        player.send(.start)
        run(player, seconds: 10)
        player.send(.roundDone)

        #expect(throws: (any Error).self) { try player.log(in: store.context) }

        #expect(!store.context.hasChanges)
        #expect(player.loggedWorkout == nil)
        #expect(try store.context.fetch(FetchDescriptor<Workout>()).isEmpty)
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<Workout>()) == 0)
        // Reading the routine after the rollback, as its detail screen does, must not trap.
        #expect(RoutineLibrary.orderedExercises(of: routine).count == 1)
    }

    @Test func aLoggedAMRAPRoundTripsThroughABackup() throws {
        let player = try start(try myAMRAP())
        player.send(.start)
        run(player, seconds: 10)
        player.send(.roundDone)
        run(player, seconds: 60)
        player.send(.setExtraReps(4))
        _ = try player.log(in: context)
        let document = try Backup(context: context).export()

        let target = try ModelContainer(
            for: BlocklogApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        let workouts = try target.mainContext.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)
        #expect(workouts.first?.format.score == (try score(1, 4)))
        #expect(workouts.first?.routine?.name == "Mine")
    }

    // MARK: Progression and previous numbers

    @Test func progressionIgnoresAMRAPSetsButPreviousNumbersShowThem() throws {
        let log = WorkoutLog(context: context)
        let bench = try exercise("Dumbbell Bench Press")
        // A Sets workout short of the top of the range, then an AMRAP whose total is far above it.
        let workout = try #require(
            try log.startEmptyWorkout(at: clock.date.addingTimeInterval(-86_400)))
        try log.addExercise(bench, to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        try log.setWeight(20, of: set)
        set.repsText = "9"
        try log.toggleCompleted(set)
        _ = try log.finish(workout, title: "Bench", at: clock.date.addingTimeInterval(-80_000))
        let player = try start(try myAMRAP())
        player.send(.start)
        run(player, seconds: 10)
        for _ in 0..<5 { player.send(.roundDone) }
        run(player, seconds: 60)
        _ = try player.log(in: context)

        var draft = RoutineDraft()
        draft.name = "Bench Day"
        draft.addExercise(bench)
        let routine = try #require(try RoutineLibrary(context: context).save(draft, to: nil))
        let started = try #require(
            try RoutineStart(context: context).startWorkout(
                from: routine, at: clock.date.addingTimeInterval(60)))

        let workoutExercise = try #require(started.workout.exercises.first)
        #expect(Progression(context: context).suggestion(for: workoutExercise) == nil)
        #expect(started.progressions.note(for: workoutExercise) == nil)
        let startedSet = try #require(workoutExercise.sets.first)
        #expect(
            PreviousSetLookup(context: context).previous(for: startedSet)
                == .weightReps(weight: 20, reps: 50))
    }
}
