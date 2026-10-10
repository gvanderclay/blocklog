import Foundation

/// A bundled routine from `starter-routines.json`, read-only: one of a starter programme's routines, a
/// standalone one, or a stretch routine. It starts a workout, plays in the guided player or seeds a routine through
/// `StarterLibrary`, by its format.
@MainActor
struct StarterRoutine: @MainActor Decodable, Identifiable {
    /// The time a set takes besides its rest, for the estimate.
    static let secondsPerSet = 40
    /// The lead-in before each hold of a stretch routine, for the estimate.
    static let leadInSeconds = 10

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
    /// The file writes it as a routine stores it: `format` ("timedAMRAP" or "stretch", nothing for Sets) and, for
    /// a Timed AMRAP, `timeCapSeconds`. Decoding fails for one that doesn't read as a `RoutineFormat`.
    let format: RoutineFormat
    let exercises: [Entry]

    private enum CodingKeys: String, CodingKey {
        case name, programme, why, format, timeCapSeconds, exercises
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        programme = try container.decodeIfPresent(String.self, forKey: .programme)
        why = try container.decode(String.self, forKey: .why)
        guard
            let format = RoutineFormat(
                rawValue: try container.decodeIfPresent(String.self, forKey: .format),
                timeCapSeconds: try container.decodeIfPresent(Int.self, forKey: .timeCapSeconds))
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .format, in: container,
                debugDescription:
                    "A format is nothing, \"stretch\" or \"timedAMRAP\" with a time cap of 1 to 60 whole minutes."
            )
        }
        self.format = format
        exercises = try container.decode([Entry].self, forKey: .exercises)
    }

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

    /// The standalone routines that aren't stretch routines, such as Golden Six and Cindy, in file order.
    static func standalone(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        starterRoutines.filter { $0.programme == nil && $0.format != .stretch }
    }

    /// The stretch routines, in file order.
    static func stretching(in starterRoutines: [StarterRoutine]) -> [StarterRoutine] {
        starterRoutines.filter { $0.format == .stretch }
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

    /// Rounded to the nearest minute: one round of a stretch routine, which takes no rest; a Timed AMRAP's time
    /// cap; otherwise every set takes its rest plus `secondsPerSet`.
    func estimatedMinutes(restSeconds: Int) -> Int {
        let seconds =
            switch format {
            case .sets: setCount * (restSeconds + Self.secondsPerSet)
            case .timedAMRAP(let timeCapSeconds): timeCapSeconds
            case .stretch: stretchRoundSeconds
            }
        return Int((Double(seconds) / 60).rounded())
    }

    /// "7 exercises · about 39 min", "7 stretches · about 6 min" for a stretch routine, or "3 exercises · Timed
    /// AMRAP · 20 min".
    func summary(restSeconds: Int) -> String {
        let (one, many) = format == .stretch ? ("stretch", "stretches") : ("exercise", "exercises")
        let count = exercises.count == 1 ? "1 \(one)" : "\(exercises.count) \(many)"
        if case .timedAMRAP = format, let summary = format.summary {
            return "\(count) · \(summary)"
        }
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
