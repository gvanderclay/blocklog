import Foundation

/// Stepping the added weight of a bodyweight set: no weight ("BW"), then the PowerBlock settings.
@MainActor
enum AddedWeight {
    /// "BW" for no added weight, else "+10 lb".
    static func label(for weight: Double?) -> String {
        weight.map { "+\($0.formatted()) lb" } ?? "BW"
    }

    /// The weight menu's choices: BW, then every PowerBlock setting.
    static let options: [Double?] = [nil] + PowerBlockTable.weights

    /// The step up: 5 lb from BW, else the next PowerBlock setting. Nil at 90 lb.
    static func next(after weight: Double?) -> Double? {
        guard let weight else { return PowerBlockTable.weights[0] }
        return PowerBlockTable.next(after: weight)
    }

    /// The step down: the previous PowerBlock setting, or nil (BW) from the lowest one. Nil from BW.
    static func previous(before weight: Double?) -> Double? {
        guard let weight, weight > PowerBlockTable.weights[0] else { return nil }
        return PowerBlockTable.previous(before: weight)
    }

    /// Whether − does anything: any added weight, including 5 lb (which steps down to BW), can decrease.
    static func canDecrease(from weight: Double?) -> Bool {
        weight != nil
    }
}
