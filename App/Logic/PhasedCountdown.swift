import Foundation
import Observation

/// A countdown through phases in order, such as a guided player's lead-ins and holds. It reads "now" from an
/// injected clock and stores the current phase with its end date (or the seconds left while paused), never a
/// ticking counter. It runs from phase 0 as soon as it is made; a phase that reaches its end moves on to the next
/// at once, and the countdown finishes after the last.
@Observable
@MainActor
final class PhasedCountdown<Step: Equatable> {
    /// One timed phase: what it is, its length, and whether it is signalled.
    struct Phase: Equatable {
        let step: Step
        let seconds: Int
        /// True when the phase's last `tickSeconds` tick and its end chimes, as a stretch hold's do.
        let isSignalled: Bool
    }

    /// What the caller plays when `advance()` reports it.
    enum Signal: Equatable {
        /// One of a signalled phase's last `tickSeconds` began.
        case tick
        /// A signalled phase reached its end.
        case chime
    }

    enum State: Equatable {
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    /// How many of a signalled phase's last seconds tick.
    static var tickSeconds: Int { 5 }

    let phases: [Phase]
    /// The current phase's position; `phases.count` once finished.
    private(set) var index = 0
    private(set) var state: State
    /// The current phase's length so far: its seconds plus any added.
    private(set) var length: Int
    /// The length each phase ran to its end, added seconds included, by position. A phase left before its end
    /// (skipped, or moved away from) is absent; one run again after reaching its end keeps its last length.
    private(set) var completedSeconds: [Int: Int] = [:]

    @ObservationIgnored private let now: () -> Date
    /// The whole seconds left at the last tick, so each second ticks once.
    @ObservationIgnored private var lastTick: Int?

    init(phases: [Phase], now: @escaping () -> Date = { .now }) {
        self.phases = phases
        self.now = now
        let length = phases.first?.seconds ?? 0
        self.length = length
        state = phases.isEmpty ? .finished : .running(endDate: now() + TimeInterval(length))
    }

    var phase: Phase? { phases.indices.contains(index) ? phases[index] : nil }
    var isPaused: Bool { if case .paused = state { true } else { false } }
    var isFinished: Bool { state == .finished }

    /// The seconds left in the current phase at the date, never negative; 0 once finished.
    func remaining(at date: Date) -> TimeInterval {
        switch state {
        case .running(let endDate): max(endDate.timeIntervalSince(date), 0)
        case .paused(let remaining): remaining
        case .finished: 0
        }
    }

    /// The whole seconds shown at the date: the seconds left, rounded up.
    func seconds(at date: Date) -> Int { Int(remaining(at: date).rounded(.up)) }

    /// Where a once-a-second timeline starts: the current phase's start, in the past, so every tick falls on the
    /// end date's seconds.
    var timelineAnchor: Date {
        if case .running(let endDate) = state { endDate - TimeInterval(length) } else { now() }
    }

    /// When `advance()` next has something to do: the next tick of a signalled phase, else the phase's end. Nil
    /// while paused or finished.
    var nextWake: Date? {
        guard case .running(let endDate) = state, let phase else { return nil }
        let ticksLeft = min(Self.tickSeconds, Int(remaining(at: now()).rounded(.up)) - 1)
        return phase.isSignalled && ticksLeft >= 1 ? endDate - TimeInterval(ticksLeft) : endDate
    }

    /// Moves past every phase whose end has passed, each completing with its length, and returns what to play
    /// now: the chime when a signalled phase ended, otherwise a tick when one of a signalled phase's last
    /// `tickSeconds` began since the last tick, otherwise nothing. Several phases passed at once play one signal.
    func advance() -> Signal? {
        let date = now()
        var signal: Signal?
        while case .running(let endDate) = state, let phase, date >= endDate {
            completedSeconds[index] = length
            if phase.isSignalled { signal = .chime }
            begin(index + 1, endingFrom: endDate)
        }
        guard signal == nil, case .running = state, phase?.isSignalled == true else {
            return signal
        }
        let left = seconds(at: date)
        guard (1...Self.tickSeconds).contains(left), left != lastTick else { return nil }
        lastTick = left
        return .tick
    }

    func pause() {
        guard case .running = state else { return }
        state = .paused(remaining: remaining(at: now()))
    }

    func resume() {
        guard case .paused(let remaining) = state else { return }
        state = .running(endDate: now() + remaining)
    }

    /// Starts the phase at the position afresh, paused if the countdown is paused; a position past the last
    /// finishes. The phase left doesn't complete.
    func move(to position: Int) {
        guard !isFinished else { return }
        let wasPaused = isPaused
        begin(max(position, 0), endingFrom: now())
        if wasPaused { pause() }
    }

    /// Adds seconds to the current phase. Does nothing once finished.
    func add(seconds: Int) {
        switch state {
        case .running(let endDate): state = .running(endDate: endDate + TimeInterval(seconds))
        case .paused(let remaining): state = .paused(remaining: remaining + TimeInterval(seconds))
        case .finished: return
        }
        length += seconds
        lastTick = nil
    }

    /// Makes the phase at the position current, running from the date, or finishes past the last.
    private func begin(_ position: Int, endingFrom date: Date) {
        index = min(position, phases.count)
        lastTick = nil
        guard let phase else {
            length = 0
            state = .finished
            return
        }
        length = phase.seconds
        state = .running(endDate: date + TimeInterval(length))
    }
}
