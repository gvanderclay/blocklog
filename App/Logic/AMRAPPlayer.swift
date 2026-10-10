import Foundation
import Observation
import SwiftData

/// Drives the guided player through a Timed AMRAP, a starter one such as Cindy or one of the user's: before Start,
/// each dumbbell exercise's weight and last time's score; then a 10 s get-ready countdown, the time cap counting
/// down while the user taps Round done after each round, and at time up the extra reps of the unfinished round.
/// The time cap's last seconds tick and its end chimes. Logs the AMRAP, with its score, as a finished workout.
@Observable
@MainActor
final class AMRAPPlayer: Identifiable {
    /// The get-ready countdown before the time cap starts.
    static let getReadySeconds = 10

    /// The two timed parts of the countdown.
    enum Step: Equatable { case getReady, work }

    enum Phase: Equatable {
        /// Before Start: the weights and last time's score.
        case setup
        case getReady
        /// The time cap counting down, with the current round on screen.
        case running
        /// Paused during the get-ready countdown or the time cap.
        case paused
        /// The time cap has ended: the extra reps are entered.
        case timeUp
        /// Logged.
        case finished
    }

    /// What the user does. `send(_:)` takes each one, and ignores one its phase doesn't allow.
    enum Event: Equatable {
        /// Sets the weight of the exercise at the position; only before Start, and only a PowerBlock setting for a
        /// dumbbell exercise.
        case setWeight(entry: Int, weight: Double)
        case start
        case pause
        case resume
        /// Only while running.
        case roundDone
        /// Sets the extra reps, held from 0 to one fewer than the round's reps; only at time up.
        case setExtraReps(Int)
    }

    /// The routine's name, which titles the player and the workout.
    let name: String
    let round: AMRAPRound
    /// The stored routine played, which the workout links to; nil for a starter routine.
    let routine: Routine?
    let timeCapSeconds: Int
    /// Last time's score, read when the player was made; nil when there is none.
    let lastScore: AMRAPScore?
    /// Each exercise's weight, by position: the dumbbell weight, fixed from Start, or nil for a bodyweight
    /// exercise, which is logged with no added weight.
    private(set) var weights: [Double?]
    /// Nil before Start.
    private(set) var countdown: PhasedCountdown<Step>?
    /// The rounds done, plus the extra reps once time is up.
    private(set) var score: AMRAPScore
    /// When Start was tapped; nil before.
    private(set) var startDate: Date?
    /// The workout `log` saved, so a second call logs nothing more.
    private(set) var loggedWorkout: Workout?

    @ObservationIgnored private let now: () -> Date

    private init(
        name: String, round: AMRAPRound, routine: Routine?, timeCapSeconds: Int,
        lastScore: AMRAPScore?, weights: [Double?], score: AMRAPScore,
        now: @escaping () -> Date
    ) {
        self.name = name
        self.round = round
        self.routine = routine
        self.timeCapSeconds = timeCapSeconds
        self.lastScore = lastScore
        self.weights = weights
        self.score = score
        self.now = now
    }

    /// A player of the Timed AMRAP routine, before Start; the workout it logs links to the routine. Nil, starting
    /// nothing, while a workout is in progress, for a routine of another format, or when its exercises don't build
    /// an `AMRAPRound`.
    static func start(
        _ routine: Routine, in context: ModelContext, now: @escaping () -> Date = { .now }
    ) -> AMRAPPlayer? {
        guard case .timedAMRAP(let timeCapSeconds) = routine.format,
            WorkoutLog(context: context).inProgressWorkout() == nil,
            let round = AMRAPRound(routine.exercises)
        else { return nil }
        return make(
            name: routine.name, round: round, routine: routine, timeCapSeconds: timeCapSeconds,
            in: context, now: now)
    }

    /// A player of the starter Timed AMRAP, before Start; the workout it logs has no routine link. Saves any starter
    /// exercise it had to insert. Nil, starting nothing, while a workout is in progress, for a starter routine of
    /// another format, or when its exercises don't build an `AMRAPRound`.
    static func start(
        _ starterRoutine: StarterRoutine, in context: ModelContext,
        now: @escaping () -> Date = { .now }
    ) throws -> AMRAPPlayer? {
        guard case .timedAMRAP(let timeCapSeconds) = starterRoutine.format,
            WorkoutLog(context: context).inProgressWorkout() == nil
        else { return nil }
        let draft = try StarterLibrary(context: context).draft(of: starterRoutine)
        guard let round = AMRAPRound(draft: draft) else { return nil }
        return make(
            name: starterRoutine.name, round: round, routine: nil, timeCapSeconds: timeCapSeconds,
            in: context, now: now)
    }

