import Foundation
import SwiftData

/// How many of each kind of record a store or a backup document holds.
@MainActor
struct BackupCounts: Equatable {
    var workouts: Int
    var routines: Int
    var exercises: Int

    /// "3 workouts, 1 routine and 41 exercises".
    var summary: String {
        func count(_ number: Int, _ noun: String) -> String {
            "\(number) \(noun)\(number == 1 ? "" : "s")"
        }
        return
            "\(count(workouts, "workout")), \(count(routines, "routine")) and \(count(exercises, "exercise"))"
    }
}

/// Exports every exercise, routine and finished workout as a `BackupDocument`, and replaces all data with
/// a validated one.
@MainActor
struct Backup {
    let context: ModelContext

    /// "blocklog-backup-2027-03-14.json" for the date in the time zone.
    static func fileName(for date: Date, in timeZone: TimeZone = .current) -> String {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        return "blocklog-backup-\(day).json"
    }

    /// Reads a backup file: decodes the whole file, then validates it. Nothing is stored.
    static func read(contentsOf url: URL) throws -> BackupDocument {
        // Files from the file importer are outside the app's sandbox until access is requested.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.unreadable("The file couldn’t be read: \(error.localizedDescription)")
        }
        return try BackupDocument.read(data)
    }

    // MARK: Counting

    /// What is stored now: every workout, in progress or not.
    func storedCounts() throws -> BackupCounts {
        BackupCounts(
            workouts: try context.fetchCount(FetchDescriptor<Workout>()),
            routines: try context.fetchCount(FetchDescriptor<Routine>()),
            exercises: try context.fetchCount(FetchDescriptor<Exercise>()))
    }

    static func counts(of document: BackupDocument) -> BackupCounts {
        BackupCounts(
            workouts: document.workouts.count, routines: document.routines.count,
            exercises: document.exercises.count)
    }

    // MARK: Exporting

    /// Every exercise, routine and finished workout. An in-progress workout is left out. Lists are sorted
    /// and positions renumbered from 0, so exporting what an import stored gives an equal document. Throws
    /// `BackupError` when the stored data would not pass import, for example a workout that ends before it
    /// starts.
    func export(at date: Date = .now) throws -> BackupDocument {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
        let routines = try context.fetch(FetchDescriptor<Routine>())
            .sorted { ($0.creationDate, $0.id.uuidString) < ($1.creationDate, $1.id.uuidString) }
        let workouts = try context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.endDate != nil })
        )
        .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }

        let document = BackupDocument(
            version: BackupDocument.currentVersion,
            exportedAt: BackupDocument.fileDate(date),
            exercises: exercises.map { exercise in
                .init(
                    id: exercise.id, name: exercise.name, muscleGroup: exercise.muscleGroupRawValue,
                    equipment: exercise.equipmentRawValue, kind: exercise.kindRawValue,
                    restOverrideSeconds: exercise.restOverrideSeconds, isCustom: exercise.isCustom)
            },
            routines: routines.map { routine in
                .init(
                    id: routine.id, name: routine.name,
                    creationDate: BackupDocument.fileDate(routine.creationDate),
                    exercises: routine.exercises.sorted(by: \.position).compactMap { entry in
                        // ponytail: an entry whose exercise is gone can't be referenced, so it is left out.
                        guard let exercise = entry.exercise else { return nil }
                        return .init(
                            id: entry.id, exerciseID: exercise.id, position: 0,
                            plannedSetTypes: entry.plannedSetTypeRawValues,
                            repRangeLow: entry.repRangeLow, repRangeHigh: entry.repRangeHigh,
                            targetDurationSeconds: entry.targetDurationSeconds)
                    }.renumbered(\.position))
            },
            workouts: workouts.map { workout in
                .init(
                    id: workout.id, title: workout.title,
                    startDate: BackupDocument.fileDate(workout.startDate),
                    endDate: workout.endDate.map(BackupDocument.fileDate),
                    routineID: workout.routine?.id,
                    exercises: WorkoutLog.orderedExercises(of: workout).compactMap { entry in
                        guard let exercise = entry.exercise else { return nil }
                        return .init(
                            id: entry.id, exerciseID: exercise.id, position: 0,
                            sets: WorkoutLog.orderedSets(of: entry).map { set in
                                .init(
                                    id: set.id, position: 0, setType: set.setTypeRawValue,
                                    weight: set.weight, reps: set.reps,
                                    durationSeconds: set.durationSeconds,
                                    isCompleted: set.isCompleted)
                            }.renumbered(\.position))
                    }.renumbered(\.position))
            })
        // A document that import would reject is no backup: fail now, not when the user restores it.
        try document.validate()
        return document
    }

    // MARK: Restoring

    /// Deletes every model and inserts the document's, with its IDs and positions renumbered from 0, then
    /// saves once. The document is validated first. Any failure, including a failed save, leaves the
    /// store as it was: unsaved changes are rolled back and the error is thrown.
    func replaceAll(with document: BackupDocument) throws {
        try document.validate()
        guard WorkoutLog(context: context).inProgressWorkout() == nil else {
            throw BackupError.workoutInProgress
        }
        do {
            try deleteEverything()
            try insert(document)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func deleteEverything() throws {
        for set in try context.fetch(FetchDescriptor<WorkoutSet>()) { context.delete(set) }
        for entry in try context.fetch(FetchDescriptor<WorkoutExercise>()) { context.delete(entry) }
        for workout in try context.fetch(FetchDescriptor<Workout>()) { context.delete(workout) }
        for entry in try context.fetch(FetchDescriptor<RoutineExercise>()) { context.delete(entry) }
        for routine in try context.fetch(FetchDescriptor<Routine>()) { context.delete(routine) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
    }

    private func insert(_ document: BackupDocument) throws {
        var exercises: [UUID: Exercise] = [:]
        for record in document.exercises {
            let exercise = Exercise(
                id: record.id, name: record.name,
                muscleGroup: try Self.parse(record.muscleGroup),
                equipment: try Self.parse(record.equipment), kind: try Self.parse(record.kind),
                restOverrideSeconds: record.restOverrideSeconds, isCustom: record.isCustom)
            context.insert(exercise)
            exercises[record.id] = exercise
        }

        var routines: [UUID: Routine] = [:]
        for record in document.routines {
            let routine = Routine(
                id: record.id, name: record.name, creationDate: record.creationDate)
            context.insert(routine)
            routines[record.id] = routine
            for (position, entry) in record.exercises.sorted(by: \.position).enumerated() {
                let routineExercise = RoutineExercise(
                    id: entry.id, exercise: try Self.resolve(entry.exerciseID, in: exercises),
                    position: position, plannedSetTypes: try entry.plannedSetTypes.map(Self.parse),
                    repRangeLow: entry.repRangeLow, repRangeHigh: entry.repRangeHigh,
                    targetDurationSeconds: entry.targetDurationSeconds)
                context.insert(routineExercise)
                routine.exercises.append(routineExercise)
            }
        }

        for record in document.workouts {
            let workout = Workout(
                id: record.id, title: record.title, startDate: record.startDate,
                endDate: record.endDate,
                routine: try record.routineID.map { try Self.resolve($0, in: routines) })
            context.insert(workout)
            for (position, entry) in record.exercises.sorted(by: \.position).enumerated() {
                let workoutExercise = WorkoutExercise(
                    id: entry.id, exercise: try Self.resolve(entry.exerciseID, in: exercises),
                    position: position)
                context.insert(workoutExercise)
                workout.exercises.append(workoutExercise)
                for (setPosition, set) in entry.sets.sorted(by: \.position).enumerated() {
                    let workoutSet = WorkoutSet(
                        id: set.id, position: setPosition, setType: try Self.parse(set.setType),
                        weight: set.weight, reps: set.reps, durationSeconds: set.durationSeconds,
                        isCompleted: set.isCompleted)
                    context.insert(workoutSet)
                    workoutExercise.sets.append(workoutSet)
                }
            }
        }
    }

    // MARK: Helpers

    private static func parse<T: RawRepresentable>(_ raw: String) throws -> T
    where T.RawValue == String {
        guard let value = T(rawValue: raw) else {
            throw BackupError.invalid("Unknown value “\(raw)”.")
        }
        return value
    }

    private static func resolve<T>(_ id: UUID, in records: [UUID: T]) throws -> T {
        guard let record = records[id] else {
            throw BackupError.invalid("A reference points at a record that is not in the file.")
        }
        return record
    }
}

extension Array {
    /// The elements in ascending order of the integer at `position`.
    fileprivate func sorted(by position: KeyPath<Element, Int>) -> [Element] {
        sorted { $0[keyPath: position] < $1[keyPath: position] }
    }

    /// The elements with `position` set to their index.
    fileprivate func renumbered(_ position: WritableKeyPath<Element, Int>) -> [Element] {
        enumerated().map { index, element in
            var element = element
            element[keyPath: position] = index
            return element
        }
    }
}
