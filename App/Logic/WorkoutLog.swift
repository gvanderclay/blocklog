import Foundation
import SwiftData

/// Starts, edits, finishes and discards workouts. Every change saves at once, so killing the app loses nothing.
@MainActor
struct WorkoutLog {
    let context: ModelContext
    /// The rest timer that Finish and Discard stop. Nil where no timer is involved.
    var restTimer: RestTimer?

    // MARK: Reading

    /// The workouts with no end date; at most one exists. Views use it in `@Query`.
    static var inProgressWorkouts: FetchDescriptor<Workout> {
        FetchDescriptor(predicate: #Predicate { $0.endDate == nil })
    }

    /// The workout with no end date. At most one exists.
    func inProgressWorkout() -> Workout? {
        var descriptor = Self.inProgressWorkouts
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// How many workouts have an end date.
    func finishedWorkoutCount() -> Int {
        (try? context.fetchCount(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.endDate != nil })))
            ?? 0
    }

    /// The workout's exercises in position order.
    static func orderedExercises(of workout: Workout) -> [WorkoutExercise] {
        workout.exercises.sorted { $0.position < $1.position }
    }

    /// The workout exercise's sets in position order.
    static func orderedSets(of workoutExercise: WorkoutExercise) -> [WorkoutSet] {
        workoutExercise.sets.sorted { $0.position < $1.position }
    }

