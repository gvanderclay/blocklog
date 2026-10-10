import Foundation

/// The routine editor's unsaved copy of a routine: its name, its format and its exercises, each with planned set
/// types and a rep range or a target duration. Nothing is stored until `RoutineLibrary.save` writes it.
@MainActor
struct RoutineDraft: Identifiable {
    let id = UUID()
    /// One exercise of the draft. Its target is a rep range or a target duration, whichever the exercise's
    /// type uses, and never changes case.
    @MainActor
    struct Entry: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var sets: [PlannedSet]
        private(set) var target: RoutineTarget

        /// An entry with `target`, or the exercise type's standard target when that is nil or of the other
        /// case.
        init(exercise: Exercise, sets: [PlannedSet], target: RoutineTarget? = nil) {
            self.exercise = exercise
            self.sets = sets
            self.target = .orStandard(target, for: exercise.type)
        }

        /// The low end of the rep range, for a stepper to bind to. A duration entry reads the standard
        /// range's low end, and setting it changes nothing.
        var repLow: Int {
            get { target.repRange?.lowerBound ?? RoutineTarget.defaultRepRange.lowerBound }
            set { target = target.settingLow(newValue) }
        }

        /// The high end of the rep range, for a stepper to bind to; see `repLow`.
        var repHigh: Int {
            get { target.repRange?.upperBound ?? RoutineTarget.defaultRepRange.upperBound }
            set { target = target.settingHigh(newValue) }
        }

        /// The target duration in seconds, for a stepper to bind to. A rep entry reads the standard duration,
        /// and setting it changes nothing.
        var targetDurationSeconds: Int {
            get { target.seconds ?? RoutineTarget.defaultDurationSeconds }
            set { target = target.settingSeconds(newValue) }
        }

        /// A Timed AMRAP entry's fixed rep count, for a stepper to bind to: the high end of the range, and setting
        /// it makes both ends the new count. A duration entry reads the standard range's high end, and setting it
        /// changes nothing.
        var reps: Int {
            get { repHigh }
            set { target = target.settingReps(newValue) }
        }

        /// One normal set at the range's high end, as a Timed AMRAP entry has; a duration entry keeps its target.
        mutating func makeFixed() {
            sets = [PlannedSet(type: .normal)]
            target = target.settingReps(repHigh)
        }

        /// Appends a set of the same type as the last set, or a normal set when there is none.
        mutating func addSet() {
            sets.append(PlannedSet(type: sets.last?.type ?? .normal))
        }
    }

    /// One planned set: only its type, since routines store no weights or reps.
    struct PlannedSet: Identifiable {
        let id = UUID()
        var type: SetType
    }

    var name = ""
    /// Changed through `switchFormat(to:)` and `timeCapMinutes`, which keep it allowing every exercise.
    private(set) var format = RoutineFormat.sets
    var exercises: [Entry] = []

    /// An empty draft, for a new routine.
    init() {}

    /// A draft of a routine that isn't stored yet, such as a starter routine's.
    init(name: String, format: RoutineFormat, exercises: [Entry]) {
        self.name = name
        self.format = format
        self.exercises = exercises
    }

    /// A draft of the routine as stored. Entries whose exercise was deleted are left out, and stored values
    /// outside the editor's bounds are kept, since the bounds limit only what the user changes. A missing
    /// target reads as the standard one.
    init(routine: Routine) {
        name = routine.name
        format = routine.format
        exercises = RoutineLibrary.orderedExercises(of: routine).compactMap { stored in
            guard let exercise = stored.exercise else { return nil }
            return Entry(
                exercise: exercise,
                sets: stored.plannedSetTypeRawValues.map {
                    PlannedSet(type: SetType(rawValue: $0) ?? .normal)
                },
                target: stored.target)
        }
    }

    /// The name as saved: trimmed, with line breaks as spaces.
    var trimmedName: String {
        name.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Reordering needs at least two exercises.
    var canReorder: Bool { exercises.count >= 2 }

    /// Save needs a name and at least one exercise, and the routine it writes must read back as its format: a
    /// Timed AMRAP's exercises build an `AMRAPRound`, and a Stretch routine's a `StretchRound`.
    var canSave: Bool {
        guard !trimmedName.isEmpty, !exercises.isEmpty,
            RoutineFormat(rawValue: format.rawValue, timeCapSeconds: format.timeCapSeconds) != nil
        else { return false }
        switch format {
        case .sets: return true
        case .timedAMRAP:
            return AMRAPRound.fixedReps(
                of: exercises.map {
                    .init(type: $0.exercise.type, plannedSetCount: $0.sets.count, target: $0.target)
                }) != nil
        case .stretch:
            return StretchRound.holdSeconds(
                of: exercises.map { .init(type: $0.exercise.type, target: $0.target) }) != nil
        }
    }

    /// A Timed AMRAP's time cap in minutes, for a stepper to bind to; setting it holds it within
    /// `RoutineFormat.timeCapMinuteBounds`. Another format reads the default and ignores a new value.
    var timeCapMinutes: Int {
        get { format.timeCapMinutes ?? RoutineFormat.defaultTimeCapMinutes }
        set {
            guard case .timedAMRAP = format else { return }
            format = .timedAMRAP(minutes: newValue)
        }
    }

    /// Switches the draft to the format, with the default time cap for Timed AMRAP, and returns nil. Switching to
    /// Timed AMRAP also gives each exercise one normal set at its range's high end. Refused, changing nothing,
    /// while the draft holds an exercise the format doesn't allow; the result is then the message saying so.
    @discardableResult
    mutating func switchFormat(to kind: RoutineFormat.Kind) -> String? {
        guard kind != format.kind else { return nil }
        let newFormat: RoutineFormat =
            switch kind {
            case .sets: .sets
            case .timedAMRAP: .timedAMRAP(minutes: RoutineFormat.defaultTimeCapMinutes)
            case .stretch: .stretch
            }
        if let refused = exercises.first(where: { !newFormat.allows($0.exercise.type) }) {
            let takes = kind == .stretch ? "timed exercises" : "rep exercises"
            return "\(kind.title) takes only \(takes). Remove \(refused.exercise.name) first."
        }
        format = newFormat
        if kind == .timedAMRAP {
            for index in exercises.indices { exercises[index].makeFixed() }
        }
        return nil
    }

    /// Appends the exercise with one normal set and the standard target for its type, its range fixed at the high
    /// end in a Timed AMRAP. False, adding nothing, when the format doesn't allow the exercise's type.
    @discardableResult
    mutating func addExercise(_ exercise: Exercise) -> Bool {
        guard format.allows(exercise.type) else { return false }
        var entry = Entry(exercise: exercise, sets: [PlannedSet(type: .normal)])
        if case .timedAMRAP = format { entry.makeFixed() }
        exercises.append(entry)
        return true
    }
}
