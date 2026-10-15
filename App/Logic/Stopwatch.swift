import Foundation
import Observation

/// The full-screen timer a live workout's duration set opens: before Start, a goal for this run only; then a
/// 5-second get ready that ticks, then a count up from its start date. The goal chimes once when the count passes
/// it, and the count keeps going. Pause holds get ready or the count until Resume. Time comes from dates, so it keeps
/// counting while the app is in the background.
@Observable
@MainActor
final class Stopwatch: Identifiable {
    static let getReadySeconds = 5

    /// The two timed parts of the countdown: get ready, then the count up to the goal.
    enum Step: Equatable { case getReady, toGoal }

    enum Phase: Equatable { case setup, getReady, running }

    let set: WorkoutSet
    /// Nil is "No goal".
    private(set) var goal: Int?
    /// Nil before Start.
    private(set) var countdown: PhasedCountdown<Step>?
    /// When the count up starts: the end of get ready, or when Start Now was tapped. Kept here because the
    /// countdown forgets its dates once finished.
    private(set) var countStart: Date?
    /// When Pause was tapped; nil while not paused.
    private(set) var pausedAt: Date?

    @ObservationIgnored private var hasChimed = false
    @ObservationIgnored private let now: () -> Date

    /// The goal starts at `lastGoal` when the set has run on a stopwatch before (an undone Stop wrote its result into
    /// the seconds, which are no goal), else at the set's seconds, else its placeholder, else no goal. It is never
    /// written into the set.
    init(
        set: WorkoutSet, placeholder: Int?, lastGoal: Int?? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.set = set
        self.now = now
        goal =
            lastGoal ?? [set.values.seconds, placeholder].lazy.compactMap { $0 }.first { $0 > 0 }
    }

    var isPaused: Bool { pausedAt != nil }

    var phase: Phase {
        guard let countdown else { return .setup }
        return countdown.phase?.step == .getReady ? .getReady : .running
    }

    var canDecreaseGoal: Bool { phase == .setup && goal != nil }
    var canIncreaseGoal: Bool {
        phase == .setup && (goal ?? 0) < RoutineTarget.durationBounds.upperBound
    }

    /// Steps down to the next multiple of 5; from 5 or below, to no goal.
    func decreaseGoal() {
        guard canDecreaseGoal, let goal else { return }
        self.goal = goal <= 5 ? nil : (goal - 1) / 5 * 5
    }

    /// Steps up to the next multiple of 5, from no goal to 5, at most the longest target duration.
    func increaseGoal() {
        guard canIncreaseGoal else { return }
        let next = goal.map { ($0 / 5 + 1) * 5 } ?? 5
        goal = min(next, RoutineTarget.durationBounds.upperBound)
    }

    /// Starts get ready; the count up follows it.
    func start() {
        guard phase == .setup else { return }
        var phases: [PhasedCountdown<Step>.Phase] = [
            .init(step: .getReady, seconds: Self.getReadySeconds, isSignalled: true)
        ]
        if let goal { phases.append(.init(step: .toGoal, seconds: goal, isSignalled: false)) }
        countStart = now() + TimeInterval(Self.getReadySeconds)
        countdown = PhasedCountdown(phases: phases, now: now)
    }

    /// Holds get ready or the count; nothing before Start.
    func pause() {
        guard let countdown, pausedAt == nil else { return }
        // Catch up first, or a get ready already over would freeze, and on Resume the goal would start late. A goal
        // passed meanwhile still chimes at the next `advance()`, which reads the completed phase.
        _ = countdown.advance()
        pausedAt = now()
        countdown.pause()
    }

    /// Goes on from where Pause held it, the paused time left out of the count.
    func resume() {
        guard let pausedAt, let countStart else { return }
        self.countStart = countStart + now().timeIntervalSince(pausedAt)
        self.pausedAt = nil
        countdown?.resume()
    }

    /// Ends get ready and starts the count up now.
    func startNow() {
        guard phase == .getReady, !isPaused, let countdown else { return }
        countStart = now()
        countdown.move(to: 1)
    }

    /// The whole seconds counted up at the date; 0 before the count starts.
    func elapsed(at date: Date) -> Int {
        let date = min(date, pausedAt ?? date)
        guard let countStart, date > countStart else { return 0 }
        return Int(date.timeIntervalSince(countStart))
    }

    func isGoalReached(at date: Date) -> Bool {
        guard let goal else { return false }
        return elapsed(at: date) >= goal
    }

    /// Stop needs a whole second counted, so it never logs 0.
    func canStop(at date: Date) -> Bool { phase == .running && elapsed(at: date) >= 1 }

    /// The clock: moves the countdown on and returns what to play. Get ready's seconds tick; its end is silent, so
    /// the chime belongs to the goal, which plays it once, however late the catch-up.
    func advance() -> PhasedCountdown<Step>.Signal? {
        guard let countdown else { return nil }
        let signal = countdown.advance()
        if goal != nil, !hasChimed, countdown.completedSeconds[1] != nil {
            hasChimed = true
            return .chime
        }
        return signal == .tick ? .tick : nil
    }
}

/// The goal each set's last logged stopwatch run used, so a rerun after the set is undone starts from that goal,
/// not from the seconds Stop wrote. In memory only; the workout screen holds it.
@MainActor
struct StopwatchGoals {
    private var goals: [UUID: Int?] = [:]

    /// A stopwatch for the set, its goal from the set's last logged run when there was one.
    func stopwatch(
        for set: WorkoutSet, placeholder: Int?, now: @escaping () -> Date = { .now }
    ) -> Stopwatch {
        Stopwatch(set: set, placeholder: placeholder, lastGoal: goals[set.id], now: now)
    }

    /// Remembers the goal of a run whose Stop logged the set.
    mutating func logged(_ stopwatch: Stopwatch) {
        goals[stopwatch.set.id] = stopwatch.goal
    }
}
