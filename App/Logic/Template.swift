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

    /// One exercise of the template, named as in `starter-exercises.json`, with a rep range or a target duration.
    @MainActor
    struct Entry: Decodable {
        let exercise: String
        let sets: [SetType]
        /// Low and high.
        let repRange: [Int]?
        let targetDurationSeconds: Int?

        var repLow: Int? { repRange?.first }
        var repHigh: Int? { repRange?.last }
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
