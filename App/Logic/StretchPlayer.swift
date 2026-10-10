import Foundation
import Observation
import SwiftData

/// Drives the guided player through a stretch routine: for each round, each stretch in order, a lead-in then a
/// hold, and for a per-side stretch a second lead-in ("Switch sides") and hold. The last seconds of each hold tick
/// and its end chimes; lead-ins are silent. Logs what was done as a finished workout.
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

    let starterRoutine: StarterRoutine
    let rounds: Int
    let countdown: PhasedCountdown<Step>
    let startDate: Date
    /// The workout `log` saved, so a second call logs nothing more.
    private(set) var loggedWorkout: Workout?

    @ObservationIgnored private let now: () -> Date

    private init(starterRoutine: StarterRoutine, rounds: Int, now: @escaping () -> Date) {
        self.starterRoutine = starterRoutine
        self.rounds = rounds
        self.now = now
        startDate = now()
        let leadIn = StarterRoutine.leadInSeconds
        var phases: [PhasedCountdown<Step>.Phase] = []
        for round in 1...rounds {
            for (position, entry) in starterRoutine.exercises.enumerated() {
                // The 32a seeding resolves a stretch by name, maybe to a custom exercise, so the side count comes
                // from the starter routine's entry, never from the stored exercise.
                for side in entry.isPerSide ? [1, 2] : [nil] {
                    let step = { Step(kind: $0, round: round, entry: position, side: side) }
                    phases.append(.init(step: step(.leadIn), seconds: leadIn, isSignalled: false))
                    phases.append(
                        .init(
                            step: step(.hold), seconds: entry.target?.seconds ?? 0,
                            isSignalled: true))
                }
            }
        }
        countdown = PhasedCountdown(phases: phases, now: now)
    }

    /// Starts playing the routine for the rounds, clamped to `roundChoices`. Nil, starting nothing, while a
    /// workout is in progress.
    static func start(
        _ starterRoutine: StarterRoutine, rounds: Int, in context: ModelContext,
        now: @escaping () -> Date = { .now }
    ) -> StretchPlayer? {
        guard WorkoutLog(context: context).inProgressWorkout() == nil else { return nil }
        let rounds = min(max(rounds, roundChoices.lowerBound), roundChoices.upperBound)
        return StretchPlayer(starterRoutine: starterRoutine, rounds: rounds, now: now)
    }

    // MARK: Reading

    /// The current step; nil once finished.
    var step: Step? { countdown.phase?.step }

    /// The current stretch's name; nil once finished.
    var stretchName: String? { step.map { starterRoutine.exercises[$0.entry].exercise } }

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
        let entries = starterRoutine.exercises
        let next = step.entry + 1
        if next < entries.count { return entries[next].exercise }
        return step.round < rounds ? entries.first?.exercise : nil
    }

    /// Whether any hold ran to its end, so quitting has something to save.
    var hasCompletedHold: Bool {
        countdown.completedSeconds.keys.contains { countdown.phases[$0].step.kind == .hold }
    }

    // MARK: Controls

    func togglePause() {
        if countdown.isPaused { countdown.resume() } else { countdown.pause() }
    }

    /// Leaves the current hold, or its lead-in, without counting it, for the next hold's lead-in; past the last
    /// hold the routine finishes.
    func skip() {
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

    /// Saves a finished workout titled with the routine's name, with no routine link, from the start of play to
    /// now, holding one completed duration set per stretch per round whose hold (either side, for a per-side
    /// stretch) ran to its end. The set holds that hold's length with any added seconds, the longer side's for a
    /// per-side stretch. A stretch whose stored exercise doesn't record a duration (a custom exercise sharing the
    /// stretch's name) is left out. Nil, saving nothing, with nothing to log; a second call returns the workout
    /// already logged. Rolls back and throws when the save fails.
    func log(in context: ModelContext) throws -> Workout? {
        if let loggedWorkout { return loggedWorkout }
        // The longest completed hold by stretch, then round.
        var held: [Int: [Int: Int]] = [:]
        for (position, seconds) in countdown.completedSeconds {
            let step = countdown.phases[position].step
            guard step.kind == .hold, seconds > 0 else { continue }
            held[step.entry, default: [:]][step.round] = max(
                held[step.entry]?[step.round] ?? 0, seconds)
        }
        guard !held.isEmpty else { return nil }
        let entries = starterRoutine.exercises
        let exercises = try StarterExercises.exercises(
            named: held.keys.map { entries[$0].exercise }, in: context)
        let logged = held.keys.sorted().compactMap { entry -> (Exercise, [Int])? in
            guard let exercise = exercises[entries[entry].exercise], exercise.type == .duration,
                let rounds = held[entry]
            else { return nil }
            return (exercise, rounds.keys.sorted().compactMap { rounds[$0] })
        }
        // Every name resolves (a missing starter is inserted), so nothing is pending when all are left out.
        guard !logged.isEmpty else { return nil }
        let workout = Workout(
            title: starterRoutine.name, startDate: startDate, endDate: max(now(), startDate))
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
