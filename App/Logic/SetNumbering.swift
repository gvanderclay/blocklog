import Foundation

/// Numbers and labels sets by type: counted sets (every set except a warm-up) are numbered 1, 2, 3…
/// in order, and warm-ups don't advance the count.
@MainActor
enum SetNumbering {
    /// Whether a set of this type is a counted set: every type except a warm-up.
    static func isCounted(_ type: SetType) -> Bool {
        type != .warmUp
    }

    /// Whether a set of this type is a progression set: normal or failure. Progression counts only these.
    static func isProgressionSet(_ type: SetType) -> Bool {
        type == .normal || type == .failure
    }

    /// The counted number of each set, or nil for a warm-up.
    static func countedNumbers(for types: [SetType]) -> [Int?] {
        var count = 0
        return types.map { type in
            guard isCounted(type) else { return nil }
            count += 1
            return count
        }
    }

    /// The label of each set: "W", "D" or "F" for warm-up, drop and failure sets, else its counted number.
    static func labels(for types: [SetType]) -> [String] {
        zip(types, countedNumbers(for: types)).map { type, number in
            switch type {
            case .warmUp: "W"
            case .drop: "D"
            case .failure: "F"
            case .normal: number.map(String.init) ?? ""
            }
        }
    }

    /// The set's counted number among its workout exercise's sets in position order; nil for a warm-up.
    static func countedNumber(of set: WorkoutSet) -> Int? {
        guard let index = index(of: set) else { return 1 }
        return countedNumbers(for: types(of: set))[index]
    }

    /// The set's label among its workout exercise's sets in position order.
    static func label(of set: WorkoutSet) -> String {
        guard let index = index(of: set) else { return "1" }
        return labels(for: types(of: set))[index]
    }

    private static func types(of set: WorkoutSet) -> [SetType] {
        set.workoutExercise.map(WorkoutLog.orderedSets(of:))?.map(\.setType) ?? []
    }

    private static func index(of set: WorkoutSet) -> Int? {
        set.workoutExercise.flatMap { WorkoutLog.orderedSets(of: $0).firstIndex { $0 === set } }
    }
}
