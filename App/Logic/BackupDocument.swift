import Foundation

/// Why a backup couldn't be read or restored. Its description is the message Import shows.
/// Not @MainActor: `Error` and `LocalizedError` are nonisolated requirements, and the cases are plain values.
enum BackupError: LocalizedError, Equatable {
    /// The file isn't a backup document, or couldn't be read.
    case unreadable(String)
    case unsupportedVersion(Int)
    /// The document decoded but breaks a rule; the text names the first problem.
    case invalid(String)
    /// Restoring would delete a workout the user is logging.
    case workoutInProgress

    var errorDescription: String? {
        switch self {
        case .unreadable(let detail): detail
        case .unsupportedVersion(let version):
            "This backup is version \(version); this app reads only version \(BackupDocument.currentVersion), so older backups can't be imported."
        case .invalid(let detail): detail
        case .workoutInProgress: "Finish or discard your workout in progress first."
        }
    }
}

/// The versioned JSON file Export writes and Import reads: plain `Codable` records, not the stored models.
/// Enum values are raw strings, so a file with an unknown value decodes and is rejected by `validate()`
/// with a message naming it. Records refer to each other by `id`.
@MainActor
struct BackupDocument: Codable, Equatable {
    nonisolated static let currentVersion = 2
    /// The largest rep range value a routine exercise may have.
    static let maxRepRange = 50

    var version: Int
    var exportedAt: Date
    var exercises: [ExerciseRecord]
    /// Absent from files written before programmes, which read as none.
    var programmes: [ProgrammeRecord]
    var routines: [RoutineRecord]
    var workouts: [WorkoutRecord]

