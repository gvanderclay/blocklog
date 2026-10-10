import Foundation

/// A bundled routine from `starter-routines.json`, read-only: one of a starter programme's routines, a
/// standalone one, or a stretch routine. A routine of sets starts a workout or seeds a routine through
/// `StarterLibrary`; a stretch routine plays in the guided player.
@MainActor
struct StarterRoutine: Decodable, Identifiable {
    /// The time a set takes besides its rest, for the estimate.
    static let secondsPerSet = 40
    /// The lead-in before each hold of a stretch routine, for the estimate.
    static let leadInSeconds = 10

    /// How the starter routine plays. The file writes "stretch" for a stretch routine and nothing for a routine of
    /// sets.
    enum Format: String, Decodable {
        case stretch
    }

    /// One exercise of the starter routine, named as in `starter-exercises.json`, with a target: a rep range or a
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

        /// Whether the starter exercise is done on each side, as a stretch held on each side is.
        var isPerSide: Bool { StarterExercises.perSideNames.contains(exercise) }

        /// A stretch's hold: "30 s", or "30 s per side" for a per-side stretch.
        var holdSummary: String {
            "\(target?.seconds ?? 0) s\(isPerSide ? " per side" : "")"
        }

        /// The hold read aloud: "30 seconds", or "30 seconds per side".
        var spokenHoldSummary: String {
            "\(target?.seconds ?? 0) seconds\(isPerSide ? " per side" : "")"
        }
    }

    let name: String
    /// The starter programme the routine belongs to, such as "Upper/Lower"; nil for a standalone routine.
    let programme: String?
    /// Why the starter routine is built the way it is, in one line.
    let why: String
    /// Nil for a routine of sets.
    let format: Format?
    let exercises: [Entry]

    nonisolated var id: String { name }

    /// The starter routines in `starter-routines.json`, or none when it can't be read (a unit test checks that it can).
    static let bundled: [StarterRoutine] = (try? load()) ?? []

    /// Reads `starter-routines.json` from the app bundle.
    static func load() throws -> [StarterRoutine] {
        guard let url = Bundle.main.url(forResource: "starter-routines", withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([StarterRoutine].self, from: Data(contentsOf: url))
    }

    /// The programmes, in the order their first routine appears.
    static func programmes(in starterRoutines: [StarterRoutine]) -> [StarterProgramme] {
        var names: [String] = []
        for case let name? in starterRoutines.map(\.programme) where !names.contains(name) {
            names.append(name)
        }
        return names.map { name in
            StarterProgramme(name: name, routines: starterRoutines.filter { $0.programme == name })
        }
    }

    /// The standalone routines of sets, in file order.
    static func standalone(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        starterRoutines.filter { $0.programme == nil && $0.format == nil }
    }

    /// The stretch routines, in file order.
    static func stretching(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        starterRoutines.filter { $0.format == .stretch }
    }

    /// The routines of sets, which can be copied into My Routines or a programme, in file order. Stretch routines
    /// can't be copied yet.
    static func copyable(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        starterRoutines.filter { $0.format == nil }
    }

    /// What an empty routine list suggests: the first routine of the first two programmes.
    static func suggestions(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        programmes(in: starterRoutines).prefix(2).compactMap(\.routines.first)
    }

    /// The programme the starter routine belongs to, or nil for a standalone one.
    static func programme(of starterRoutine: StarterRoutine, in starterRoutines: [StarterRoutine])
        -> StarterProgramme?
    {
        programmes(in: starterRoutines).first { $0.name == starterRoutine.programme }
    }

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    /// One round of a stretch routine: each hold, twice for a per-side stretch, with a lead-in before each. Pauses
    /// between sides aren't counted.
    var stretchRoundSeconds: Int {
        exercises.reduce(0) { total, entry in
            total + (entry.isPerSide ? 2 : 1) * ((entry.target?.seconds ?? 0) + Self.leadInSeconds)
        }
    }

    /// Rounded to the nearest minute: one round of a stretch routine, which takes no rest; otherwise every set
    /// takes its rest plus `secondsPerSet`.
    func estimatedMinutes(restSeconds: Int) -> Int {
        let seconds =
            format == .stretch
            ? stretchRoundSeconds : setCount * (restSeconds + Self.secondsPerSet)
        return Int((Double(seconds) / 60).rounded())
    }

    /// "7 exercises · about 39 min", or "7 stretches · about 6 min" for a stretch routine.
    func summary(restSeconds: Int) -> String {
        let (one, many) = format == .stretch ? ("stretch", "stretches") : ("exercise", "exercises")
        let count = exercises.count == 1 ? "1 \(one)" : "\(exercises.count) \(many)"
        return "\(count) · about \(estimatedMinutes(restSeconds: restSeconds)) min"
    }
}

/// The routines of one starter programme, in file order.
@MainActor
struct StarterProgramme: Identifiable {
    let name: String
    let routines: [StarterRoutine]

    nonisolated var id: String { name }
}
