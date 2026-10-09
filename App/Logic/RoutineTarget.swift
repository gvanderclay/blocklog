import Foundation

/// What a routine exercise aims for, which depends on its exercise type: a rep range for the rep types, held
/// as a closed range so its low end never passes its high end, or a target duration for a duration exercise.
/// Read once from a routine exercise's stored fields (`RoutineExercise.target`) and written back through the
/// same property, so no other code decides which of the stored range ends and seconds apply. A routine
/// exercise that stores none has no target (nil); the editor then starts from `standard(for:)`.
@MainActor
enum RoutineTarget: Equatable {
    case repRange(ClosedRange<Int>)
    case duration(seconds: Int)

    /// The values a rep-range end can take in the editor.
    static let repBounds = 1...BackupDocument.maxRepRange
    static let defaultRepRange = 8...12
    static let defaultDurationSeconds = 30
    /// The values a target duration can take in the editor, in steps of `durationStep` seconds.
    static let durationBounds = 5...600
    static let durationStep = 5

    /// The target a new routine exercise of the type starts with: 8–12 reps, or 30 s for a duration exercise.
    static func standard(for kind: ExerciseKind) -> RoutineTarget {
        kind == .duration ? .duration(seconds: defaultDurationSeconds) : .repRange(defaultRepRange)
    }

    /// `target` when it is of the exercise type's case, otherwise the type's standard target.
    static func orStandard(_ target: RoutineTarget?, for kind: ExerciseKind) -> RoutineTarget {
        switch (target, kind) {
        case (.duration?, .duration), (.repRange?, .weightReps), (.repRange?, .bodyweightReps):
            target ?? standard(for: kind)
        default: standard(for: kind)
        }
    }

    /// Reads the stored fields as the target of an exercise type, ignoring the fields it doesn't use. Nil when
    /// they hold none: a duration exercise without seconds, or a rep exercise without both range ends or with
    /// a low end above the high end (no screen writes one). A stored value outside the editor's bounds is kept.
    /// With no exercise type (the exercise was deleted), stored seconds read as a duration and anything else
    /// as a range.
    init?(kind: ExerciseKind?, repRangeLow: Int?, repRangeHigh: Int?, durationSeconds: Int?) {
        if kind.map({ $0 == .duration }) ?? (durationSeconds != nil) {
            guard let durationSeconds else { return nil }
            self = .duration(seconds: durationSeconds)
        } else {
            guard let low = repRangeLow, let high = repRangeHigh, low <= high else { return nil }
            self = .repRange(low...high)
        }
    }

    /// A rep range inside `repBounds`, low end first; nil otherwise. Import checks a stored range with it.
    init?(validRepRangeLow low: Int, high: Int) {
        guard Self.repBounds.contains(low), Self.repBounds.contains(high), low <= high else {
            return nil
        }
        self = .repRange(low...high)
    }

    /// A target duration above 0 seconds; nil otherwise. Import checks a stored duration with it.
    init?(validDurationSeconds seconds: Int) {
        guard seconds > 0 else { return nil }
        self = .duration(seconds: seconds)
    }

    // MARK: Reading

    /// The rep range; nil for a duration.
    var repRange: ClosedRange<Int>? {
        if case .repRange(let range) = self { range } else { nil }
    }

    /// The target duration in seconds; nil for a rep range.
    var seconds: Int? {
        if case .duration(let seconds) = self { seconds } else { nil }
    }

    /// The values the low end of a range can take: from the bounds' start up to the high end, so the low end
    /// can't pass it. A stored end outside `repBounds` is kept as it is, so the bounds still contain it.
    static func lowBounds(of range: ClosedRange<Int>) -> ClosedRange<Int> {
        min(repBounds.lowerBound, range.upperBound)...range.upperBound
    }

    /// The values the high end of a range can take: from the low end up to the bounds' end.
    static func highBounds(of range: ClosedRange<Int>) -> ClosedRange<Int> {
        range.lowerBound...max(repBounds.upperBound, range.lowerBound)
    }

    // MARK: Changing

    /// A range with the new low end, held at the high end at most; a duration is unchanged.
    func settingLow(_ low: Int) -> RoutineTarget {
        guard case .repRange(let range) = self else { return self }
        return .repRange(min(low, range.upperBound)...range.upperBound)
    }

    /// A range with the new high end, held at the low end at least; a duration is unchanged.
    func settingHigh(_ high: Int) -> RoutineTarget {
        guard case .repRange(let range) = self else { return self }
        return .repRange(range.lowerBound...max(high, range.lowerBound))
    }

    /// A duration with the new seconds; a range is unchanged.
    func settingSeconds(_ seconds: Int) -> RoutineTarget {
        guard case .duration = self else { return self }
        return .duration(seconds: seconds)
    }
}

@MainActor
extension RoutineExercise {
    /// The routine exercise's target, read from its stored range and duration by its exercise's type; nil when
    /// they hold none. Setting it writes the case's values back and clears the stored fields the other case
    /// would use; nil clears both. The caller saves.
    var target: RoutineTarget? {
        get {
            RoutineTarget(
                kind: exercise?.kind, repRangeLow: repRangeLow, repRangeHigh: repRangeHigh,
                durationSeconds: targetDurationSeconds)
        }
        set {
            repRangeLow = newValue?.repRange?.lowerBound
            repRangeHigh = newValue?.repRange?.upperBound
            targetDurationSeconds = newValue?.seconds
        }
    }
}