    /// "Morning Workout" for a start from 5:00 to 11:59, "Afternoon Workout" from 12:00 to 16:59, otherwise "Evening Workout".
    static func defaultTitle(startingAt date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        default: "Evening Workout"
        }
    }

    /// Removing a workout exercise asks for confirmation only when it has a checked set to lose.
    static func needsRemovalConfirmation(_ workoutExercise: WorkoutExercise) -> Bool {
        workoutExercise.sets.contains(where: \.isCompleted)
    }

    /// Reordering needs at least two exercises.
    static func canReorder(_ workout: Workout) -> Bool {
        workout.exercises.count >= 2
    }

    /// The exercises Add Exercise offers, sorted by name.
    static var addableExercises: FetchDescriptor<Exercise> {
        FetchDescriptor(sortBy: [SortDescriptor(\.name)])
    }

    /// A set can be checked off only once it has reps, or seconds for a duration exercise.
    static func canCheckOff(_ set: WorkoutSet) -> Bool {
        if set.workoutExercise?.exercise?.kind == .duration {
            return (set.durationSeconds ?? 0) > 0
        }
        return (set.reps ?? 0) > 0
    }

    /// Whether Finish can save the workout: it needs at least one checked set.
    static func hasCheckedSet(_ workout: Workout) -> Bool {
        workout.exercises.contains { $0.sets.contains(where: \.isCompleted) }
    }

    /// The first set after the given one, in workout order, whose field is empty: reps, or seconds for a
    /// duration exercise. Nil when there is none.
    static func nextEmptySet(after setID: UUID, in workout: Workout) -> WorkoutSet? {
        let sets = orderedExercises(of: workout).flatMap(orderedSets(of:))
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return nil }
        return sets[(index + 1)...].first {
            $0.workoutExercise?.exercise?.kind == .duration
                ? $0.durationSeconds == nil : $0.reps == nil
        }
    }

    // MARK: Changing

    /// Checks the set off when it can be, then returns the set to focus next, chosen as `nextEmptySet` does;
    /// an already checked set is left as it is. Nil, meaning close the keyboard, when there is no next set
    /// or the set can't be checked off.
    func checkOffAndAdvance(_ set: WorkoutSet, in workout: Workout) throws -> WorkoutSet? {
        if !set.isCompleted {
            guard Self.canCheckOff(set) else { return nil }
            try toggleCompleted(set)
        }
        return Self.nextEmptySet(after: set.id, in: workout)
    }

    /// Starts an empty workout titled for its start time. Nil while another workout is in progress.
    func startEmptyWorkout(at date: Date = .now) throws -> Workout? {
        guard inProgressWorkout() == nil else { return nil }
        let workout = Workout(title: Self.defaultTitle(startingAt: date), startDate: date)
        context.insert(workout)
        try context.saveOrRollBack()
        return workout
    }

    /// Appends the exercise to the workout with one first set.
    func addExercise(_ exercise: Exercise, to workout: Workout) throws {
        let workoutExercise = WorkoutExercise(exercise: exercise, position: workout.exercises.count)
        context.insert(workoutExercise)
        workout.exercises.append(workoutExercise)
        appendSet(to: workoutExercise)
        try context.saveOrRollBack()
    }

    /// Appends a set copying the last set's type and values, or a first set when there is none.
    func addSet(to workoutExercise: WorkoutExercise) throws {
        appendSet(to: workoutExercise)
        try context.saveOrRollBack()
    }

    /// Sets the weight, which must be a PowerBlock setting.
    func setWeight(_ weight: Double, of set: WorkoutSet) throws {
        guard PowerBlockTable.setup(for: weight) != nil else { return }
        set.weight = weight
        try context.saveOrRollBack()
    }

    /// Sets the added weight of a bodyweight set: nil for none ("BW"), else a PowerBlock setting.
    func setAddedWeight(_ weight: Double?, of set: WorkoutSet) throws {
        if let weight, PowerBlockTable.setup(for: weight) == nil { return }
        set.weight = weight
        try context.saveOrRollBack()
    }

    /// Sets the set's type.
    func setType(_ type: SetType, of set: WorkoutSet) throws {
        set.setType = type
        try context.saveOrRollBack()
    }

    /// Deletes the set and renumbers the positions of the exercise's remaining sets.
    func deleteSet(_ set: WorkoutSet) throws {
        if let workoutExercise = set.workoutExercise {
            workoutExercise.sets.removeAll { $0 === set }
            Self.renumberSets(of: workoutExercise)
        }
        context.delete(set)
        try context.saveOrRollBack()
    }

    /// Inserts an unchecked copy of the set right after it.
    func duplicateSet(_ set: WorkoutSet) throws {
        guard let workoutExercise = set.workoutExercise else { return }
        for later in workoutExercise.sets where later.position > set.position {
            later.position += 1
        }
        let copy = WorkoutSet(
            position: set.position + 1, setType: set.setType, weight: set.weight, reps: set.reps,
            durationSeconds: set.durationSeconds)
        context.insert(copy)
        workoutExercise.sets.append(copy)
        try context.saveOrRollBack()
    }

    /// Deletes the workout exercise with its sets and renumbers the remaining exercises.
    func removeExercise(_ workoutExercise: WorkoutExercise) throws {
        if let workout = workoutExercise.workout {
            workout.exercises.removeAll { $0 === workoutExercise }
            for (position, other) in Self.orderedExercises(of: workout).enumerated() {
                other.position = position
            }
        }
        context.delete(workoutExercise)
        try context.saveOrRollBack()
    }

    /// Gives the exercises the positions of their place in `ordered`.
    func reorderExercises(_ ordered: [WorkoutExercise]) throws {
        for (position, workoutExercise) in ordered.enumerated() {
            workoutExercise.position = position
        }
        try context.saveOrRollBack()
    }

    /// Copies the previous values (weight, reps and duration) into an unchecked set. Returns false, changing
    /// nothing, when the set is checked or has no previous set.
    func copyPrevious(to set: WorkoutSet) throws -> Bool {
        guard !set.isCompleted,
            let previous = PreviousSetLookup(context: context).previous(for: set)
        else { return false }
        set.weight = previous.weight
        set.reps = previous.reps
        set.durationSeconds = previous.durationSeconds
        try context.saveOrRollBack()
        return true
    }

    /// Checks the set off, if it can be, or unchecks it.
    func toggleCompleted(_ set: WorkoutSet) throws {
        guard set.isCompleted || Self.canCheckOff(set) else { return }
        set.isCompleted.toggle()
        try context.saveOrRollBack()
    }

    /// Deletes unchecked sets and the exercises left with none, renumbers what remains, sets the title
    /// (the default title when blank, line breaks becoming spaces) and the end date (never before the start), and saves.
    /// Nil, changing nothing, when no set is checked. When saving fails it rolls everything back, leaving the
    /// workout in progress as it was, and throws, returning no summary.
    func finish(_ workout: Workout, title: String, at date: Date = .now) throws -> WorkoutSummary? {
        guard Self.hasCheckedSet(workout) else { return nil }
        for workoutExercise in workout.exercises {
            let unchecked = workoutExercise.sets.filter { !$0.isCompleted }
            workoutExercise.sets.removeAll { !$0.isCompleted }
            unchecked.forEach(context.delete)
        }
        let empty = workout.exercises.filter(\.sets.isEmpty)
        workout.exercises.removeAll(where: \.sets.isEmpty)
        empty.forEach(context.delete)
        for (position, workoutExercise) in Self.orderedExercises(of: workout).enumerated() {
            workoutExercise.position = position
            for (setPosition, set) in Self.orderedSets(of: workoutExercise).enumerated() {
                set.position = setPosition
            }
        }
        let trimmed = title.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        workout.title = trimmed.isEmpty ? Self.defaultTitle(startingAt: workout.startDate) : trimmed
        // A clock set back during the workout must not end it before it started (export rejects that).
        let end = max(date, workout.startDate)
        workout.endDate = end
        try context.saveOrRollBack()
        restTimer?.skip()
        return WorkoutSummary(
            workoutNumber: finishedWorkoutCount(),
            title: workout.title,
            duration: .seconds(end.timeIntervalSince(workout.startDate)),
            completedSetCount: workout.exercises.reduce(0) { $0 + $1.sets.count },
            exerciseCount: workout.exercises.count)
    }

    /// Deletes the workout with its exercises and sets.
    func discard(_ workout: Workout) throws {
        context.delete(workout)
        try context.saveOrRollBack()
        restTimer?.skip()
    }

    /// Sets the exercise's rest override, in every workout; nil uses the default rest.
    func setRestOverride(_ seconds: Int?, of exercise: Exercise) throws {
        exercise.restOverrideSeconds = seconds
        try context.saveOrRollBack()
    }

    private static func renumberSets(of workoutExercise: WorkoutExercise) {
        for (position, set) in orderedSets(of: workoutExercise).enumerated() {
            set.position = position
        }
    }

    /// A first set starts at 5 lb for weight × reps, with empty reps; later sets copy the last one.
    private func appendSet(to workoutExercise: WorkoutExercise) {
        let last = Self.orderedSets(of: workoutExercise).last
        let firstWeight =
            workoutExercise.exercise?.kind == .weightReps ? PowerBlockTable.weights[0] : nil
        let set = WorkoutSet(
            position: workoutExercise.sets.count,
            setType: last?.setType ?? .normal,
            weight: last == nil ? firstWeight : last?.weight,
            reps: last?.reps,
            durationSeconds: last?.durationSeconds)
        context.insert(set)
        workoutExercise.sets.append(set)
    }
}

/// What the finish summary shows about a just-finished workout.
@MainActor
struct WorkoutSummary {
    /// The count of all finished workouts, this one included.
    let workoutNumber: Int
    let title: String
    let duration: Duration
    let completedSetCount: Int
    let exerciseCount: Int
}

@MainActor
extension WorkoutSet {
    /// The reps as the text a reps field edits: digits only, at most three, empty for none.
    /// Clearing the reps (or entering 0) unchecks the set, so a checked set always has reps.
    /// A set row binds its field to this and saves when `reps` changes.
    var repsText: String {
        get { reps.map(String.init) ?? "" }
        set {
            reps = Int(String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(3)))
            if !WorkoutLog.canCheckOff(self) { isCompleted = false }
        }
    }
}

@MainActor
extension WorkoutSet {
    /// The duration as the text a seconds field edits: digits only, at most four, empty for none.
    /// Clearing the duration (or entering 0) unchecks the set, like `repsText`.
    var durationText: String {
        get { durationSeconds.map(String.init) ?? "" }
        set {
            durationSeconds = Int(String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(4)))
            if !WorkoutLog.canCheckOff(self) { isCompleted = false }
        }
    }
}
