import Foundation
import Observation

/// The full-screen timer a live workout's duration set opens: before Start, a goal for this run only; then a
/// 5-second get ready that ticks, then a count up from its start date. The goal chimes once when the count passes
/// it, and the count keeps going. Time comes from dates, so it keeps counting while the app is in the background.
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

    @ObservationIgnored private var hasChimed = false
    @ObservationIgnored private let now: () -> Date

    /// The goal starts at the set's seconds, else its placeholder, else no goal; it is never written back.
    init(set: WorkoutSet, placeholder: Int?, now: @escaping () -> Date = { .now }) {
        self.set = set
        self.now = now
        goal = [set.values.seconds, placeholder].lazy.compactMap { $0 }.first { $0 > 0 }
    }

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

    /// Ends get ready and starts the count up now.
    func startNow() {
        guard phase == .getReady, let countdown else { return }
        countStart = now()
        countdown.move(to: 1)
    }

    /// The whole seconds counted up at the date; 0 before the count starts.
    func elapsed(at date: Date) -> Int {
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