    @MainActor
    struct ExerciseRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var muscleGroup: String
        var equipment: String
        var type: String
        var restOverrideSeconds: Int?
        var isCustom: Bool
    }

    @MainActor
    struct ProgrammeRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var creationDate: Date
    }

    @MainActor
    struct RoutineRecord: Codable, Equatable {
        var id: UUID
        var name: String
        var creationDate: Date
        /// The programme the routine belongs to, with `programmePosition`; both nil for My Routines.
        var programmeID: UUID?
        var programmePosition: Int?
        var exercises: [RoutineExerciseRecord]
    }

    @MainActor
    struct RoutineExerciseRecord: Codable, Equatable {
        var id: UUID
        var exerciseID: UUID
        var position: Int
        var plannedSetTypes: [String]
        var repRangeLow: Int?
        var repRangeHigh: Int?
        var targetDurationSeconds: Int?
    }

    @MainActor
    struct WorkoutRecord: Codable, Equatable {
        var id: UUID
        var title: String
        var startDate: Date
        /// Nil for an unfinished workout, which `validate()` rejects.
        var endDate: Date?
        /// The routine the workout started from; nil for a freeform workout.
        var routineID: UUID?
        var exercises: [WorkoutExerciseRecord]
    }

    @MainActor
    struct WorkoutExerciseRecord: Codable, Equatable {
        var id: UUID
        var exerciseID: UUID
        var position: Int
        var sets: [SetRecord]
    }

    @MainActor
    struct SetRecord: Codable, Equatable {
        var id: UUID
        var position: Int
        var setType: String
        var weight: Double?
        var reps: Int?
        var durationSeconds: Int?
        var isCompleted: Bool
    }

    // MARK: Reading and writing JSON

    /// Dates are ISO 8601 with fractional seconds, so a restored date is exact to the millisecond.
    /// Nonisolated, with `text(for:)`, because the JSON coders' date closures run off the main actor; the
    /// format style is an immutable `Sendable` value.
    private nonisolated static let fractionalDates = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true)

    /// The file's text for a date: the date rounded to the millisecond. The format style truncates, so the
    /// rounded value is nudged half a millisecond up; otherwise a parsed .135 stored a hair under .135 would
    /// print as .134, and every export and import would lose a millisecond.
    private nonisolated static func text(for date: Date) -> String {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        return Date(timeIntervalSince1970: (milliseconds + 0.5) / 1000).formatted(fractionalDates)
    }

    /// A date as the file stores it: rounded to the millisecond, so the same date comes back from a restore.
    static func fileDate(_ date: Date) -> Date {
        (try? Date(text(for: date), strategy: fractionalDates)) ?? date
    }

    /// The pretty-printed JSON with sorted keys.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.text(for: date))
        }
        return try encoder.encode(self)
    }

    /// Decodes the whole file without validating its values. Throws `BackupError.unsupportedVersion` for a
    /// file of another version and `BackupError.unreadable` when the file isn't a backup document.
    static func decode(_ data: Data) throws -> BackupDocument {
        struct Header: Decodable { let version: Int }
        do {
            let version = try JSONDecoder().decode(Header.self, from: data).version
            guard version == currentVersion else { throw BackupError.unsupportedVersion(version) }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let text = try decoder.singleValueContainer().decode(String.self)
                if let date = try? Date(text, strategy: fractionalDates) { return date }
                if let date = try? Date(text, strategy: .iso8601) { return date }
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath, debugDescription: "“\(text)” is not a date."
                    ))
            }
            return try decoder.decode(BackupDocument.self, from: data)
        } catch let error as BackupError {
            throw error
        } catch let error as DecodingError {
            throw BackupError.unreadable(Self.describe(error))
        } catch {
            throw BackupError.unreadable("The file isn’t valid JSON.")
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        let context: DecodingError.Context
        switch error {
        case .typeMismatch(_, let found), .valueNotFound(_, let found), .dataCorrupted(let found):
            context = found
        case .keyNotFound(let key, let found):
            context = .init(
                codingPath: found.codingPath + [key], debugDescription: "A value is missing.")
        @unknown default:
            return "The file isn’t a Blocklog backup."
        }
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty
            ? "The file isn’t a Blocklog backup."
            : "The file isn’t a Blocklog backup (\(path): \(context.debugDescription))"
    }

    /// Decodes the whole file, then validates the whole document. Nothing is stored.
    static func read(_ data: Data) throws -> BackupDocument {
        let document = try decode(data)
        try document.validate()
        return document
    }

    // MARK: Validation

    /// Throws `BackupError` naming the first problem. Nothing is stored from a document that fails.
    func validate() throws {
        guard version == Self.currentVersion else { throw BackupError.unsupportedVersion(version) }
        // A store always holds at least one exercise; an empty one would be re-seeded with the starters at launch.
        guard !exercises.isEmpty else { throw BackupError.invalid("The backup has no exercises.") }
        var ids = Set<UUID>()
        func claim(_ id: UUID, for owner: String) throws {
            guard ids.insert(id).inserted else {
                throw BackupError.invalid("\(owner) has an ID that is used more than once.")
            }
        }
        func requireKnown<T: RawRepresentable>(
            _: T.Type, _ raw: String, _ what: String, _ owner: String
        )
            throws where T.RawValue == String
        {
            guard T(rawValue: raw) != nil else {
                throw BackupError.invalid("\(owner) has an unknown \(what), “\(raw)”.")
            }
        }
        func requireUniquePositions(_ positions: [Int], in owner: String) throws {
            guard Set(positions).count == positions.count else {
                throw BackupError.invalid("\(owner) has two entries with the same position.")
            }
        }

        var types: [UUID: ExerciseType] = [:]
        var names = Set<String>()
        for exercise in exercises {
            let owner = "Exercise “\(exercise.name)”"
            try claim(exercise.id, for: owner)
            let name = ExerciseCatalog.normalized(exercise.name)
            guard !name.trimmed.isEmpty else {
                throw BackupError.invalid("An exercise has no name.")
            }
            guard names.insert(name.key).inserted else {
                throw BackupError.invalid(
                    "Two exercises are named “\(name.trimmed)”, ignoring case.")
            }
            try requireKnown(MuscleGroup.self, exercise.muscleGroup, "muscle group", owner)
            try requireKnown(Equipment.self, exercise.equipment, "equipment", owner)
            try requireKnown(ExerciseType.self, exercise.type, "type", owner)
            if let rest = exercise.restOverrideSeconds,
                rest <= 0 || rest > (RestTimer.choices.last ?? 0)
            {
                throw BackupError.invalid("\(owner) has a rest time of \(rest) seconds.")
            }
            types[exercise.id] = ExerciseType(rawValue: exercise.type)
        }

        var programmePositions: [UUID: [Int]] = [:]
        for programme in programmes {
            try claim(programme.id, for: "Programme “\(programme.name)”")
            guard !ExerciseCatalog.normalized(programme.name).trimmed.isEmpty else {
                throw BackupError.invalid("A programme has no name.")
            }
            programmePositions[programme.id] = []
        }

        for routine in routines {
            let owner = "Routine “\(routine.name)”"
            try claim(routine.id, for: owner)
            switch (routine.programmeID, routine.programmePosition) {
            case (nil, nil): break
            case (let programmeID?, let position?):
                guard programmePositions[programmeID] != nil else {
                    throw BackupError.invalid(
                        "\(owner) belongs to a programme that is not in the file.")
                }
                programmePositions[programmeID, default: []].append(position)
            case (_?, nil):
                throw BackupError.invalid("\(owner) has a programme but no position in it.")
            case (nil, _?):
                throw BackupError.invalid("\(owner) has a programme position but no programme.")
            }
            try requireUniquePositions(routine.exercises.map(\.position), in: owner)
            for entry in routine.exercises {
                try claim(entry.id, for: owner)
                guard let type = types[entry.exerciseID] else {
                    throw BackupError.invalid("\(owner) uses an exercise that is not in the file.")
                }
                for type in entry.plannedSetTypes {
                    try requireKnown(SetType.self, type, "set type", owner)
                }
                switch (entry.repRangeLow, entry.repRangeHigh) {
                case (nil, nil): break
                case (let low?, let high?):
                    guard RoutineTarget(validRepRangeLow: low, high: high) != nil else {
                        throw BackupError.invalid(
                            "\(owner) has the rep range \(low)–\(high); it must be 1 to \(Self.maxRepRange) with the low end first."
                        )
                    }
                default:
                    throw BackupError.invalid("\(owner) has only one end of a rep range.")
                }
                if let seconds = entry.targetDurationSeconds,
                    RoutineTarget(validDurationSeconds: seconds) == nil
                {
                    throw BackupError.invalid(
                        "\(owner) has a target duration of \(seconds) seconds.")
                }
                // The stored fields must read as the exercise type's target, so a rep range on a timed exercise
                // (or a duration on a rep exercise) is refused rather than imported as a mix.
                let target = RoutineTarget(
                    type: type, repRangeLow: entry.repRangeLow, repRangeHigh: entry.repRangeHigh,
                    durationSeconds: entry.targetDurationSeconds)
                if entry.repRangeLow != nil, target?.repRange == nil {
                    throw BackupError.invalid("\(owner) has a rep range for a duration exercise.")
                }
                if entry.targetDurationSeconds != nil, target?.seconds == nil {
                    throw BackupError.invalid("\(owner) has a target duration for a rep exercise.")
                }
            }
        }

        for programme in programmes
        where !ProgrammeMembership.areValid(programmePositions[programme.id] ?? []) {
            throw BackupError.invalid(
                "Programme “\(programme.name)” has routine positions that aren’t 0 to one less than its number of routines."
            )
        }

        let routineIDs = Set(routines.map(\.id))
        for workout in workouts {
            let owner = "Workout “\(workout.title)”"
            try claim(workout.id, for: owner)
            guard let end = workout.endDate else {
                throw BackupError.invalid("\(owner) is not finished.")
            }
            guard end >= workout.startDate else {
                throw BackupError.invalid("\(owner) ends before it starts.")
            }
            if let routineID = workout.routineID, !routineIDs.contains(routineID) {
                throw BackupError.invalid(
                    "\(owner) started from a routine that is not in the file.")
            }
            try requireUniquePositions(workout.exercises.map(\.position), in: owner)
            for entry in workout.exercises {
                try claim(entry.id, for: owner)
                guard let type = types[entry.exerciseID] else {
                    throw BackupError.invalid("\(owner) uses an exercise that is not in the file.")
                }
                try requireUniquePositions(entry.sets.map(\.position), in: owner)
                for set in entry.sets {
                    try claim(set.id, for: owner)
                    try requireKnown(SetType.self, set.setType, "set type", owner)
                    try Self.validate(set, of: type, in: owner)
                }
            }
        }
    }

    /// A set must be completed and have exactly the fields its exercise type records.
    private static func validate(_ set: SetRecord, of type: ExerciseType, in owner: String) throws {
        func problem(_ text: String) -> BackupError { .invalid("\(owner) has a set \(text).") }
        guard set.isCompleted else { throw problem("that is not completed") }
        if let weight = set.weight, PowerBlockTable.setup(for: weight) == nil {
            throw problem(
                "with a weight of \(weight.formatted()) lb, which is not a PowerBlock setting")
        }
        guard
            SetValues(
                complete: type, weight: set.weight, reps: set.reps, seconds: set.durationSeconds)
                != nil
        else { throw problem(SetValues.requirement(of: type)) }
    }
}

extension BackupDocument {
    /// Reads `programmes` as empty when the key is absent; every other key is required.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        exercises = try container.decode([ExerciseRecord].self, forKey: .exercises)
        programmes =
            try container.decodeIfPresent([ProgrammeRecord].self, forKey: .programmes) ?? []
        routines = try container.decode([RoutineRecord].self, forKey: .routines)
        workouts = try container.decode([WorkoutRecord].self, forKey: .workouts)
    }
}
