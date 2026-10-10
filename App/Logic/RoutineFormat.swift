import Foundation

/// How a routine plays: Sets (sets checked off in the workout screen), a Timed AMRAP with its time cap, or
/// Stretch (holds in the guided player). The time cap lives inside its case, so a cap on another format, or a
/// Timed AMRAP without one, can't be written. Read once from a routine's stored fields (`Routine.format`) and
/// written back through the same property, so no other code decides from the raw fields.
@MainActor
enum RoutineFormat: Equatable {
    case sets
    case timedAMRAP(timeCapSeconds: Int)
    case stretch

    /// The three formats without their values, for the editor's choice. A stored format writes the raw value of
    /// Timed AMRAP or Stretch, and nothing for Sets.
    enum Kind: String, CaseIterable, Identifiable {
        case sets, timedAMRAP, stretch

        nonisolated var id: Self { self }

        var title: String {
            switch self {
            case .sets: "Sets"
            case .timedAMRAP: "Timed AMRAP"
            case .stretch: "Stretch"
            }
        }
    }

    /// The minutes a time cap can take, in whole minutes.
    static let timeCapMinuteBounds = 1...60
    /// The time cap a routine switched to Timed AMRAP starts with.
    static let defaultTimeCapMinutes = 20

    /// Reads the stored fields; nil for an unknown raw value (including "sets", which is stored as nil), a time cap
    /// on a format other than Timed AMRAP, or a Timed AMRAP without a time cap of whole minutes within
    /// `timeCapMinuteBounds`. Import checks a stored routine with it.
    init?(rawValue: String?, timeCapSeconds: Int?) {
        guard let rawValue else {
            guard timeCapSeconds == nil else { return nil }
            self = .sets
            return
        }
        switch (Kind(rawValue: rawValue), timeCapSeconds) {
        case (.stretch, nil): self = .stretch
        case (.timedAMRAP, let seconds?)
        where seconds % 60 == 0 && Self.timeCapMinuteBounds.contains(seconds / 60):
            self = .timedAMRAP(timeCapSeconds: seconds)
        default: return nil
        }
    }

    /// A Timed AMRAP of the minutes, held within `timeCapMinuteBounds`.
    static func timedAMRAP(minutes: Int) -> RoutineFormat {
        let bounds = timeCapMinuteBounds
        return .timedAMRAP(
            timeCapSeconds: min(max(minutes, bounds.lowerBound), bounds.upperBound) * 60)
    }

    // MARK: Reading

    var kind: Kind {
        switch self {
        case .sets: .sets
        case .timedAMRAP: .timedAMRAP
        case .stretch: .stretch
        }
    }

    /// The raw value the routine stores: nil for Sets.
    var rawValue: String? { self == .sets ? nil : kind.rawValue }

    /// The time cap in seconds; nil for a format other than Timed AMRAP.
    var timeCapSeconds: Int? {
        if case .timedAMRAP(let seconds) = self { seconds } else { nil }
    }

    /// The time cap in whole minutes; nil for a format other than Timed AMRAP.
    var timeCapMinutes: Int? { timeCapSeconds.map { $0 / 60 } }

    /// Whether a routine of this format can hold an exercise of the type: a Timed AMRAP takes only rep exercises
    /// (weight × reps or bodyweight reps), a Stretch routine only duration exercises, and Sets any.
    func allows(_ type: ExerciseType) -> Bool {
        switch self {
        case .sets: true
        case .timedAMRAP: type != .duration
        case .stretch: type == .duration
        }
    }

    /// The exercise types the format allows, in `ExerciseType` order, for the exercise picker.
    var allowedTypes: [ExerciseType] { ExerciseType.allCases.filter(allows) }

    /// The format's line under the routine's name: "Timed AMRAP · 20 min" or "Stretch"; nil for Sets.
    var summary: String? {
        switch self {
        case .sets: nil
        case .timedAMRAP: "Timed AMRAP · \(timeCapMinutes ?? 0) min"
        case .stretch: "Stretch"
        }
    }

    /// The summary read aloud: "Timed AMRAP, 20 minutes" or "Stretch"; nil for Sets.
    var spokenSummary: String? {
        switch self {
        case .sets: return nil
        case .timedAMRAP:
            let minutes = timeCapMinutes ?? 0
            return "Timed AMRAP, \(minutes) \(minutes == 1 ? "minute" : "minutes")"
        case .stretch: return "Stretch"
        }
    }
}

@MainActor
extension Routine {
    /// The routine's format, read from its stored raw value and time cap. Stored fields that don't read as a format
    /// read as Sets: only a bug could write them, since import refuses them. Setting it writes both fields. The
    /// caller saves.
    var format: RoutineFormat {
        get { RoutineFormat(rawValue: formatRawValue, timeCapSeconds: timeCapSeconds) ?? .sets }
        set {
            formatRawValue = newValue.rawValue
            timeCapSeconds = newValue.timeCapSeconds
        }
    }
}
