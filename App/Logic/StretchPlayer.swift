import Foundation
import Observation
import SwiftData

/// Drives the guided player through a stretch routine, a starter one or a Stretch-format routine: for each round,
/// each stretch in order, a lead-in then a hold, and for a per-side stretch a second lead-in ("Switch sides") and
/// hold. The last seconds of each hold tick and its end chimes; lead-ins are silent. Logs what was done as a
/// finished workout.
@Observable
@MainActor
final class StretchPlayer: Identifiable {
    /// The rounds a player offers before Start.
    static let roundChoices = 1...3
    /// The seconds +15 adds.
    static let addedSeconds = 15

    /// One phase of the routine.
    struct Step: Equatable {
        enum Kind: Equatable { case leadIn, hold }
        let kind: Kind
        /// From 1.
        let round: Int
        /// The stretch's position in the routine.
        let entry: Int
        /// 1 or 2 for a per-side stretch, nil for one that isn't.
        let side: Int?

        /// "Get into position" before a hold, "Switch sides" before a per-side stretch's second hold, and for a
        /// per-side hold its side, "Side 1 of 2". Nil for any other hold.
        var status: String? {
            switch (kind, side) {
            case (.leadIn, 2): "Switch sides"
            case (.leadIn, _): "Get into position"
            case (.hold, let side?): "Side \(side) of 2"
            case (.hold, nil): nil
            }
        }
    }

    /// The routine's name, which titles the player and the workout.
    let name: String
    let round: StretchRound
    /// The stored routine played, which the workout links to; nil for a starter stretch routine.
    let routine: Routine?
    let rounds: Int
    let countdown: PhasedCountdown<Step>
    let startDate: Date
    /// The workout `log` saved, so a second call logs nothing more.
    private(set) var loggedWorkout: Workout?

    @ObservationIgnored private let now: () -> Date

    private init(
        name: String, round: StretchRound, routine: Routine?, rounds: Int,
        now: @escaping () -> Date
    ) {
        self.name = name
        self.round = round
        self.routine = routine
        self.rounds = rounds
        self.now = now
        startDate = now()
        let leadIn = StarterRoutine.leadInSeconds
        var phases: [PhasedCountdown<Step>.Phase] = []
        let stretches = round.stretches
        for round in 1...rounds {
            for (position, stretch) in stretches.enumerated() {
                for side in stretch.isPerSide ? [1, 2] : [nil] {
                    let step = { Step(kind: $0, round: round, entry: position, side: side) }
                    phases.append(.init(step: step(.leadIn), seconds: leadIn, isSignalled: false))
                    phases.append(
                        .init(
                            step: step(.hold), seconds: stretch.seconds, isSignalled: true))
                }
            }
        }
        countdown = PhasedCountdown(phases: phases, now: now)
    }

    /// Starts playing the starter stretch routine for the rounds, clamped to `roundChoices`. Nil, starting
    /// nothing, while a workout is in progress or when it doesn't build a `StretchRound`.
    static func start(
        _ starterRoutine: StarterRoutine, rounds: Int, in context: ModelContext,
        now: @escaping () -> Date = { .now }
    ) -> StretchPlayer? {
        guard let round = StretchRound(starterRoutine) else { return nil }
        return start(
            name: starterRoutine.name, round: round, routine: nil, rounds: rounds, in: context,
            now: now)
    }

    /// Starts playing a Stretch-format routine for the rounds, clamped to `roundChoices`; the workout it logs links
    /// to the routine. Nil, starting nothing, while a workout is in progress, for a routine of another format, or
    /// when its exercises don't build a `StretchRound`.
    static func start(
        _ routine: Routine, rounds: Int, in context: ModelContext,
        now: @escaping () -> Date = { .now }
    ) -> StretchPlayer? {
        guard routine.format == .stretch, let round = StretchRound(routine.exercises) else {
            return nil
        }
        return start(
            name: routine.name, round: round, routine: routine, rounds: rounds, in: context,
            now: now)
    }

    private static func start(
        name: String, round: StretchRound, routine: Routine?, rounds: Int,
        in context: ModelContext, now: @escaping () -> Date
    ) -> StretchPlayer? {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        let rounds = min(max(rounds, roundChoices.lowerBound), roundChoices.upperBound)
        return StretchPlayer(name: name, round: round, routine: routine, rounds: rounds, now: now)
    }

    // MARK: Reading

    /// The current step; nil once finished.
    var step: Step? { countdown.phase?.step }

