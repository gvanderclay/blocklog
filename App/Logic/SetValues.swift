import Foundation

/// The values a set records, which depend on its exercise type: one case per type, each holding only that
/// type's values. A weight × reps set always has a weight; reps and seconds stay optional, because an unchecked
/// set is a draft. Read once from a set's stored fields (`WorkoutSet.values`) and written back through the same
/// property, so no other code decides which of the stored weight, reps and seconds apply.
@MainActor
enum SetValues: Equatable {
    case weightReps(weight: Double, reps: Int?)
    /// The added weight is nil for none ("BW").
    case bodyweightReps(addedWeight: Double?, reps: Int?)
    case duration(seconds: Int?)

    /// Reads the stored fields as the values of an exercise type, ignoring the fields it doesn't record.
    /// A weight × reps set with no weight has no producer (import rejects it, no screen writes it), so it reads
    /// as the lowest PowerBlock setting.
    init(kind: ExerciseKind, weight: Double?, reps: Int?, seconds: Int?) {
        switch kind {
        case .weightReps:
            self = .weightReps(weight: weight ?? PowerBlockTable.weights[0], reps: reps)
        case .bodyweightReps: self = .bodyweightReps(addedWeight: weight, reps: reps)
        case .duration: self = .duration(seconds: seconds)
        }
    }

    /// Reads the stored fields as a finished set of the exercise type: exactly the values the type records,
    /// weight × reps with a weight and reps of at least 1, bodyweight with reps of at least 1, duration with
    /// seconds above 0. Nil when they are not.
    init?(complete kind: ExerciseKind, weight: Double?, reps: Int?, seconds: Int?) {
        switch kind {
        case .weightReps:
            guard let weight, (reps ?? 0) >= 1, seconds == nil else { return nil }
            self = .weightReps(weight: weight, reps: reps)
        case .bodyweightReps:
            guard (reps ?? 0) >= 1, seconds == nil else { return nil }
            self = .bodyweightReps(addedWeight: weight, reps: reps)
        case .duration:
            guard (seconds ?? 0) > 0, weight == nil, reps == nil else { return nil }
            self = .duration(seconds: seconds)
        }
    }

    /// What `init?(complete:…)` asks of a set of the type, as the end of a sentence about a set.
    static func requirement(of kind: ExerciseKind) -> String {
        switch kind {
        case .weightReps: "that needs a weight and reps, and no duration"
        case .bodyweightReps: "that needs reps and no duration"
        case .duration: "that needs a duration and no weight or reps"
        }
    }

    /// A first set: 5 lb with empty reps for weight × reps, "BW" with empty reps for bodyweight reps, and empty
    /// seconds for duration.
    static func first(for kind: ExerciseKind) -> SetValues {
        SetValues(kind: kind, weight: nil, reps: nil, seconds: nil)
    }

    /// The values a set of a workout started from a routine begins with, in this priority: a duration set gets
    /// the target duration, or 30 s with none; a set with a progression gets its weight and reps; any other
    /// set gets the values of `previous` (last time's set paired with it), or, with nothing from last time, the
    /// values of a first set.
    static func prefilled(
        for kind: ExerciseKind, previous: SetValues?,
        progression: (weight: Double, reps: Int)?, targetSeconds: Int?
    ) -> SetValues {
        if kind == .duration {
            return .duration(seconds: targetSeconds ?? RoutineTarget.defaultDurationSeconds)
        }
        if let progression {
            return SetValues(
                kind: kind, weight: progression.weight, reps: progression.reps, seconds: nil)
        }
        guard let previous else { return first(for: kind) }
        // A bodyweight set's nil weight is "BW", so last time's nil is kept rather than defaulted.
        return SetValues(kind: kind, weight: previous.weight, reps: previous.reps, seconds: nil)
    }

    // MARK: Reading

    /// The weight: the dumbbell weight, or the added weight on bodyweight reps (nil for none). Nil for duration.
    var weight: Double? {
        switch self {
        case .weightReps(let weight, _): weight
        case .bodyweightReps(let addedWeight, _): addedWeight
        case .duration: nil
        }
    }

