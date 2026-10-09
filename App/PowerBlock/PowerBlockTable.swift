/// The PowerBlock settings the user's Elite EXP makes with Stage 2 and Stage 3 installed: 27 weights from 5 to 90 lb per dumbbell.
///
/// Each printed slot number is the slot's total with both adders installed, so slot 30 with no adders is 25 lb.
@MainActor
enum PowerBlockTable {
    /// Where the magnetic pin sits.
    @MainActor
    enum Location: Equatable {
        /// The pin is in no slot, so only the handle is lifted.
        case handleOnly
        /// The top plate slot, which has no printed number.
        case firstSlot
        /// A plate slot by its printed number, 30 to 90.
        case slot(Int)

        /// The name used after "Pin" or after an arrow, such as "first slot" or "30".
        var slotName: String {
            switch self {
            case .handleOnly: "handle only"
            case .firstSlot: "first slot"
            case .slot(let number): "\(number)"
            }
        }

        /// The location as setup text, such as "Handle only", "Pin first slot" or "Pin 30".
        var setupText: String {
            self == .handleOnly ? "Handle only" : "Pin \(slotName)"
        }

        /// The printed label beside the location in the diagram: "Handle", a slot number, or nil for the unnumbered first slot.
        var label: String? {
            switch self {
            case .handleOnly: "Handle"
            case .firstSlot: nil
            case .slot(let number): "\(number)"
            }
        }
    }

    /// What the diagram draws for one setting.
    @MainActor
    struct DiagramState: Equatable {
        /// The pin's location and its position in `locations`.
        let selected: Location
        let selectedIndex: Int
        /// False for handle-only settings, where the pin is in no slot.
        let hasPin: Bool
        /// The locations from the handle down to the selected one, drawn lifted.
        let lifted: [Location]
        /// How many adders are in the handle, 0 to 2.
        let adders: Int
    }

    /// How to set the block for one weight: where the pin goes and how many adders are in the handle.
    @MainActor
    struct Setup: Equatable {
        let location: Location
        let adders: Int

        /// The setup as one line, such as "Handle only · no adders" or "Pin 30 · 1 adder".
        var line: String {
            "\(location.setupText) · \(adders == 0 ? "no adders" : PowerBlockTable.adderPhrase(adders))"
        }
    }

    /// The block's locations from the handle down to slot 90.
    static let locations: [Location] =
        [.handleOnly, .firstSlot] + stride(from: 30, through: 90, by: 10).map { .slot($0) }

    /// Every PowerBlock setting in ascending order.
    private static let settings: [(weight: Double, setup: Setup)] = [
        (5, Setup(location: .handleOnly, adders: 0)),
        (7.5, Setup(location: .handleOnly, adders: 1)),
        (10, Setup(location: .handleOnly, adders: 2)),
        (15, Setup(location: .firstSlot, adders: 0)),
        (17.5, Setup(location: .firstSlot, adders: 1)),
        (20, Setup(location: .firstSlot, adders: 2)),
        (25, Setup(location: .slot(30), adders: 0)),
        (27.5, Setup(location: .slot(30), adders: 1)),
        (30, Setup(location: .slot(30), adders: 2)),
        (35, Setup(location: .slot(40), adders: 0)),
        (37.5, Setup(location: .slot(40), adders: 1)),
        (40, Setup(location: .slot(40), adders: 2)),
        (45, Setup(location: .slot(50), adders: 0)),
        (47.5, Setup(location: .slot(50), adders: 1)),
        (50, Setup(location: .slot(50), adders: 2)),
        (55, Setup(location: .slot(60), adders: 0)),
        (57.5, Setup(location: .slot(60), adders: 1)),
        (60, Setup(location: .slot(60), adders: 2)),
        (65, Setup(location: .slot(70), adders: 0)),
        (67.5, Setup(location: .slot(70), adders: 1)),
        (70, Setup(location: .slot(70), adders: 2)),
        (75, Setup(location: .slot(80), adders: 0)),
        (77.5, Setup(location: .slot(80), adders: 1)),
        (80, Setup(location: .slot(80), adders: 2)),
        (85, Setup(location: .slot(90), adders: 0)),
        (87.5, Setup(location: .slot(90), adders: 1)),
        (90, Setup(location: .slot(90), adders: 2)),
    ]

    /// All 27 weights in ascending order.
    static let weights: [Double] = settings.map(\.weight)

    /// The next setting above a weight. From a weight that is not a setting, this is the nearest one above it; nil at 90.
    static func next(after weight: Double) -> Double? {
        settings.first { $0.weight > weight }?.weight
    }

    /// The previous setting below a weight. From a weight that is not a setting, this is the nearest one below it; nil at 5.
    static func previous(before weight: Double) -> Double? {
        settings.last { $0.weight < weight }?.weight
    }

    /// The step up from a weight, or nil with no weight or at 90 lb; what + does on a weighted set.
    static func stepUp(from weight: Double?) -> Double? {
        weight.flatMap { next(after: $0) }
    }

    /// The step down from a weight, or nil with no weight or at 5 lb; what − does on a weighted set.
    static func stepDown(from weight: Double?) -> Double? {
        weight.flatMap { previous(before: $0) }
    }

    /// The setup for a weight, or nil when the weight is not a setting.
    static func setup(for weight: Double) -> Setup? {
        settings.first { $0.weight == weight }?.setup
    }

    /// What the diagram draws for a weight, or nil when the weight is not a setting.
    static func diagramState(for weight: Double) -> DiagramState? {
        guard let setup = setup(for: weight), let index = locations.firstIndex(of: setup.location)
        else { return nil }
        return DiagramState(
            selected: setup.location, selectedIndex: index, hasPin: setup.location != .handleOnly,
            lifted: Array(locations[...index]), adders: setup.adders)
    }

    /// The setup line for a set's weight, such as "Pin 30 · 1 adder"; nil with no weight ("BW", duration).
    static func setupLine(for weight: Double?) -> String? {
        weight.flatMap { setup(for: $0)?.line }
    }

    /// What to change on the block from one weight to another, such as "Pin 30 → 40 · remove 1 adder".
    /// Nil when the weights are equal or either is not a setting.
    static func changeLine(from start: Double, to end: Double) -> String? {
        guard start != end, let from = setup(for: start), let to = setup(for: end) else {
            return nil
        }
        var parts: [String] = []
        if from.location != to.location {
            parts.append(pinChange(from: from.location, to: to.location))
        }
        let delta = to.adders - from.adders
        if delta != 0 {
            var text = "\(delta > 0 ? "add" : "remove") \(adderPhrase(abs(delta)))"
            if parts.isEmpty {
                text = text.prefix(1).uppercased() + text.dropFirst()
            }
            parts.append(text)
        }
        return parts.joined(separator: " · ")
    }

    /// The pin part of a change line. Between two plate slots only the new slot is named after the arrow.
    private static func pinChange(from: Location, to: Location) -> String {
        if from != .handleOnly && to != .handleOnly {
            return "Pin \(from.slotName) → \(to.slotName)"
        }
        return "\(from.setupText) → \(to.setupText.lowercased())"
    }

    /// "1 adder" or "2 adders".
    private static func adderPhrase(_ count: Int) -> String {
        "\(count) adder\(count == 1 ? "" : "s")"
    }
}
