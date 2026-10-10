import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class ManualClock {
    var date = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

/// Checks the stretch player's sequence, controls, signals and logging, on an injected clock against an
/// in-memory store seeded with the starters.
@MainActor
struct StretchPlayerTests {
    private let clock = ManualClock()
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
    }

    /// A mixed routine: a per-side stretch of 30 s, then one of 20 s that isn't.
    private func mixedRoutine() throws -> StarterRoutine {
        let json = """
            {"name": "Mixed", "why": "A test.", "format": "stretch", "exercises": [
              {"exercise": "Hip Flexor Stretch", "sets": ["normal"], "targetDurationSeconds": 30},
              {"exercise": "Pancake Stretch", "sets": ["normal"], "targetDurationSeconds": 20}]}
            """
        return try JSONDecoder().decode(StarterRoutine.self, from: Data(json.utf8))
    }

    private func start(_ starterRoutine: StarterRoutine, rounds: Int = 1) throws -> StretchPlayer {
        let clock = clock
        return try #require(
            StretchPlayer.start(starterRoutine, rounds: rounds, in: context, now: { clock.date }))
    }

    /// Moves the clock a second at a time, advancing the player, and returns the signals given.
    @discardableResult
    private func run(_ player: StretchPlayer, seconds: Int) -> [PhasedCountdown<StretchPlayer.Step>
        .Signal]
    {
        (0..<seconds).compactMap { _ in
            clock.advance(1)
            return player.countdown.advance()
        }
    }

    private func runToTheEnd(_ player: StretchPlayer) {
        while !player.countdown.isFinished { run(player, seconds: 1) }
    }

    private func remaining(_ player: StretchPlayer) -> TimeInterval {
        player.countdown.remaining(at: clock.date)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    /// Each logged exercise's name with its sets' seconds, in order.
    private func logged(_ workout: Workout) -> [String: [Int]] {
        Dictionary(
            uniqueKeysWithValues: WorkoutLog.orderedExercises(of: workout).map {
                (
                    $0.exercise?.name ?? "",
                    WorkoutLog.orderedSets(of: $0).map { $0.values.seconds ?? 0 }
                )
            })
    }

    // MARK: Sequence

    @Test func aMixedRoutinePlaysLeadInsSidesAndRounds() throws {
        let player = try start(try mixedRoutine(), rounds: 2)
        typealias Step = StretchPlayer.Step
        let round = { (round: Int) -> [Step] in
            [
                Step(kind: .leadIn, round: round, entry: 0, side: 1),
                Step(kind: .hold, round: round, entry: 0, side: 1),
                Step(kind: .leadIn, round: round, entry: 0, side: 2),
                Step(kind: .hold, round: round, entry: 0, side: 2),
                Step(kind: .leadIn, round: round, entry: 1, side: nil),
                Step(kind: .hold, round: round, entry: 1, side: nil),
            ]
        }
        let phases = player.countdown.phases
        #expect(phases.map(\.step) == round(1) + round(2))
        #expect(phases.map(\.seconds) == [5, 30, 5, 30, 5, 20, 5, 30, 5, 30, 5, 20])
        #expect(phases.map(\.isSignalled) == phases.map { $0.step.kind == .hold })
        #expect(
            phases.prefix(6).map(\.step.status) == [
                "Get into position", "Side 1 of 2", "Switch sides", "Side 2 of 2",
                "Get into position", nil,
            ])
    }

    @Test func theClockMovesThroughEachPhaseAndShowsTheStretch() throws {
        let player = try start(try mixedRoutine(), rounds: 2)
        #expect(player.stretchName == "Hip Flexor Stretch")
        #expect(player.cue == StretchCue.bundled["Hip Flexor Stretch"])
        #expect(player.roundText == "Round 1 of 2")
        #expect(player.upNext == "Pancake Stretch")
        #expect(remaining(player) == 5)

        run(player, seconds: 5)
        #expect(player.step == .init(kind: .hold, round: 1, entry: 0, side: 1))
        #expect(remaining(player) == 30)
        run(player, seconds: 30 + 5 + 30 + 5)
        #expect(player.step == .init(kind: .hold, round: 1, entry: 1, side: nil))
        #expect(player.upNext == "Hip Flexor Stretch")
        run(player, seconds: 20 + 5 + 30 + 5 + 30 + 5)
        #expect(player.step == .init(kind: .hold, round: 2, entry: 1, side: nil))
        #expect(player.roundText == "Round 2 of 2")
        #expect(player.upNext == nil)
        run(player, seconds: 20)
        #expect(player.countdown.isFinished)
        #expect(player.step == nil)
    }

    @Test func aHoldTicksItsLastFiveSecondsAndChimesAtItsEnd() throws {
        let player = try start(try mixedRoutine())
        // The lead-in is silent.
        #expect(run(player, seconds: 5).isEmpty)
        #expect(run(player, seconds: 24).isEmpty)
        #expect(run(player, seconds: 6) == [.tick, .tick, .tick, .tick, .tick, .chime])
        // The "Switch sides" lead-in is silent too.
        #expect(run(player, seconds: 5).isEmpty)
    }

    @Test func passingSeveralPhasesAtOnceGivesOneChime() throws {
        let player = try start(try mixedRoutine())
        clock.advance(5 + 30 + 5 + 30 + 2)
        #expect(player.countdown.advance() == .chime)
        #expect(player.step == .init(kind: .leadIn, round: 1, entry: 1, side: nil))
        #expect(remaining(player) == 3)
    }

    @Test func nextWakeIsTheNextTickThenTheEnd() throws {
        let player = try start(try mixedRoutine())
        let leadInEnd = clock.date + 5
        #expect(player.countdown.nextWake == leadInEnd)
        run(player, seconds: 5)
        #expect(player.countdown.nextWake == leadInEnd + 25)
        run(player, seconds: 29)
        #expect(player.countdown.nextWake == leadInEnd + 30)
        player.countdown.pause()
        #expect(player.countdown.nextWake == nil)
    }

    // MARK: Controls

    @Test func pauseFreezesTheCountdownAndResumeContinuesIt() throws {
        let player = try start(try mixedRoutine())
        run(player, seconds: 10)
        player.togglePause()
        #expect(player.countdown.isPaused)
        run(player, seconds: 60)
        #expect(remaining(player) == 25)
        #expect(player.step?.kind == .hold)
        player.togglePause()
        #expect(!player.countdown.isPaused)
        run(player, seconds: 5)
        #expect(remaining(player) == 20)
    }

    @Test func skipLeavesTheHoldUncountedForTheNextLeadIn() throws {
        let player = try start(try mixedRoutine())
        run(player, seconds: 10)
        player.skip()
        #expect(player.step == .init(kind: .leadIn, round: 1, entry: 0, side: 2))
        #expect(remaining(player) == 5)
        // From a lead-in, Skip passes its hold too.
        player.skip()
        #expect(player.step == .init(kind: .leadIn, round: 1, entry: 1, side: nil))
        #expect(!player.hasCompletedHold)
        player.skip()
        #expect(player.countdown.isFinished)
        #expect(try player.log(in: context) == nil)
    }

    @Test func skipWhilePausedStaysPaused() throws {
        let player = try start(try mixedRoutine())
        player.togglePause()
        player.skip()
        #expect(player.countdown.isPaused)
        run(player, seconds: 10)
        #expect(remaining(player) == 5)
    }

    @Test func backGoesToThePreviousHoldsLeadIn() throws {
        let player = try start(try mixedRoutine())
        run(player, seconds: 5 + 30 + 5 + 10)
        #expect(player.step == .init(kind: .hold, round: 1, entry: 0, side: 2))
        player.back()
        #expect(player.step == .init(kind: .leadIn, round: 1, entry: 0, side: 1))
        #expect(remaining(player) == 5)
        // From the first hold, Back starts its lead-in again.
        run(player, seconds: 8)
        player.back()
        #expect(player.step == .init(kind: .leadIn, round: 1, entry: 0, side: 1))
        #expect(remaining(player) == 5)
    }

    @Test func addTimeLengthensTheCurrentHold() throws {
        let player = try start(try mixedRoutine())
        run(player, seconds: 5 + 28)
        #expect(player.countdown.advance() == nil)
        player.addTime()
        #expect(remaining(player) == 17)
        // The added seconds tick again at the new end.
        #expect(run(player, seconds: 11).isEmpty)
        #expect(run(player, seconds: 6) == [.tick, .tick, .tick, .tick, .tick, .chime])
        #expect(player.countdown.completedSeconds[1] == 45)
    }

    @Test func theTickAndTheChimeAreBundled() {
        for sound in [TimerSounds.Sound.tick, .chime] {
            #expect(Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") != nil)
        }
    }

    @Test func roundsAreClampedToOneToThree() throws {
        #expect(try start(try mixedRoutine(), rounds: 0).rounds == 1)
        #expect(try start(try mixedRoutine(), rounds: 9).rounds == 3)
        #expect(try start(try mixedRoutine(), rounds: 1).roundText == nil)
    }

    @Test func startingIsRefusedWhileAWorkoutIsInProgress() throws {
        _ = try WorkoutLog(context: context).startEmptyWorkout()
        #expect(StretchPlayer.start(try mixedRoutine(), rounds: 1, in: context) == nil)
    }

    // MARK: Logging

    @Test func finishingLogsOneSetPerStretchPerRound() throws {
        let routine = try #require(
            StarterRoutine.stretching(in: try StarterRoutine.load()).first {
                $0.name == "Full-Body Quick Stretch"
            })
        let began = clock.date
        let player = try start(routine, rounds: 2)
        runToTheEnd(player)

        let workout = try #require(try player.log(in: context))
        #expect(workout.title == "Full-Body Quick Stretch")
        #expect(workout.routine == nil)
        #expect(workout.startDate == began)
        #expect(workout.endDate == clock.date)
        #expect(
            WorkoutLog.orderedExercises(of: workout).compactMap(\.exercise?.name)
                == routine.exercises.map(\.exercise))
        // A per-side stretch's set holds the per-side seconds.
        #expect(logged(workout)["Hip Flexor Stretch"] == [30, 30])
        #expect(logged(workout)["Elephant Walks"] == [30, 30])
        #expect(logged(workout)["Standing Active Twist"] == [5, 5])
        let sets = workout.exercises.flatMap(\.sets)
        #expect(sets.count == routine.exercises.count * 2)
        #expect(sets.allSatisfy { $0.isCompleted && $0.setType == .normal })
        #expect(sets.allSatisfy { $0.weight == nil && $0.reps == nil })

        // Logging again saves nothing more.
        #expect(try player.log(in: context) === workout)
        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(WorkoutLog(context: fresh).inProgressWorkout() == nil)
    }

    @Test func savingOnQuitLogsOnlyTheHoldsDone() throws {
        let player = try start(try mixedRoutine(), rounds: 2)
        // Round 1: side 1 of the hip flexor with +15, then side 2 skipped; the pancake held.
        run(player, seconds: 5 + 10)
        player.addTime()
        run(player, seconds: 35)
        player.skip()
        run(player, seconds: 5 + 20)
        // Round 2: the hip flexor's first side held, then quit mid-way through the second.
        run(player, seconds: 5 + 30 + 5 + 10)
        #expect(player.hasCompletedHold)

        let workout = try #require(try player.log(in: context))
        #expect(logged(workout) == ["Hip Flexor Stretch": [45, 30], "Pancake Stretch": [20]])
        #expect(workout.endDate == clock.date)
    }

    @Test func aStretchResolvedToACustomExercisePlaysByTheRoutine() throws {
        // A custom duration exercise outside the Stretching group, not marked per side, takes the stretch's name.
        let hipFlexor = try exercise("Hip Flexor Stretch")
        hipFlexor.isCustom = true
        hipFlexor.muscleGroup = .core
        hipFlexor.isPerSide = nil
        // A custom rep exercise takes the other's name, so it can't hold a duration set.
        let pancake = try exercise("Pancake Stretch")
        pancake.isCustom = true
        pancake.type = .bodyweightReps
        try context.save()

        let player = try start(try mixedRoutine())
        #expect(player.countdown.phases.count == 6)
        runToTheEnd(player)

        let workout = try #require(try player.log(in: context))
        #expect(logged(workout) == ["Hip Flexor Stretch": [30]])
        #expect(workout.exercises.first?.exercise === hipFlexor)
    }

    @Test func aFailedSaveRollsBackAndSavesNothing() throws {
        let store = try ReadOnlyStore()
        defer { store.remove() }
        let clock = clock
        let player = try #require(
            StretchPlayer.start(
                try mixedRoutine(), rounds: 1, in: store.context, now: { clock.date }))
        runToTheEnd(player)

        #expect(throws: (any Error).self) { try player.log(in: store.context) }

        #expect(!store.context.hasChanges)
        #expect(player.loggedWorkout == nil)
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<Exercise>()) == 0)
    }
}
