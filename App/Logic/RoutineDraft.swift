import Foundation

/// The routine editor's unsaved copy of a routine: its name and its exercises, each with planned set types
/// and a rep range or a target duration. Nothing is stored until `RoutineLibrary.save` writes it.
@MainActor
struct RoutineDraft {
    /// The values a rep-range end can take.
    static let repBounds = 1...BackupDocument.maxRepRange
    static let defaultRepRange = (low: 8, high: 12)
    static let defaultTargetDuration = 30
    /// The values a target duration can take, in steps of `targetDurationStep` seconds.
    static let targetDurationBounds = 5...600
    static let targetDurationStep = 5

    /// One exercise of the draft. A rep-based exercise uses the rep range and a duration exercise uses the
    /// target duration; the other value is kept but never saved.
    @MainActor
    struct Entry: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var sets: [PlannedSet]
        var repLow: Int
        var repHigh: Int
        var targetDurationSeconds: Int

        var isTimed: Bool { exercise.kind == .duration }
        /// Low can't pass high, so the range always reads low–high.
        /// A stored value outside `repBounds` is kept as it is, so the bounds still contain the current value.
        var repLowBounds: ClosedRange<Int> {
            min(RoutineDraft.repBounds.lowerBound, repHigh)...repHigh
        }
        var repHighBounds: ClosedRange<Int> {
            repLow...max(RoutineDraft.repBounds.upperBound, repLow)
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
    /// outside the editor's bounds are kept, since the bounds limit only what the user changes; only a low
    /// above its high is lowered to the high.
    init(routine: Routine) {
        name = routine.name
        exercises = RoutineLibrary.orderedExercises(of: routine).compactMap { stored in
            guard let exercise = stored.exercise else { return nil }
            let high = stored.repRangeHigh ?? Self.defaultRepRange.high
            let low = min(stored.repRangeLow ?? Self.defaultRepRange.low, high)
            return Entry(
                exercise: exercise,
                sets: stored.plannedSetTypeRawValues.map {
                    PlannedSet(type: SetType(rawValue: $0) ?? .normal)
                },
                repLow: low, repHigh: high,
                targetDurationSeconds: stored.targetDurationSeconds ?? Self.defaultTargetDuration)
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

    /// Appends the exercise with one normal set, the rep range 8–12 and a 30 s target.
    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(
            Entry(
                exercise: exercise, sets: [PlannedSet(type: .normal)],
                repLow: Self.defaultRepRange.low,
                repHigh: Self.defaultRepRange.high,
                targetDurationSeconds: Self.defaultTargetDuration
            ))
    }
}