    /// The current stretch's name; nil once finished.
    var stretchName: String? { step.map { round.stretches[$0.entry].name } }

    /// The current stretch's cue and variations; nil once finished or for a stretch with none.
    var cue: StretchCue? { stretchName.flatMap { StretchCue.bundled[$0] } }

    /// "Round 2 of 3" when playing more than one round; nil for one round or once finished.
    var roundText: String? {
        guard rounds > 1, let step else { return nil }
        return "Round \(step.round) of \(rounds)"
    }

    /// The stretch after the current one, in this round or the next; nil during the last stretch and once
    /// finished.
    var upNext: String? {
        guard let step else { return nil }
        let stretches = round.stretches
        let next = step.entry + 1
        if next < stretches.count { return stretches[next].name }
        return step.round < rounds ? stretches.first?.name : nil
    }

    // MARK: Controls

    func togglePause() {
        if countdown.isPaused { countdown.resume() } else { countdown.pause() }
    }

    /// From a lead-in, starts its hold at once. From a hold, leaves it uncounted for the next hold's lead-in; past
    /// the last hold the routine finishes.
    func skip() {
        if step?.kind == .leadIn {
            countdown.move(to: countdown.index + 1)
            return
        }
        let next = countdown.phases.indices.dropFirst(countdown.index + 1).first {
            countdown.phases[$0].step.kind == .leadIn
        }
        countdown.move(to: next ?? countdown.phases.count)
    }

    /// Goes back to the previous hold's lead-in, or to the first hold's lead-in from the first hold.
    func back() {
        guard let step else { return }
        let leadIn = step.kind == .hold ? countdown.index - 1 : countdown.index
        countdown.move(to: leadIn - 2)
    }

    /// Adds `addedSeconds` to the current lead-in or hold.
    func addTime() { countdown.add(seconds: Self.addedSeconds) }

    // MARK: Logging

    /// Saves a finished workout titled with the routine's name, linked to the stored routine played (none for a
    /// starter routine), from the start of play to
    /// now, holding one completed duration set per stretch per round whose hold (either side, for a per-side
    /// stretch) ran to its end, or is the hold under way when finishing early. The set holds that hold's length with
    /// any added seconds, or the seconds held so far for the hold under way, the longer side's for a per-side
    /// stretch. A stretch whose stored exercise doesn't record a duration (a custom exercise sharing the
    /// stretch's name) is left out. Nil, saving nothing, with nothing to log; a second call returns the workout
    /// already logged. Rolls back and throws when the save fails.
    func log(in context: ModelContext) throws -> Workout? {
        if let loggedWorkout { return loggedWorkout }
        // The longest completed hold by stretch, then round.
        var held: [Int: [Int: Int]] = [:]
        var holds = countdown.completedSeconds
        if !countdown.isFinished {
            let soFar = countdown.length - countdown.seconds(at: now())
            holds[countdown.index] = max(holds[countdown.index] ?? 0, soFar)
        }
        for (position, seconds) in holds {
            let step = countdown.phases[position].step
            guard step.kind == .hold, seconds > 0 else { continue }
            held[step.entry, default: [:]][step.round] = max(
                held[step.entry]?[step.round] ?? 0, seconds)
        }
        guard !held.isEmpty else { return nil }
        let stretches = round.stretches
        let exercises = try StarterExercises.exercises(
            named: held.keys.map { stretches[$0].name }, in: context)
        let logged = held.keys.sorted().compactMap { entry -> (Exercise, [Int])? in
            guard let exercise = exercises[stretches[entry].name], exercise.type == .duration,
                let rounds = held[entry]
            else { return nil }
            return (exercise, rounds.keys.sorted().compactMap { rounds[$0] })
        }
        // Every name resolves (a missing starter is inserted), so nothing is pending when all are left out.
        guard !logged.isEmpty else { return nil }
        let workout = Workout(
            title: name, startDate: startDate, endDate: max(now(), startDate), routine: routine)
        context.insert(workout)
        for (position, (exercise, seconds)) in logged.enumerated() {
            let workoutExercise = WorkoutExercise(exercise: exercise, position: position)
            context.insert(workoutExercise)
            workout.exercises.append(workoutExercise)
            for (setPosition, seconds) in seconds.enumerated() {
                let set = WorkoutSet(position: setPosition, isCompleted: true)
                context.insert(set)
                workoutExercise.sets.append(set)
                set.values = .duration(seconds: seconds)
            }
        }
        try context.saveOrRollBack()
        loggedWorkout = workout
        return workout
    }
}
