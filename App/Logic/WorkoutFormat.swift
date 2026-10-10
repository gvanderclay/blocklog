import Foundation

/// How a workout was played: Sets, or a Timed AMRAP holding its score. Read once from a workout's stored fields
/// (`Workout.format`) and written back through the same property, so a score exists exactly when the format is
/// Timed AMRAP.
@MainActor
enum WorkoutFormat: Equatable {
    case sets
    case timedAMRAP(AMRAPScore)

    /// Reads the stored fields; nil for an unknown raw value (the workout stores only Timed AMRAP's), score fields
    /// on a Sets workout, or a Timed AMRAP whose fields don't read as an `AMRAPScore`. Import checks a stored
    /// workout with it.
    init?(rawValue: String?, rounds: Int?, extraReps: Int?) {
        switch (rawValue, rounds, extraReps) {
        case (nil, nil, nil): self = .sets
        case (let raw?, let rounds?, let extraReps?)
        where raw == RoutineFormat.Kind.timedAMRAP.rawValue:
            guard let score = AMRAPScore(storedRounds: rounds, extraReps: extraReps) else {
                return nil
            }
            self = .timedAMRAP(score)
        default: return nil
        }
    }

    /// The raw value the workout stores: nil for Sets.
    var rawValue: String? {
        if case .timedAMRAP = self { RoutineFormat.Kind.timedAMRAP.rawValue } else { nil }
    }

    /// The Timed AMRAP's score; nil for Sets.
    var score: AMRAPScore? {
        if case .timedAMRAP(let score) = self { score } else { nil }
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
            amrapRounds = newValue.score?.rounds
            amrapExtraReps = newValue.score?.extraReps
        }
    }
}
