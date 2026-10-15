import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class ManualClock {
    var date = Date(timeIntervalSince1970: 3_000_000)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

/// Checks the stopwatch's goal, get ready, count up and signals on an injected clock, with a Plank set from an
/// in-memory store seeded with the starters.
@MainActor
struct StopwatchTests {
    private let clock = ManualClock()
    let container: ModelContainer
    let set: WorkoutSet

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        let log = WorkoutLog(context: container.mainContext)
        let plank = try #require(
            try container.mainContext.fetch(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Plank" })
            ).first)
        set = try log.addExercise(plank, to: try #require(try log.startEmptyWorkout()))
    }

    private func stopwatch(seconds: Int? = nil, placeholder: Int? = nil) -> Stopwatch {
        set.values = .duration(seconds: seconds)
        let clock = clock
        return Stopwatch(set: set, placeholder: placeholder, now: { clock.date })
    }

    @Test func theGoalDefaultsToTheSecondsThenThePlaceholderThenNone() {
        #expect(stopwatch(seconds: 42, placeholder: 30).goal == 42)
        #expect(stopwatch(seconds: 0, placeholder: 30).goal == 30)
        #expect(stopwatch(placeholder: 30).goal == 30)
        #expect(stopwatch().goal == nil)
    }

    @Test func theGoalStepsToMultiplesOfFiveDownToNoGoalAndUpTo600() {
        let down = stopwatch(seconds: 42)
        down.decreaseGoal()
        #expect(down.goal == 40)
        let up = stopwatch(seconds: 42)
        up.increaseGoal()
        #expect(up.goal == 45)

        let low = stopwatch(seconds: 5)
        low.decreaseGoal()
        #expect(low.goal == nil)
        #expect(!low.canDecreaseGoal)
        low.increaseGoal()
        #expect(low.goal == 5)

        let high = stopwatch(seconds: 595)
        high.increaseGoal()
        #expect(high.goal == 600)
        #expect(!high.canIncreaseGoal)
        high.increaseGoal()
        #expect(high.goal == 600)
    }

    @Test func theGoalIsFixedOnceStarted() {
        let stopwatch = stopwatch(seconds: 30)
        stopwatch.start()
        stopwatch.increaseGoal()
        stopwatch.decreaseGoal()
        #expect(stopwatch.goal == 30)
    }

    @Test func getReadyTicksEachOfItsFiveSecondsAndEndsSilently() {
        let stopwatch = stopwatch(seconds: 30)
        #expect(stopwatch.phase == .setup)
        stopwatch.start()
        #expect(stopwatch.phase == .getReady)
        var signals: [PhasedCountdown<Stopwatch.Step>.Signal?] = []
        for _ in 0..<5 {
            signals.append(stopwatch.advance())
            clock.advance(1)
        }
        #expect(signals == [.tick, .tick, .tick, .tick, .tick])
        #expect(stopwatch.advance() == nil)
        #expect(stopwatch.phase == .running)
    }

    @Test func elapsedCountsFromTheEndOfGetReady() {
        let stopwatch = stopwatch()
        stopwatch.start()
        clock.advance(3)
        #expect(stopwatch.elapsed(at: clock.date) == 0)
        clock.advance(2 + 7.6)
        _ = stopwatch.advance()
        #expect(stopwatch.elapsed(at: clock.date) == 7)
    }

    @Test func startNowCountsFromNow() {
        let stopwatch = stopwatch(seconds: 10)
        stopwatch.start()
        clock.advance(2)
        stopwatch.startNow()
        #expect(stopwatch.phase == .running)
        clock.advance(10)
        #expect(stopwatch.elapsed(at: clock.date) == 10)
        #expect(stopwatch.isGoalReached(at: clock.date))
        #expect(stopwatch.advance() == .chime)
    }

    @Test func theGoalChimesOnceAndTheCountKeepsGoing() {
        let stopwatch = stopwatch(seconds: 10)
        stopwatch.start()
        clock.advance(5)
        _ = stopwatch.advance()
        clock.advance(9)
        #expect(stopwatch.advance() == nil)
        #expect(!stopwatch.isGoalReached(at: clock.date))
        clock.advance(1)
        #expect(stopwatch.advance() == .chime)
        clock.advance(5)
        #expect(stopwatch.advance() == nil)
        #expect(stopwatch.elapsed(at: clock.date) == 15)
    }

    @Test func noGoalMeansNoChime() {
        let stopwatch = stopwatch()
        stopwatch.start()
        clock.advance(100)
        #expect(stopwatch.advance() == nil)
        #expect(!stopwatch.isGoalReached(at: clock.date))
    }

    @Test func aLateCatchUpPastTheGoalChimesOnce() {
        let stopwatch = stopwatch(seconds: 30)
        stopwatch.start()
        clock.advance(100)
        #expect(stopwatch.advance() == .chime)
        #expect(stopwatch.advance() == nil)
        #expect(stopwatch.elapsed(at: clock.date) == 95)
    }

    @Test(arguments: [45, nil] as [Int?])
    func aRerunAfterAnUndoneStopKeepsTheGoalItRanWith(goal: Int?) throws {
        set.values = .duration(seconds: goal)
        let workout = try #require(set.workoutExercise?.workout)
        let log = WorkoutLog(context: container.mainContext)
        try log.addSet(to: try #require(set.workoutExercise))
        var goals = StopwatchGoals()
        let clock = clock
        let first = goals.stopwatch(for: set, placeholder: nil, now: { clock.date })
        #expect(first.goal == goal)

        _ = try log.logStopwatch(seconds: 17, of: set, in: workout, defaultRest: 90)
        goals.logged(first)
        try log.toggleCompleted(set)
        #expect(!set.isCompleted && set.values == .duration(seconds: 17))

        #expect(goals.stopwatch(for: set, placeholder: 30, now: { clock.date }).goal == goal)
    }

    @Test func aSetNeverLoggedTakesItsSecondsAsTheGoal() {
        set.values = .duration(seconds: 20)
        #expect(StopwatchGoals().stopwatch(for: set, placeholder: 30).goal == 20)
    }

    @Test func pauseHoldsTheCountAndResumeLeavesThePausedTimeOut() {
        let stopwatch = stopwatch(seconds: 10)
        stopwatch.start()
        stopwatch.startNow()
        clock.advance(4)
        stopwatch.pause()
        #expect(stopwatch.isPaused)
        clock.advance(30)
        #expect(stopwatch.elapsed(at: clock.date) == 4)
        #expect(stopwatch.advance() == nil)
        stopwatch.resume()
        #expect(!stopwatch.isPaused)
        clock.advance(5)
        #expect(stopwatch.elapsed(at: clock.date) == 9)
        #expect(stopwatch.advance() == nil)
        clock.advance(1)
        #expect(stopwatch.advance() == .chime)
    }

    @Test func pauseAfterGetReadyEndedUnnoticedKeepsTheGoalOnTime() {
        let stopwatch = stopwatch(seconds: 10)
        stopwatch.start()
        clock.advance(7)
        stopwatch.pause()
        clock.advance(30)
        stopwatch.resume()
        clock.advance(7.5)
        #expect(stopwatch.elapsed(at: clock.date) == 9)
        #expect(stopwatch.advance() == nil)
        clock.advance(1)
        #expect(stopwatch.elapsed(at: clock.date) == 10)
        #expect(stopwatch.advance() == .chime)
    }

    @Test func pauseHoldsGetReady() {
        let stopwatch = stopwatch()
        stopwatch.start()
        clock.advance(2)
        stopwatch.pause()
        clock.advance(60)
        _ = stopwatch.advance()
        #expect(stopwatch.phase == .getReady)
        stopwatch.startNow()
        #expect(stopwatch.phase == .getReady)
        stopwatch.resume()
        clock.advance(3)
        _ = stopwatch.advance()
        #expect(stopwatch.phase == .running)
        clock.advance(2)
        #expect(stopwatch.elapsed(at: clock.date) == 2)
    }

    @Test func stopWaitsForAWholeSecond() {
        let stopwatch = stopwatch()
        #expect(!stopwatch.canStop(at: clock.date))
        stopwatch.start()
        stopwatch.startNow()
        #expect(!stopwatch.canStop(at: clock.date))
        clock.advance(0.9)
        #expect(!stopwatch.canStop(at: clock.date))
        clock.advance(0.1)
        #expect(stopwatch.canStop(at: clock.date))
    }
}
