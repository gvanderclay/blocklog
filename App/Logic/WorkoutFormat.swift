import Foundation

/// How a workout was played: Sets, or a Timed AMRAP holding its score, completed rounds plus extra reps. Read once
/// from a workout's stored fields (`Workout.format`) and written back through the same property, so the score
/// fields exist exactly when the format is Timed AMRAP.
@MainActor
enum WorkoutFormat: Equatable {
    case sets
    case timedAMRAP(rounds: Int, extraReps: Int)

    /// Reads the stored fields; nil for an unknown raw value (the workout stores only Timed AMRAP's), score fields
    /// on a Sets workout, or a Timed AMRAP without both score fields, each 0 or more. Import checks a stored workout
    /// with it.
    init?(rawValue: String?, rounds: Int?, extraReps: Int?) {
        switch (rawValue, rounds, extraReps) {
        case (nil, nil, nil): self = .sets
        case (let raw?, let rounds?, let extraReps?)
        where raw == RoutineFormat.Kind.timedAMRAP.rawValue && rounds >= 0 && extraReps >= 0:
            self = .timedAMRAP(rounds: rounds, extraReps: extraReps)
        default: return nil
        }
    }

    /// The raw value the workout stores: nil for Sets.
    var rawValue: String? {
        if case .timedAMRAP = self { RoutineFormat.Kind.timedAMRAP.rawValue } else { nil }
    }
}

@MainActor
extension Workout {
    /// The workout's format, read from its stored raw value and score. Stored fields that don't read as a format
    /// read as Sets: only a bug could write them, since import refuses them. Setting it writes all three fields.
    /// The caller saves.
    var format: WorkoutFormat {
        get {
            WorkoutFormat(rawValue: formatRawValue, rounds: amrapRounds, extraReps: amrapExtraReps)
                ?? .sets
        }
        set {
            formatRawValue = newValue.rawValue
            switch newValue {
            case .sets:
                amrapRounds = nil
                amrapExtraReps = nil
            case .timedAMRAP(let rounds, let extraReps):
                amrapRounds = rounds
                amrapExtraReps = extraReps
            }
        }
    }
}
