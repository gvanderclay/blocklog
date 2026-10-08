import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class FakeClock {
    var date = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

/// Records what the timer asks the notification center to do.
@MainActor
private final class FakeNotifications: RestNotifying {
    private(set) var scheduled: [(date: Date, name: String?)] = []
    private(set) var cancelCount = 0
    func schedule(at date: Date, exerciseName: String?) { scheduled.append((date, exerciseName)) }
    func cancel() { cancelCount += 1 }
}

@MainActor
struct RestTimerTests {
    private let clock = FakeClock()
    private let notifications = FakeNotifications()
    private let timer: RestTimer
    /// Held by the suite instance: a model is unusable once its container is gone.
    private let container: ModelContainer

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        let clock = clock
        timer = RestTimer(now: { clock.date }, notifications: notifications)
    }

    @Test func countsDownAndAdjusts() {
        timer.start(duration: 90)
        #expect(timer.remaining == 90)
        clock.advance(30)
        #expect(timer.remaining == 60)
        timer.add(seconds: 15)
        #expect(timer.remaining == 75)
        timer.add(seconds: -15)
        timer.add(seconds: -15)
        #expect(timer.remaining == 45)
        timer.skip()
        #expect(!timer.isRunning)
        #expect(timer.remaining == 0)
    }

    @Test func advancingPastTheEndRunsOnInOvertime() {
        timer.start(duration: 90)
        clock.advance(120)
        #expect(timer.remaining == 0)
        #expect(timer.isRunning)
        #expect(timer.isOvertime)
        #expect(timer.overtime(at: clock.date) == 30)
        clock.advance(10)
        #expect(timer.overtime(at: clock.date) == 40)
        timer.skip()
        #expect(!timer.isRunning)
        #expect(timer.overtime(at: clock.date) == 0)
    }

    @Test func overtimeIsZeroBeforeTheEnd() {
        timer.start(duration: 90)
        #expect(!timer.isOvertime)
        #expect(timer.overtime(at: clock.date) == 0)
    }

    @Test func minus15PastTheEndPutsTheEndAtNowAndEntersOvertime() {
        timer.start(duration: 30)
        clock.advance(20)
        timer.add(seconds: -15)
        #expect(timer.isRunning)
        #expect(timer.endDate == clock.date)
        #expect(timer.total == 20)
        #expect(timer.isOvertime)
        #expect(!timer.signalEndIfDue(appActive: true))  // the user's own tap, so no haptic or chime
        #expect(notifications.cancelCount == 1)
        clock.advance(5)
        #expect(timer.overtime(at: clock.date) == 5)
    }

    @Test func addDoesNothingInOvertime() {
        timer.start(duration: 30)
        clock.advance(40)
        timer.add(seconds: 15)
        #expect(timer.overtime(at: clock.date) == 10)
    }

    @Test func theEndIsSignalledOnceWhenTicksAreSkipped() {
        timer.start(duration: 30)
        clock.advance(29)
        #expect(!timer.signalEndIfDue(appActive: true))
        clock.advance(1.5)  // the final tick was missed
        #expect(timer.signalEndIfDue(appActive: true))
        #expect(notifications.cancelCount == 1)
        #expect(!timer.signalEndIfDue(appActive: true))
        #expect(timer.isRunning)
    }

    @Test func anEndAfterTimeAwayIsMarkedSilently() {
        timer.start(duration: 30)
        clock.advance(300)  // back from the background
        #expect(!timer.signalEndIfDue(appActive: false))
        #expect(timer.isOvertime)
        clock.advance(1)
        #expect(!timer.signalEndIfDue(appActive: true))  // already handled, no second alert
    }

    @Test func isOvertimeAtADate() {
        #expect(!timer.isOvertime(at: clock.date))
        timer.start(duration: 30)
        #expect(!timer.isOvertime(at: clock.date.addingTimeInterval(29)))
        #expect(timer.isOvertime(at: clock.date.addingTimeInterval(30)))
    }

    @Test func changingTheTimerSoundReschedulesOnlyACountdown() {
        timer.timerSoundChanged()
        #expect(notifications.scheduled.isEmpty)
        timer.start(duration: 30, exerciseName: "Curl")
        timer.timerSoundChanged()
        #expect(notifications.scheduled.count == 2)
        #expect(notifications.scheduled[1].name == "Curl")
        clock.advance(40)
        timer.timerSoundChanged()
        #expect(notifications.scheduled.count == 2)
    }

    @Test func skipBeforeTheEndNeverSignals() {
        timer.start(duration: 30)
        timer.skip()
        clock.advance(60)
        #expect(!timer.signalEndIfDue(appActive: true))
    }

    @Test func restartingAfterOvertimeSignalsAgain() {
        timer.start(duration: 30)
        clock.advance(30)
        #expect(timer.signalEndIfDue(appActive: true))
        timer.start(duration: 30)
        #expect(!timer.isOvertime)
        clock.advance(30)
        #expect(timer.signalEndIfDue(appActive: true))
    }

    @Test func countdownTicksAreTheLastThreeSeconds() {
        #expect(RestTimer.isCountdownTick(from: 4, to: 3))
        #expect(RestTimer.isCountdownTick(from: 2, to: 1))
        #expect(RestTimer.isCountdownTick(from: 9, to: 2))  // a skipped tick
        #expect(!RestTimer.isCountdownTick(from: 5, to: 4))
        #expect(!RestTimer.isCountdownTick(from: 1, to: 0))
        #expect(!RestTimer.isCountdownTick(from: 1, to: 2))  // after +15
    }

    @Test func formatsOvertime() {
        #expect(RestTimer.overtimeClock(45) == "+0:45")
        #expect(RestTimer.overtimeClock(125) == "+2:05")
    }

    @Test func adjustingMovesTheTotalWithTheEnd() throws {
        timer.start(duration: 90)
        timer.add(seconds: 15)
        #expect(timer.total == 105)
        timer.add(seconds: -15)
        timer.add(seconds: -15)
        #expect(timer.total == 75)
        #expect(timer.endDate == clock.date.addingTimeInterval(75))
    }

    @Test func addDoesNothingWhenIdle() {
        timer.add(seconds: 15)
        #expect(!timer.isRunning)
        #expect(notifications.scheduled.isEmpty)
    }

    @Test func startSchedulesAdjustReschedulesAndSkipCancels() throws {
        timer.start(duration: 90, exerciseName: "Hammer Curl")
        #expect(notifications.scheduled.count == 1)
        #expect(notifications.scheduled[0].date == clock.date.addingTimeInterval(90))
        #expect(notifications.scheduled[0].name == "Hammer Curl")
        timer.add(seconds: 15)
        #expect(notifications.scheduled.count == 2)
        #expect(notifications.scheduled[1].date == clock.date.addingTimeInterval(105))
        #expect(notifications.scheduled[1].name == "Hammer Curl")
        let cancelsBefore = notifications.cancelCount
        timer.skip()
        #expect(notifications.cancelCount == cancelsBefore + 1)
    }

    @Test func restoreKeepsARestThatHasNotEnded() {
        let end = clock.date.addingTimeInterval(40)
        timer.restore(endDate: end, total: 90)
        #expect(timer.remaining == 40)
        #expect(timer.total == 90)
    }

    @Test func restoreAfterTheEndShowsOvertimeWithNothingScheduled() {
        timer.restore(endDate: clock.date.addingTimeInterval(-5), total: 90)
        #expect(timer.isOvertime)
        #expect(timer.overtime(at: clock.date) == 5)
        #expect(!timer.signalEndIfDue(appActive: true))
        #expect(notifications.scheduled.isEmpty)
        timer.restore(endDate: nil, total: nil)
        #expect(!timer.isRunning)
    }

    @Test func exerciseOverrideBeatsTheDefault() {
        let withOverride = Exercise(
            name: "A", muscleGroup: .chest, equipment: .dumbbell, kind: .weightReps,
            restOverrideSeconds: 120)
        let without = Exercise(
            name: "B", muscleGroup: .chest, equipment: .dumbbell, kind: .weightReps)
        #expect(RestTimer.restSeconds(for: withOverride, defaultRest: 90) == 120)
        #expect(RestTimer.restSeconds(for: without, defaultRest: 90) == 90)
        #expect(RestTimer.restSeconds(for: nil, defaultRest: 90) == 90)
    }

    @Test func formatsClockTime() {
        #expect(RestTimer.clock(90) == "1:30")
        #expect(RestTimer.clock(300) == "5:00")
        #expect(RestTimer.clock(0) == "0:00")
    }

    // MARK: With a workout

    private func store() throws -> (
        log: WorkoutLog, workout: Workout, set: WorkoutSet, exercise: Exercise
    ) {
        let log = WorkoutLog(context: container.mainContext, restTimer: timer)
        let name = "Hammer Curl"
        let exercise = try #require(
            try container.mainContext.fetch(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
            ).first)
        let workout = try #require(try log.startEmptyWorkout())
        try log.addExercise(exercise, to: workout)
        let set = try #require(workout.exercises.first?.sets.first)
        set.reps = 10
        try log.context.saveOrRollBack()
        return (log, workout, set, exercise)
    }

    @Test func checkingOffASetStartsTheRestAndUncheckingKeepsIt() throws {
        let (log, workout, set, _) = try store()
        _ = try timer.checkOff(set, in: workout, using: log, defaultRest: 90)
        #expect(timer.remaining == 90)
        #expect(notifications.scheduled.last?.name == "Hammer Curl")
        clock.advance(30)
        try log.toggleCompleted(set)
        #expect(!set.isCompleted)
        #expect(timer.remaining == 60)
    }

    @Test func checkingOffUsesTheExerciseOverride() throws {
        let (log, workout, set, exercise) = try store()
        try log.setRestOverride(120, of: exercise)
        _ = try timer.checkOff(set, in: workout, using: log, defaultRest: 90)
        #expect(timer.remaining == 120)
        try log.setRestOverride(nil, of: exercise)
        #expect(exercise.restOverrideSeconds == nil)
    }

    @Test func finishingStopsTheTimerAndCancelsTheNotification() throws {
        let (log, workout, set, _) = try store()
        _ = try timer.checkOff(set, in: workout, using: log, defaultRest: 90)
        let cancelsBefore = notifications.cancelCount
        _ = try log.finish(workout, title: "Done", at: clock.date)
        #expect(!timer.isRunning)
        #expect(notifications.cancelCount > cancelsBefore)
    }

    @Test func discardingStopsTheTimerAndCancelsTheNotification() throws {
        let (log, workout, set, _) = try store()
        _ = try timer.checkOff(set, in: workout, using: log, defaultRest: 90)
        let cancelsBefore = notifications.cancelCount
        try log.discard(workout)
        #expect(!timer.isRunning)
        #expect(notifications.cancelCount > cancelsBefore)
    }
}
