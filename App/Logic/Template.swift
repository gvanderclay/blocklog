import Foundation

/// A bundled plan from `templates.json`, read-only: a programme session or a one-off workout. It starts a
/// workout or seeds a routine through `TemplateLibrary`.
@MainActor
struct Template: Decodable, Identifiable {
    /// The time a set takes besides its rest, for the estimate.
    static let secondsPerSet = 40

    enum Kind: String, Decodable {
        /// A session of a programme, meant to be kept as a routine.
        case routine
        /// A workout that stands on its own.
        case oneOff
    }

    /// One exercise of the template, named as in `starter-exercises.json`, with a target: a rep range or a
    /// target duration.
    @MainActor
    struct Entry: @MainActor Decodable {
        let exercise: String
        let sets: [SetType]
        /// Nil when the entry gives neither. The file writes the range as `repRange`, two numbers (low, high);
        /// decoding fails for one that isn't, or for an entry with both a range and a duration.
        let target: RoutineTarget?

        private enum CodingKeys: String, CodingKey {
            case exercise, sets, repRange, targetDurationSeconds
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exercise = try container.decode(String.self, forKey: .exercise)
            sets = try container.decode([SetType].self, forKey: .sets)
            let ends = try container.decodeIfPresent([Int].self, forKey: .repRange)
            let seconds = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds)
            switch (ends, seconds) {
            case (nil, nil): target = nil
            case (let ends?, nil):
                guard ends.count == 2,
                    let range = RoutineTarget(validRepRangeLow: ends[0], high: ends[1])
                else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .repRange, in: container,
                        debugDescription: "A rep range is two numbers, low then high, from 1 to 50."
                    )
                }
                target = range
            case (nil, let seconds?):
                guard let duration = RoutineTarget(validDurationSeconds: seconds) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .targetDurationSeconds, in: container,
                        debugDescription: "A target duration is above 0 seconds.")
                }
                target = duration
            case (.some, .some):
                throw DecodingError.dataCorruptedError(
                    forKey: .repRange, in: container,
                    debugDescription: "An entry has a rep range or a target duration, not both.")
            }
        }
    }

    /// The sessions of one programme, in file order.
    @MainActor
    struct Programme: Identifiable {
        let name: String
        let sessions: [Template]

        nonisolated var id: String { name }
    }

    let name: String
    let kind: Kind
    /// The programme the session belongs to, such as "Upper/Lower"; nil for a one-off.
    let programme: String?
    /// Why the template is built the way it is, in one line.
    let why: String
    let exercises: [Entry]

    nonisolated var id: String { name }

    /// The templates in `templates.json`, or none when it can't be read (a unit test checks that it can).
    static let bundled: [Template] = (try? load()) ?? []

    /// Reads `templates.json` from the app bundle.
    static func load() throws -> [Template] {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Template].self, from: Data(contentsOf: url))
    }

    /// The programmes, in the order their first session appears.
    static func programmes(in templates: [Template]) -> [Programme] {
        var names: [String] = []
        for case let name? in templates.map(\.programme) where !names.contains(name) {
            names.append(name)
        }
        return names.map { name in
            Programme(name: name, sessions: templates.filter { $0.programme == name })
        }
    }

    /// The one-off workouts, in file order.
    static func oneOffs(in templates: [Template]) -> [Template] {
        templates.filter { $0.kind == .oneOff }
    }

    /// What an empty routine list suggests: the first session of the first two programmes.
    static func suggestions(in templates: [Template]) -> [Template] {
        programmes(in: templates).prefix(2).compactMap(\.sessions.first)
    }

    /// The programme the template is a session of, or nil for a one-off.
    static func programme(of template: Template, in templates: [Template]) -> Programme? {
        programmes(in: templates).first { $0.name == template.programme }
    }

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    /// Every set takes its rest plus `secondsPerSet`, rounded to the nearest minute.
    func estimatedMinutes(restSeconds: Int) -> Int {
        Int((Double(setCount * (restSeconds + Self.secondsPerSet)) / 60).rounded())
    }

    /// "7 exercises · about 39 min".
    func summary(restSeconds: Int) -> String {
        let count = exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises"
        return "\(count) · about \(estimatedMinutes(restSeconds: restSeconds)) min"
    }
}
