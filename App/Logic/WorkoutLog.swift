import Foundation
import SwiftData

/// Starts, edits, finishes and discards workouts. Every change saves at once, so killing the app loses nothing.
@MainActor
struct WorkoutLog {
    let context: ModelContext
    /// The rest timer that check-off starts and Finish and Discard stop. Nil where no timer is involved.
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

    /// Whether Finish can save the workout: it needs at least one checked set.
    static func hasCheckedSet(_ workout: Workout) -> Bool {
        workout.exercises.contains { $0.sets.contains(where: \.isCompleted) }
    }

    /// Whether any set in the workout is still unchecked.
    static func hasUncheckedSet(_ workout: Workout) -> Bool {
        workout.exercises.contains { $0.sets.contains { !$0.isCompleted } }
    }

    /// The first set after the given one, in workout order, whose field is empty: reps, or seconds for a
    /// duration exercise. Nil when there is none.
    static func nextEmptySet(after setID: UUID, in workout: Workout) -> WorkoutSet? {
        let sets = orderedExercises(of: workout).flatMap(orderedSets(of:))
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return nil }
        return sets[(index + 1)...].first { $0.values.isFieldEmpty }
    }

    // MARK: Changing

    /// Checks the set off when it can be, then returns the set to focus next, chosen as `nextEmptySet` does;
    /// an already checked set is left as it is. Nil, meaning close the keyboard, when there is no next set
    /// or the set can't be checked off.
    func checkOffAndAdvance(_ set: WorkoutSet, in workout: Workout) throws -> WorkoutSet? {
        if !set.isCompleted {
            guard set.values.canCheckOff else { return nil }
            try toggleCompleted(set)
        }
        return Self.nextEmptySet(after: set.id, in: workout)
    }

    /// Checks the set off through `checkOffAndAdvance` and, once that has saved, starts the rest for its
    /// exercise, as the checkmark and the keyboard's Done both do. Checking off the workout's last unchecked
    /// set starts no rest and reports `allSetsDone` instead. An already checked set, one that can't be checked
    /// off, or a failed save starts nothing.
    func checkOff(_ set: WorkoutSet, in workout: Workout, defaultRest: Int) throws
        -> CheckOffOutcome
    {
        let wasChecked = set.isCompleted
        let next = try checkOffAndAdvance(set, in: workout)
        guard !wasChecked, set.isCompleted else { return .focus(next) }
        guard Self.hasUncheckedSet(workout) else { return .allSetsDone }
        let exercise = set.workoutExercise?.exercise
        restTimer?.start(
            duration: RestTimer.restSeconds(for: exercise, defaultRest: defaultRest),
            exerciseName: exercise?.name, checkedSet: set)
        return .focus(next)
    }

    /// Starts an empty workout titled for its start time. Nil while another workout is in progress.
    func startEmptyWorkout(at date: Date = .now) throws -> Workout? {
        guard inProgressWorkout() == nil else { return nil }
        let workout = Workout(title: Self.defaultTitle(startingAt: date), startDate: date)
        context.insert(workout)
        try context.saveOrRollBack()
        return workout
    }

    /// Appends the exercise to the workout with one first set, completed when `completed` (editing a past workout).
    func addExercise(_ exercise: Exercise, to workout: Workout, completed: Bool = false) throws {
        let workoutExercise = WorkoutExercise(exercise: exercise, position: workout.exercises.count)
        context.insert(workoutExercise)
        workout.exercises.append(workoutExercise)
        appendSet(to: workoutExercise, completed: completed)
        try context.saveOrRollBack()
    }

    /// Appends a set copying the last set's type and values, or a first set when there is none; completed when
    /// `completed` (editing a past workout).
    func addSet(to workoutExercise: WorkoutExercise, completed: Bool = false) throws {
        appendSet(to: workoutExercise, completed: completed)
        try context.saveOrRollBack()
    }

    /// Sets the weight, which must be a PowerBlock setting; a bodyweight set's added weight may also be nil
    /// ("BW"). A weight the set's exercise type can't hold (none for weight × reps, any for duration) changes
    /// nothing and saves nothing.
    func setWeight(_ weight: Double?, of set: WorkoutSet) throws {
        guard let changed = set.values.settingWeight(weight) else { return }
        set.values = changed
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

    /// Inserts a copy of the set right after it, unchecked unless `completed` (editing a past workout).
    func duplicateSet(_ set: WorkoutSet, completed: Bool = false) throws {
        guard let workoutExercise = set.workoutExercise else { return }
        for later in workoutExercise.sets where later.position > set.position {
            later.position += 1
        }
        let copy = WorkoutSet(position: set.position + 1, setType: set.setType)
        copy.values = set.values
        copy.isCompleted = completed
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
        set.values = previous
        try context.saveOrRollBack()
        return true
    }

    /// Checks the set off, if it can be, or unchecks it.
    func toggleCompleted(_ set: WorkoutSet) throws {
        guard set.isCompleted || set.values.canCheckOff else { return }
        set.isCompleted.toggle()
        try context.saveOrRollBack()
    }

    /// Deletes unchecked sets and the exercises left with none, renumbers what remains, sets the title
    /// (when blank, the routine's name for a workout started from one, else the default title; line breaks
    /// becoming spaces) and the end date (never before the start), and saves.
    /// Nil, changing nothing, when no set is checked. When saving fails it rolls everything back, leaving the
    /// workout in progress as it was, and throws, returning no summary.
    func finish(_ workout: Workout, title: String, at date: Date = .now) throws -> WorkoutSummary? {
        guard Self.hasCheckedSet(workout) else { return nil }
        for workoutExercise in workout.exercises {
            let unchecked = workoutExercise.sets.filter { !$0.isCompleted }
            workoutExercise.sets.removeAll { !$0.isCompleted }
            unchecked.forEach(context.delete)
        }
        tidy(workout, title: title)
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
            exerciseCount: workout.exercises.count,
            nextInProgramme: ProgrammeLibrary.nextInProgramme(after: workout))
    }

    /// Deletes the exercises with no sets, renumbers the exercises and sets, and sets the title (when blank,
    /// the routine's name for a workout started from one, else the default title; line breaks becoming
    /// spaces). Does not save; the caller does.
    func tidy(_ workout: Workout, title: String) {
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
        workout.title =
            trimmed.isEmpty
            ? workout.routine?.name ?? Self.defaultTitle(startingAt: workout.startDate) : trimmed
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
    private func appendSet(to workoutExercise: WorkoutExercise, completed: Bool) {
        let last = Self.orderedSets(of: workoutExercise).last
        let set = WorkoutSet(
            position: workoutExercise.sets.count, setType: last?.setType ?? .normal)
        set.values =
            last?.values ?? SetValues.first(for: workoutExercise.exercise?.type ?? .weightReps)
        set.isCompleted = completed
        context.insert(set)
        workoutExercise.sets.append(set)
    }
}

/// What a check-off leaves for the workout screen to do.
enum CheckOffOutcome: Equatable {
    /// Focus moves to the set (nil closes the keyboard), as Next does.
    case focus(WorkoutSet?)
    /// The workout's last unchecked set was checked off, so no rest started; the screen offers Finish.
    case allSetsDone
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
    /// Nil when the workout's routine is in no programme.
    let nextInProgramme: NextInProgramme?
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
            if !values.canCheckOff { isCompleted = false }
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
            if !values.canCheckOff { isCompleted = false }
        }
    }
}