    /// The reps; nil for none, and always nil for duration.
    var reps: Int? {
        switch self {
        case .weightReps(_, let reps), .bodyweightReps(_, let reps): reps
        case .duration: nil
        }
    }

    /// The seconds; nil for none, and always nil for the rep types.
    var seconds: Int? {
        if case .duration(let seconds) = self { seconds } else { nil }
    }

    /// Whether the weight is added to bodyweight, so its control starts at "BW".
    var weightIsAdded: Bool {
        if case .bodyweightReps = self { true } else { false }
    }

    /// A set can be checked off only once it has reps, or seconds for a duration exercise.
    var canCheckOff: Bool {
        switch self {
        case .weightReps, .bodyweightReps: (reps ?? 0) > 0
        case .duration(let seconds): (seconds ?? 0) > 0
        }
    }

    /// Whether the field the user fills in is empty: reps, or seconds for a duration exercise.
    var isFieldEmpty: Bool {
        switch self {
        case .weightReps, .bodyweightReps: reps == nil
        case .duration(let seconds): seconds == nil
        }
    }

    // MARK: Changing

    /// These values with the new weight, or nil when this type can't hold it: a weight × reps set needs a
    /// weight, a duration set has none, and the weight must be a PowerBlock setting (bodyweight may also have
    /// none, "BW").
    func settingWeight(_ newWeight: Double?) -> SetValues? {
        if let newWeight, PowerBlockTable.setup(for: newWeight) == nil { return nil }
        switch self {
        case .weightReps(_, let reps):
            guard let newWeight else { return nil }
            return .weightReps(weight: newWeight, reps: reps)
        case .bodyweightReps(_, let reps):
            return .bodyweightReps(addedWeight: newWeight, reps: reps)
        case .duration: return nil
        }
    }

    // MARK: Text

    /// The value beside a set: "35 lb × 10", "BW × 12", "+10 lb × 8" or "45 s"; "—" for a missing value.
    var text: String {
        switch self {
        case .weightReps(let weight, _): "\(weight.formatted()) lb × \(repsText)"
        case .bodyweightReps(let addedWeight, _):
            "\(AddedWeight.label(for: addedWeight)) × \(repsText)"
        case .duration(let seconds): "\(seconds.map(String.init) ?? "—") s"
        }
    }

    /// The value read aloud: "35 pounds times 10", "bodyweight times 12", "10 pounds added times 8" or
    /// "45 seconds".
    var spokenText: String {
        switch self {
        case .weightReps(let weight, _): "\(weight.formatted()) pounds times \(repsText)"
        case .bodyweightReps(let addedWeight, _):
            "\(addedWeight.map { "\($0.formatted()) pounds added" } ?? "bodyweight") times \(repsText)"
        case .duration(let seconds): "\(seconds.map(String.init) ?? "—") seconds"
        }
    }

    /// The weight as a note writes it: "35 lb" or "+10 lb"; nil without a weight.
    var weightLabel: String? {
        switch self {
        case .weightReps(let weight, _): "\(weight.formatted()) lb"
        case .bodyweightReps(let addedWeight, _): addedWeight.map { AddedWeight.label(for: $0) }
        case .duration: nil
        }
    }

    private var repsText: String {
        reps.map(String.init) ?? "—"
    }
}

@MainActor
extension WorkoutSet {
    /// The set's values, read from its stored weight, reps and seconds by its exercise's type (weight × reps
    /// when the exercise is gone). Setting it writes the case's values back and clears the stored fields the
    /// type doesn't record; the caller saves.
    var values: SetValues {
        get {
            SetValues(
                kind: workoutExercise?.exercise?.kind ?? .weightReps, weight: weight, reps: reps,
                seconds: durationSeconds)
        }
        set {
            weight = newValue.weight
            reps = newValue.reps
            durationSeconds = newValue.seconds
        }
    }
}
