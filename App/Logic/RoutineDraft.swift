import Foundation

/// The routine editor's unsaved copy of a routine: its name and its exercises, each with planned set types
/// and a rep range or a target duration. Nothing is stored until `RoutineLibrary.save` writes it.
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
            self.target = .orStandard(target, for: exercise.kind)
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
    var exercises: [Entry] = []

    /// An empty draft, for a new routine.
    init() {}

    /// A draft of the routine as stored. Entries whose exercise was deleted are left out, and stored values
    /// outside the editor's bounds are kept, since the bounds limit only what the user changes. A missing
    /// target reads as the standard one.
    init(routine: Routine) {
        name = routine.name
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

    /// Save needs a name and at least one exercise.
    var canSave: Bool {
        !trimmedName.isEmpty && !exercises.isEmpty
    }

    /// Appends the exercise with one normal set and the standard target for its type.
    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(Entry(exercise: exercise, sets: [PlannedSet(type: .normal)]))
    }
}