    /// Reads last time's score and each dumbbell exercise's previous weight (5 lb with none).
    private static func make(
        name: String, round: AMRAPRound, routine: Routine?, timeCapSeconds: Int,
        in context: ModelContext, now: @escaping () -> Date
    ) -> AMRAPPlayer? {
        guard let zero = AMRAPScore(rounds: 0, extraReps: 0, of: round) else { return nil }
        let workouts = (try? context.fetch(WorkoutHistory.finishedWorkouts)) ?? []
        let lookup = PreviousSetLookup(context: context)
        let weights = round.entries.map { entry -> Double? in
            guard entry.exercise.type == .weightReps else { return nil }
            return SetValues.prefilled(
                for: .weightReps, previous: lookup.previousFirstSet(of: entry.exercise),
                progression: nil, targetSeconds: nil
            ).weight
        }
        return AMRAPPlayer(
            name: name, round: round, routine: routine, timeCapSeconds: timeCapSeconds,
            lastScore: AMRAPScore.last(of: routine, titled: name, in: workouts),
            weights: weights, score: zero, now: now)
    }

    // MARK: Reading

    var phase: Phase {
        guard let countdown else { return .setup }
        if loggedWorkout != nil { return .finished }
        if countdown.isFinished { return .timeUp }
        if countdown.isPaused { return .paused }
        return countdown.phase?.step == .getReady ? .getReady : .running
    }

    /// The positions of the dumbbell exercises, whose weights are set before Start.
    var dumbbellEntries: [Int] { weights.indices.filter { weights[$0] != nil } }

    /// The round being done, from 1.
    var roundNumber: Int { score.rounds + 1 }

    /// Whether quitting has something to save: a round done or extra reps entered, not yet logged.
    var hasSomethingToSave: Bool {
        phase != .finished && (score.rounds > 0 || score.extraReps > 0)
    }

    // MARK: Events

    /// Applies the event when the phase allows it, and returns the phase after it. An event the phase doesn't
    /// allow, such as Round done while paused or after time up, changes nothing.
    @discardableResult
    func send(_ event: Event) -> Phase {
        switch (event, phase) {
        case (.setWeight(let entry, let weight), .setup):
            if weights.indices.contains(entry), weights[entry] != nil,
                PowerBlockTable.setup(for: weight) != nil
            {
                weights[entry] = weight
            }
        case (.start, .setup):
            startDate = now()
            countdown = PhasedCountdown(
                phases: [
                    .init(step: .getReady, seconds: Self.getReadySeconds, isSignalled: false),
                    .init(step: .work, seconds: timeCapSeconds, isSignalled: true),
                ], now: now)
        case (.pause, .getReady), (.pause, .running):
            countdown?.pause()
        case (.resume, .paused):
            countdown?.resume()
        case (.roundDone, .running):
            score = AMRAPScore(rounds: score.rounds + 1, extraReps: 0, of: round) ?? score
        case (.setExtraReps(let reps), .timeUp):
            let held = min(max(reps, 0), round.repsPerRound - 1)
            score = AMRAPScore(rounds: score.rounds, extraReps: held, of: round) ?? score
        default: break
        }
        return phase
    }

    /// The clock: moves the countdown past every part whose end has passed (get ready to running, running to time
    /// up) and returns what to play, as `PhasedCountdown.advance()` does. Nothing before Start.
    func advance() -> PhasedCountdown<Step>.Signal? { countdown?.advance() }

    // MARK: Logging

    /// Saves a finished Timed AMRAP workout with the score (extra reps count only from time up; quitting early
    /// logs the rounds done), titled with the routine's name, linked to the stored routine played (none for a
    /// starter routine), from Start to now. It holds one completed set per exercise with its total reps (see
    /// `AMRAPRound.totalReps(for:)`) and its weight; an exercise whose total is 0 is left out. Nil, saving
    /// nothing, before Start or for a score of 0 rounds + 0 reps; a second call returns the workout already logged. Rolls back and throws when the
    /// save fails.
    func log(in context: ModelContext) throws -> Workout? {
        if let loggedWorkout { return loggedWorkout }
        // A score of 0 rounds + 0 reps has no set to log, so it logs no empty workout.
        let totals = round.totalReps(for: score)
        guard let startDate, totals.contains(where: { $0 > 0 }) else { return nil }
        let workout = Workout(
            title: name, startDate: startDate, endDate: max(now(), startDate), routine: routine)
        context.insert(workout)
        workout.format = .timedAMRAP(score)
        var position = 0
        for (index, entry) in round.entries.enumerated() where totals[index] > 0 {
            let workoutExercise = WorkoutExercise(exercise: entry.exercise, position: position)
            context.insert(workoutExercise)
            workout.exercises.append(workoutExercise)
            let set = WorkoutSet(position: 0, isCompleted: true)
            context.insert(set)
            workoutExercise.sets.append(set)
            set.values = SetValues(
                type: entry.exercise.type, weight: weights[index], reps: totals[index],
                seconds: nil)
            position += 1
        }
        try context.saveOrRollBack()
        loggedWorkout = workout
        return workout
    }
}
