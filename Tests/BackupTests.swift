import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks the backup document against in-memory stores seeded with the starters.
@MainActor
struct BackupTests {
    /// 2027-01-15 10:00 UTC plus a fraction of a second finer than a millisecond.
    static let start = Date(timeIntervalSince1970: 1_800_000_000.1234567)
    static let exportDate = Date(timeIntervalSince1970: 1_800_100_000)

    // MARK: Fixtures

    private func exercise(_ name: String, in context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try context.fetch(descriptor).first)
    }

    private func addWorkout(
        _ context: ModelContext, title: String, start: Date, finished: Bool,
        routine: Routine? = nil, _ build: (Workout) -> Void
    ) {
        let workout = Workout(
            title: title, startDate: start,
            endDate: finished ? start.addingTimeInterval(3_000) : nil,
            routine: routine)
        context.insert(workout)
        build(workout)
    }

    private func addExercise(
        _ exercise: Exercise, to workout: Workout, in context: ModelContext, position: Int,
        sets: [WorkoutSet]
    ) {
        let entry = WorkoutExercise(exercise: exercise, position: position)
        context.insert(entry)
        workout.exercises.append(entry)
        for set in sets {
            context.insert(set)
            entry.sets.append(set)
        }
    }

    /// A store with a custom exercise, a routine, two finished workouts covering every exercise type and set
    /// type, and one workout in progress.
    private func makeSource() throws -> ModelContainer {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        try populate(container.mainContext)
        return container
    }

    /// Adds the `makeSource` content to a context that holds the starter exercises, and saves.
    private func populate(_ context: ModelContext) throws {
        let bench = try exercise("Dumbbell Bench Press", in: context)
        let pullUp = try exercise("Pull-up", in: context)
        let plank = try exercise("Plank", in: context)
        let custom = Exercise(
            name: "Farmer Carry", muscleGroup: .forearms, equipment: .dumbbell, type: .weightReps,
            restOverrideSeconds: 120, isCustom: true)
        context.insert(custom)

        let routine = Routine(name: "Push Day", creationDate: Self.start.addingTimeInterval(-9_999))
        context.insert(routine)
        let benchEntry = RoutineExercise(
            exercise: bench, position: 0, plannedSetTypes: [.warmUp, .normal, .normal],
            repRangeLow: 8, repRangeHigh: 12)
        let plankEntry = RoutineExercise(
            exercise: plank, position: 1, plannedSetTypes: [.normal], targetDurationSeconds: 60)
        for entry in [benchEntry, plankEntry] {
            context.insert(entry)
            routine.exercises.append(entry)
        }

        // A programme whose routines are stored out of position order.
        let programme = Programme(name: "PPL", creationDate: Self.start.addingTimeInterval(-5_000))
        context.insert(programme)
        for (name, position) in [("Pull", 1), ("Legs", 0)] {
            let member = Routine(
                name: name, creationDate: Self.start.addingTimeInterval(Double(-4_000 + position)))
            context.insert(member)
            member.membership = ProgrammeMembership(programme: programme, position: position)
        }

        addWorkout(context, title: "Push Day", start: Self.start, finished: true, routine: routine)
        {
            workout in
            addExercise(
                bench, to: workout, in: context, position: 0,
                sets: [
                    WorkoutSet(
                        position: 0, setType: .warmUp, weight: 20, reps: 10, isCompleted: true),
                    WorkoutSet(position: 1, weight: 40, reps: 10, isCompleted: true),
                    WorkoutSet(position: 2, setType: .drop, weight: 30, reps: 8, isCompleted: true),
                    WorkoutSet(
                        position: 3, setType: .failure, weight: 40, reps: 6, isCompleted: true),
                ])
            addExercise(
                pullUp, to: workout, in: context, position: 1,
                sets: [
                    WorkoutSet(position: 0, reps: 8, isCompleted: true),
                    WorkoutSet(position: 1, weight: 10, reps: 6, isCompleted: true),
                ])
            addExercise(
                plank, to: workout, in: context, position: 2,
                sets: [WorkoutSet(position: 0, durationSeconds: 45, isCompleted: true)])
        }
        addWorkout(
            context, title: "Carries", start: Self.start.addingTimeInterval(86_400), finished: true
        ) { workout in
            addExercise(
                custom, to: workout, in: context, position: 0,
                sets: [WorkoutSet(position: 0, weight: 90, reps: 30, isCompleted: true)])
        }
        try context.save()
    }

    /// Adds a workout in progress, which export leaves out.
    private func addInProgressWorkout(to container: ModelContainer) throws {
        let context = container.mainContext
        addWorkout(
            context, title: "Unfinished", start: Self.start.addingTimeInterval(172_800),
            finished: false
        ) { workout in
            addExercise(
                (try? exercise("Hammer Curl", in: context))!, to: workout, in: context,
                position: 0, sets: [WorkoutSet(position: 0, weight: 5)])
        }
        try context.save()
    }

    private func emptyContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BlocklogApp.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func exported(_ container: ModelContainer) throws -> BackupDocument {
        try Backup(context: container.mainContext).export(at: Self.exportDate)
    }

    // MARK: Round trip

    @Test func exportThenImportIntoAnEmptyStoreGivesTheSameDocument() throws {
        let source = try makeSource()
        try addInProgressWorkout(to: source)
        // A date that rounds up to .136 where the format style alone truncates to .135, which then
        // reparses just under .135 and prints .134.
        addWorkout(
            source.mainContext, title: "Odd Date",
            start: Date(timeIntervalSince1970: 1_771_994_388.1357493), finished: true
        ) { workout in
            addExercise(
                (try? exercise("Plank", in: source.mainContext))!, to: workout,
                in: source.mainContext, position: 0,
                sets: [WorkoutSet(position: 0, durationSeconds: 30, isCompleted: true)])
        }
        try source.mainContext.save()
        let document = try exported(source)
        #expect(document.workouts.map(\.title) == ["Odd Date", "Push Day", "Carries"])

        // A store with no models at all: import must not rely on the seeded starters.
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        #expect(try exported(target) == document)
        // Every cycle gives the same text, so no date drifts by a millisecond.
        #expect(try exported(target).encoded() == document.encoded())
        #expect(
            String(decoding: try document.encoded(), as: UTF8.self).contains(
                "\"startDate\" : \"2026-02-25T04:39:48.136Z\""))
        #expect(document.exercises.contains { $0.name == "Farmer Carry" && $0.isCustom })
    }

    @Test func importKeepsDatesToTheMillisecondAndTheRoutineLink() throws {
        let source = try makeSource()
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(exported(source).encoded()))

        let workouts = try target.mainContext.fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startDate)]))
        #expect(abs(workouts[0].startDate.timeIntervalSince(Self.start)) < 0.001)
        #expect(workouts[0].routine?.name == "Push Day")
        #expect(workouts[1].routine == nil)
    }

    @Test func importKeepsProgrammesAndTheirRoutineOrder() throws {
        let document = try exported(makeSource())
        #expect(document.programmes.map(\.name) == ["PPL"])
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        let programme = try #require(
            try target.mainContext.fetch(FetchDescriptor<Programme>()).first)
        #expect(programme.name == "PPL")
        #expect(ProgrammeLibrary.orderedRoutines(of: programme).map(\.name) == ["Legs", "Pull"])
        let push = try #require(
            try target.mainContext.fetch(
                FetchDescriptor<Routine>(predicate: #Predicate { $0.name == "Push Day" })
            ).first)
        #expect(push.membership == nil)
    }

    @Test func aBackupWithoutProgrammesFromBeforeThemStillImports() throws {
        var document = try exported(makeSource())
        document.programmes = []
        for index in document.routines.indices {
            document.routines[index].programmeID = nil
            document.routines[index].programmePosition = nil
        }
        var json = try #require(
            try JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any])
        json["programmes"] = nil
        let data = try JSONSerialization.data(withJSONObject: json)

        let read = try BackupDocument.read(data)

        #expect(read.programmes.isEmpty)
        #expect(read.routines.count == 3)
    }

    @Test func importKeepsWhichExercisesArePerSide() throws {
        let document = try exported(makeSource())
        let records = Dictionary(uniqueKeysWithValues: document.exercises.map { ($0.name, $0) })
        #expect(records["Hip Flexor Stretch"]?.isPerSide == true)
        #expect(records["Elephant Walks"]?.isPerSide == nil)
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        #expect(try exercise("Hip Flexor Stretch", in: target.mainContext).isPerSide == true)
        #expect(try exercise("Elephant Walks", in: target.mainContext).isPerSide == nil)
        #expect(try exported(target) == document)
    }

    @Test func aBackupWithoutPerSideFromBeforeItStillImports() throws {
        let document = try exported(makeSource())
        var json = try #require(
            try JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any])
        let exercises = try #require(json["exercises"] as? [[String: Any]])
        #expect(exercises.contains { $0["isPerSide"] != nil })
        json["exercises"] = exercises.map { record in
            var record = record
            record["isPerSide"] = nil
            return record
        }
        let target = try emptyContainer()

        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(JSONSerialization.data(withJSONObject: json)))

        let stored = try target.mainContext.fetch(FetchDescriptor<Exercise>())
        #expect(stored.count == document.exercises.count)
        #expect(stored.allSatisfy { $0.isPerSide == nil })
    }

    @Test func fileIsIso8601JsonWithRawStringEnums() throws {
        let source = try makeSource()
        let text = String(decoding: try exported(source).encoded(), as: UTF8.self)
        #expect(text.contains("\"version\" : 3"))
        #expect(text.contains("\"exportedAt\" : \"2027-01-16T"))
        #expect(text.contains("\"setType\" : \"warmUp\""))
    }

    @Test func fileNameUsesTheDayInTheTimeZone() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
        #expect(
            Backup.fileName(for: date, in: TimeZone(identifier: "UTC")!)
                == "blocklog-backup-2027-01-15.json")
        #expect(
            Backup.fileName(for: date, in: TimeZone(identifier: "Pacific/Kiritimati")!)
                == "blocklog-backup-2027-01-15.json")
        #expect(
            Backup.fileName(for: date, in: TimeZone(identifier: "Pacific/Pago_Pago")!)
                == "blocklog-backup-2027-01-14.json")
    }

    // MARK: Replacing

    @Test func importReplacesWhatTheStoreHeld() throws {
        let source = try makeSource()
        let document = try exported(source)

        let target = try makeSource()
        let context = target.mainContext
        context.insert(
            Exercise(name: "Stray", muscleGroup: .core, equipment: .bodyweight, type: .duration))
        addWorkout(
            context, title: "Old", start: .now.addingTimeInterval(-5_000_000), finished: true
        ) {
            workout in
            addExercise(
                (try? exercise("Plank", in: context))!, to: workout, in: context, position: 0,
                sets: [WorkoutSet(position: 0, durationSeconds: 30, isCompleted: true)])
        }
        try context.save()
        let backup = Backup(context: context)
        #expect(try backup.storedCounts().workouts == 3)

        try backup.replaceAll(with: document)

        #expect(try exported(target) == document)
        #expect(try backup.storedCounts() == Backup.counts(of: document))
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 8)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<RoutineExercise>()) == 2)
    }

    @Test func importRenumbersPositionsInOrder() throws {
        var document = try exported(makeSource())
        document.workouts[0].exercises[0].position = 40
        document.workouts[0].exercises[1].position = -3
        document.workouts[0].exercises[0].sets[0].position = 9
        document.workouts[0].exercises[0].sets[1].position = -1
        let target = try BlocklogApp.makeContainer(inMemory: true)
        try Backup(context: target.mainContext).replaceAll(with: document)

        let workout = try #require(
            try target.mainContext.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.title == "Push Day" })
            ).first)
        let entries = WorkoutLog.orderedExercises(of: workout)
        #expect(entries.map(\.position) == [0, 1, 2])
        #expect(entries.map { $0.exercise?.name } == ["Pull-up", "Plank", "Dumbbell Bench Press"])
        let sets = WorkoutLog.orderedSets(of: entries[2])
        #expect(sets.map(\.position) == [0, 1, 2, 3])
        #expect(sets.map(\.weight) == [40, 30, 40, 20])
    }

    @Test func importIsRefusedWhileAWorkoutIsInProgress() throws {
        let document = try exported(makeSource())
        let target = try makeSource()
        try addInProgressWorkout(to: target)
        let before = try exported(target)

        #expect(throws: BackupError.workoutInProgress) {
            try Backup(context: target.mainContext).replaceAll(with: document)
        }
        #expect(try exported(target) == before)
        #expect(WorkoutLog(context: target.mainContext).inProgressWorkout() != nil)
    }

    @Test func importingABackupIntoTheStoreItCameFromGivesTheSameDocument() throws {
        let source = try makeSource()
        let document = try exported(source)
        try Backup(context: source.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        #expect(try exported(source) == document)
        #expect(
            try Backup(context: source.mainContext).storedCounts() == Backup.counts(of: document))
    }

    /// A store whose saves fail, standing in for a full disk, holding what `populate` adds.
    @Test func aFailedSaveRestoresTheStore() throws {
        let store = try ReadOnlyStore { context in
            try StarterExercises.seedMissing(context)
            try populate(context)
        }
        defer { store.remove() }
        let readOnly = store.container
        let context = readOnly.mainContext
        let backup = Backup(context: context)
        let before = try exported(readOnly)
        let storedBefore = try backup.storedCounts()
        #expect(storedBefore.workouts == 2)
        let other = try exported(BlocklogApp.makeContainer(inMemory: true))
        #expect(Backup.counts(of: other) != storedBefore)

        #expect(throws: (any Error).self) { try backup.replaceAll(with: other) }

        // Nothing is left pending for autosave to commit once the store can save again.
        #expect(!context.hasChanges)
        #expect(try exported(readOnly) == before)
        #expect(try backup.storedCounts() == storedBefore)
    }

    @Test func replaceAllValidatesADocumentThatDidNotComeFromRead() throws {
        var document = try exported(makeSource())
        // Only validation rejects this: the exercise reference still resolves.
        document.workouts[0].exercises[0].sets[0].isCompleted = false
        let target = try makeSource()
        let before = try exported(target)

        #expect(throws: BackupError.self) {
            try Backup(context: target.mainContext).replaceAll(with: document)
        }
        #expect(try exported(target) == before)
    }

    @Test func exportThrowsWhenTheStoredDataWouldFailImport() throws {
        let source = try makeSource()
        let workout = try #require(
            try source.mainContext.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.title == "Carries" })
            ).first)
        // A clock change can leave a workout ending before it started.
        workout.endDate = workout.startDate.addingTimeInterval(-60)

        #expect(throws: BackupError.invalid("Workout “Carries” ends before it starts.")) {
            try Backup(context: source.mainContext).export()
        }
    }

    @Test func countsSummaryUsesSingularAndPlural() {
        #expect(
            BackupCounts(workouts: 1, routines: 0, exercises: 2).summary
                == "1 workout, 0 routines and 2 exercises")
        #expect(
            BackupCounts(workouts: 3, routines: 1, exercises: 1).summary
                == "3 workouts, 1 routine and 1 exercise")
    }

    // MARK: Rejection

    /// Applies the change to a valid document, then expects reading and restoring it to fail with a message
    /// containing `fragment` and the target store to be unchanged.
    private func expectRejected(
        containing fragment: String, sourceLocation: SourceLocation = #_sourceLocation,
        _ change: (inout BackupDocument) -> Void
    ) throws {
        var document = try exported(makeSource())
        change(&document)
        try expectRejected(
            data: document.encoded(), containing: fragment, sourceLocation: sourceLocation)
    }

    @Test func aBackupWithNoExercisesIsRejectedSoLaunchSeedingCannotUndoTheRestore() throws {
        var document = try exported(makeSource())
        document.exercises = []
        document.routines = []
        document.workouts = []
        let target = try makeSource()
        let before = try exported(target)
        let storedBefore = try Backup(context: target.mainContext).storedCounts()
        do {
            let rejected = try BackupDocument.read(document.encoded())
            try Backup(context: target.mainContext).replaceAll(with: rejected)
            Issue.record("The document was accepted.")
        } catch {
            #expect(error.localizedDescription.contains("no exercises"))
        }
        #expect(try exported(target) == before)
        #expect(try Backup(context: target.mainContext).storedCounts() == storedBefore)
        try StarterExercises.seedMissing(target.mainContext)
        #expect(try exported(target) == before)
        #expect(try Backup(context: target.mainContext).storedCounts() == storedBefore)
    }

    private func expectRejected(
        data: Data, containing fragment: String, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let target = try makeSource()
        let before = try exported(target)
        let storedBefore = try Backup(context: target.mainContext).storedCounts()
        do {
            let document = try BackupDocument.read(data)
            try Backup(context: target.mainContext).replaceAll(with: document)
            Issue.record("The document was accepted.", sourceLocation: sourceLocation)
        } catch {
            #expect(
                error.localizedDescription.contains(fragment),
                "\(error.localizedDescription) should contain \(fragment)",
                sourceLocation: sourceLocation)
        }
        #expect(try exported(target) == before, sourceLocation: sourceLocation)
        #expect(
            try Backup(context: target.mainContext).storedCounts() == storedBefore,
            sourceLocation: sourceLocation)
    }

    @Test func rejectsMalformedJson() throws {
        try expectRejected(data: Data("{ not json".utf8), containing: "isn’t a Blocklog backup")
        try expectRejected(data: Data("{}".utf8), containing: "version")
        try expectRejected(data: Data(), containing: "isn’t a Blocklog backup")
    }

    @Test func rejectsAnUnknownVersion() throws {
        try expectRejected(containing: "version 4") { $0.version = 4 }
    }

    @Test func rejectsAnOlderVersionWithAClearError() throws {
        try expectRejected(containing: "older backups can't be imported") { $0.version = 1 }
    }

    @Test func rejectsADanglingExerciseReference() throws {
        try expectRejected(containing: "exercise that is not in the file") {
            $0.workouts[0].exercises[0].exerciseID = UUID()
        }
        try expectRejected(containing: "exercise that is not in the file") {
            $0.routines[0].exercises[0].exerciseID = UUID()
        }
        try expectRejected(containing: "routine that is not in the file") {
            $0.workouts[0].routineID = UUID()
        }
    }

    @Test func rejectsADuplicateID() throws {
        try expectRejected(containing: "ID that is used more than once") {
            $0.exercises[1].id = $0.exercises[0].id
        }
        try expectRejected(containing: "ID that is used more than once") {
            $0.workouts[1].id = $0.workouts[0].id
        }
        try expectRejected(containing: "ID that is used more than once") {
            $0.workouts[0].exercises[0].sets[1].id = $0.workouts[0].exercises[0].sets[0].id
        }
    }

    @Test func rejectsUnknownEnumValues() throws {
        try expectRejected(containing: "unknown set type, “sideways”") {
            $0.workouts[0].exercises[0].sets[0].setType = "sideways"
        }
        try expectRejected(containing: "unknown set type") {
            $0.routines[0].exercises[0].plannedSetTypes = ["x"]
        }
        try expectRejected(containing: "unknown muscle group") {
            $0.exercises[0].muscleGroup = "neck"
        }
        try expectRejected(containing: "unknown equipment") {
            $0.exercises[0].equipment = "kettlebell"
        }
        try expectRejected(containing: "unknown type") { $0.exercises[0].type = "cardio" }
    }

    @Test func rejectsABadExerciseName() throws {
        try expectRejected(containing: "has no name") { $0.exercises[0].name = "  " }
        try expectRejected(containing: "ignoring case") {
            $0.exercises[0].name = $0.exercises[1].name.uppercased()
        }
    }

    @Test func rejectsARestOverrideOutsideThePickerRange() throws {
        try expectRejected(containing: "rest time of 0 seconds") {
            $0.exercises[0].restOverrideSeconds = 0
        }
        try expectRejected(containing: "rest time of -30 seconds") {
            $0.exercises[0].restOverrideSeconds = -30
        }
        try expectRejected(containing: "rest time of 301 seconds") {
            $0.exercises[0].restOverrideSeconds = 301
        }
        try expectRejected(containing: "rest time of \(Int.max) seconds") {
            $0.exercises[0].restOverrideSeconds = Int.max
        }
    }

    @Test func acceptsARestOverrideOfFiveMinutes() throws {
        var document = try exported(makeSource())
        document.exercises[0].restOverrideSeconds = 300
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))
        #expect(try exported(target).exercises[0].restOverrideSeconds == 300)
    }

    @Test func acceptsAnExerciseWithNoRestOverride() throws {
        var document = try exported(makeSource())
        document.exercises[0].restOverrideSeconds = nil
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))
        #expect(try exported(target).exercises[0].restOverrideSeconds == nil)
    }

    @Test func rejectsAWeightThatIsNotAPowerBlockSetting() throws {
        try expectRejected(containing: "12.5 lb") {
            $0.workouts[0].exercises[0].sets[1].weight = 12.5
        }
        // The added weight of a bodyweight set too.
        try expectRejected(containing: "12.5 lb") {
            $0.workouts[0].exercises[1].sets[1].weight = 12.5
        }
    }

    @Test func rejectsSetsThatDoNotMatchTheirType() throws {
        // Workout 0: exercises sorted by position are bench, pull-up, plank.
        try expectRejected(containing: "needs a duration and no weight or reps") {
            $0.workouts[0].exercises[2].sets[0].reps = 10
        }
        try expectRejected(containing: "needs a duration") {
            $0.workouts[0].exercises[2].sets[0].durationSeconds = 0
        }
        try expectRejected(containing: "needs a weight and reps") {
            $0.workouts[0].exercises[0].sets[1].weight = nil
        }
        try expectRejected(containing: "needs a weight and reps") {
            $0.workouts[0].exercises[0].sets[1].reps = 0
        }
        try expectRejected(containing: "no duration") {
            $0.workouts[0].exercises[0].sets[1].durationSeconds = 30
        }
        try expectRejected(containing: "needs reps") {
            $0.workouts[0].exercises[1].sets[0].reps = nil
        }
        try expectRejected(containing: "not completed") {
            $0.workouts[0].exercises[0].sets[1].isCompleted = false
        }
    }

    @Test func rejectsAnUnfinishedWorkoutOrOneThatEndsBeforeItStarts() throws {
        try expectRejected(containing: "is not finished") { $0.workouts[0].endDate = nil }
        try expectRejected(containing: "ends before it starts") {
            $0.workouts[0].endDate = $0.workouts[0].startDate.addingTimeInterval(-1)
        }
    }

    @Test func rejectsDuplicatePositions() throws {
        try expectRejected(containing: "same position") {
            $0.workouts[0].exercises[1].position = $0.workouts[0].exercises[0].position
        }
        try expectRejected(containing: "same position") {
            $0.workouts[0].exercises[0].sets[1].position =
                $0.workouts[0].exercises[0].sets[0].position
        }
        try expectRejected(containing: "same position") {
            $0.routines[0].exercises[1].position = $0.routines[0].exercises[0].position
        }
    }

    @Test func rejectsProgrammePositionsThatAreNotZeroToNMinusOne() throws {
        // Routines sorted by creation date: Push Day, Legs (position 0), Pull (position 1).
        try expectRejected(containing: "routine positions that aren’t 0") {
            $0.routines[2].programmePosition = 2
        }
        try expectRejected(containing: "routine positions that aren’t 0") {
            $0.routines[2].programmePosition = 0
        }
        try expectRejected(containing: "routine positions that aren’t 0") {
            $0.routines[2].programmePosition = -1
        }
        try expectRejected(containing: "programme position but no programme") {
            $0.routines[0].programmePosition = 2
        }
        try expectRejected(containing: "programme but no position") {
            $0.routines[1].programmePosition = nil
        }
        try expectRejected(containing: "programme that is not in the file") {
            $0.routines[1].programmeID = UUID()
        }
        try expectRejected(containing: "programme has no name") { $0.programmes[0].name = " " }
    }

    @Test func rejectsBadRepRangesAndTargetDurations() throws {
        try expectRejected(containing: "rep range 12–8") {
            $0.routines[0].exercises[0].repRangeLow = 12
            $0.routines[0].exercises[0].repRangeHigh = 8
        }
        try expectRejected(containing: "rep range 0–12") {
            $0.routines[0].exercises[0].repRangeLow = 0
        }
        try expectRejected(containing: "rep range 8–51") {
            $0.routines[0].exercises[0].repRangeHigh = 51
        }
        try expectRejected(containing: "only one end") {
            $0.routines[0].exercises[0].repRangeHigh = nil
        }
        try expectRejected(containing: "target duration of 0") {
            $0.routines[0].exercises[1].targetDurationSeconds = 0
        }
    }

    @Test func rejectsATargetThatDoesNotMatchItsExerciseType() throws {
        // Routine exercise 0 is a weight and reps exercise, 1 a duration exercise.
        try expectRejected(containing: "target duration for a rep exercise") {
            $0.routines[0].exercises[0].targetDurationSeconds = 45
        }
        try expectRejected(containing: "rep range for a duration exercise") {
            $0.routines[0].exercises[1].repRangeLow = 5
            $0.routines[0].exercises[1].repRangeHigh = 9
        }
    }

    @Test func acceptsARoutineExerciseWithNeitherRangeNorDuration() throws {
        var document = try exported(makeSource())
        document.routines[0].exercises[0].repRangeLow = nil
        document.routines[0].exercises[0].repRangeHigh = nil
        document.routines[0].exercises[1].targetDurationSeconds = nil
        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        let stored = try target.mainContext.fetch(FetchDescriptor<RoutineExercise>())
            .sorted { $0.position < $1.position }
        #expect(stored.map(\.repRangeLow) == [nil, nil])
        #expect(stored.map(\.targetDurationSeconds) == [nil, nil])
    }

    // MARK: Routine and workout formats

    /// The `makeSource` store plus copies of Cindy and Full-Body Quick Stretch, and a finished Cindy workout with
    /// its score.
    private func makeGuidedSource() throws -> ModelContainer {
        let source = try makeSource()
        let context = source.mainContext
        let starters = try StarterRoutine.load()
        let library = RoutineLibrary(context: context)
        var routines: [Routine] = []
        for (offset, name) in ["Cindy", "Full-Body Quick Stretch"].enumerated() {
            let starter = try #require(starters.first { $0.name == name })
            let draft = try StarterLibrary(context: context).draft(of: starter)
            routines.append(
                try #require(
                    try library.save(
                        draft, to: nil, at: Self.start.addingTimeInterval(Double(offset)))))
        }
        addWorkout(
            context, title: "Cindy", start: Self.start.addingTimeInterval(200_000), finished: true,
            routine: routines[0]
        ) { workout in
            workout.format = .timedAMRAP(rounds: 14, extraReps: 7)
            addExercise(
                (try? exercise("Push-up", in: context))!, to: workout, in: context, position: 0,
                sets: [WorkoutSet(position: 0, reps: 147, isCompleted: true)])
        }
        try context.save()
        return source
    }

    /// The index of the routine or workout record named `name`.
    private func index(of name: String, in records: [String]) throws -> Int {
        try #require(records.firstIndex(of: name))
    }

    @Test func formatsAndTheAMRAPScoreRoundTrip() throws {
        let document = try exported(makeGuidedSource())
        let cindy = try index(of: "Cindy", in: document.routines.map(\.name))
        let stretch = try index(of: "Full-Body Quick Stretch", in: document.routines.map(\.name))
        #expect(document.routines[cindy].format == "timedAMRAP")
        #expect(document.routines[cindy].timeCapSeconds == 1200)
        #expect(document.routines[stretch].format == "stretch")
        #expect(document.routines[0].format == nil)
        let text = String(decoding: try document.encoded(), as: UTF8.self)
        #expect(text.contains("\"amrapRounds\" : 14"))

        let target = try emptyContainer()
        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(document.encoded()))

        #expect(try exported(target) == document)
        let routines = try target.mainContext.fetch(RoutineLibrary.routinesByName)
        #expect(routines.first { $0.name == "Cindy" }?.format == .timedAMRAP(timeCapSeconds: 1200))
        #expect(routines.first { $0.name == "Full-Body Quick Stretch" }?.format == .stretch)
        #expect(routines.first { $0.name == "Push Day" }?.format == .sets)
        let workouts = try target.mainContext.fetch(FetchDescriptor<Workout>())
        #expect(
            workouts.first { $0.title == "Cindy" }?.format == .timedAMRAP(rounds: 14, extraReps: 7))
        #expect(workouts.first { $0.title == "Carries" }?.format == .sets)
    }

    @Test func aVersionTwoBackupWithoutTheFormatKeysStillImports() throws {
        var document = try exported(makeSource())
        document.version = 2
        let text = String(decoding: try document.encoded(), as: UTF8.self)
        #expect(!text.contains("\"format\""))
        let target = try emptyContainer()

        try Backup(context: target.mainContext).replaceAll(
            with: BackupDocument.read(Data(text.utf8)))

        let routines = try target.mainContext.fetch(FetchDescriptor<Routine>())
        #expect(routines.count == 3)
        #expect(routines.allSatisfy { $0.format == .sets })
    }

    /// Applies the change to the guided source's document, then expects it refused with the store unchanged.
    private func expectGuidedRejected(
        containing fragment: String, sourceLocation: SourceLocation = #_sourceLocation,
        _ change: (inout BackupDocument) throws -> Void
    ) throws {
        var document = try exported(makeGuidedSource())
        try change(&document)
        try expectRejected(
            data: document.encoded(), containing: fragment, sourceLocation: sourceLocation)
    }

    @Test func rejectsFormatFieldsThatDontReadAsAFormat() throws {
        let fragment = "has a format that isn’t Sets"
        try expectGuidedRejected(containing: fragment) { $0.routines[0].timeCapSeconds = 600 }
        try expectGuidedRejected(containing: fragment) { $0.routines[0].format = "ladder" }
        try expectGuidedRejected(containing: fragment) {
            let cindy = try index(of: "Cindy", in: $0.routines.map(\.name))
            $0.routines[cindy].timeCapSeconds = nil
        }
        try expectGuidedRejected(containing: fragment) {
            let cindy = try index(of: "Cindy", in: $0.routines.map(\.name))
            $0.routines[cindy].timeCapSeconds = 3660
        }
        try expectGuidedRejected(containing: fragment) {
            let stretch = try index(of: "Full-Body Quick Stretch", in: $0.routines.map(\.name))
            $0.routines[stretch].timeCapSeconds = 600
        }
    }

    @Test func rejectsATimedAMRAPWhoseExercisesDontBuildARound() throws {
        let fragment = "is a Timed AMRAP whose exercises"
        func cindy(_ document: BackupDocument) throws -> Int {
            try index(of: "Cindy", in: document.routines.map(\.name))
        }
        try expectGuidedRejected(containing: fragment) {
            let cindy = try cindy($0)
            $0.routines[cindy].exercises[1].plannedSetTypes = ["normal", "normal"]
        }
        try expectGuidedRejected(containing: fragment) {
            let cindy = try cindy($0)
            $0.routines[cindy].exercises[2].repRangeLow = 10
        }
        try expectGuidedRejected(containing: fragment) {
            let cindy = try cindy($0)
            $0.routines[cindy].exercises = []
        }
        // A duration exercise with a target duration in the round.
        try expectGuidedRejected(containing: fragment) {
            let cindy = try cindy($0)
            var plank = $0.routines[0].exercises[1]
            plank.id = UUID()
            plank.position = 3
            $0.routines[cindy].exercises.append(plank)
        }
        // Push Day, a routine of sets, turned into a Timed AMRAP.
        try expectGuidedRejected(containing: fragment) {
            $0.routines[0].format = "timedAMRAP"
            $0.routines[0].timeCapSeconds = 600
        }
    }

    @Test func rejectsAStretchRoutineWithANonDurationExercise() throws {
        try expectGuidedRejected(containing: "is a Stretch routine whose exercises") {
            let stretch = try index(of: "Full-Body Quick Stretch", in: $0.routines.map(\.name))
            var bench = $0.routines[0].exercises[0]
            bench.id = UUID()
            bench.position = 99
            $0.routines[stretch].exercises.append(bench)
        }
    }

    @Test func rejectsAWorkoutWhoseFormatAndScoreDisagree() throws {
        let fragment = "has a format and AMRAP score that don’t match"
        func cindy(_ document: BackupDocument) throws -> Int {
            try index(of: "Cindy", in: document.workouts.map(\.title))
        }
        try expectGuidedRejected(containing: fragment) { $0.workouts[0].amrapRounds = 3 }
        try expectGuidedRejected(containing: fragment) {
            $0.workouts[0].format = "timedAMRAP"
        }
        try expectGuidedRejected(containing: fragment) {
            $0.workouts[try cindy($0)].amrapExtraReps = nil
        }
        try expectGuidedRejected(containing: fragment) {
            $0.workouts[try cindy($0)].amrapRounds = -1
        }
        try expectGuidedRejected(containing: fragment) {
            $0.workouts[try cindy($0)].amrapExtraReps = -1
        }
        try expectGuidedRejected(containing: fragment) {
            $0.workouts[try cindy($0)].format = "stretch"
        }
    }

    @Test func exportRefusesAStoredAMRAPThatDoesntBuildARound() throws {
        let source = try makeGuidedSource()
        let cindy = try #require(
            try source.mainContext.fetch(RoutineLibrary.routinesByName).first { $0.name == "Cindy" }
        )
        RoutineLibrary.orderedExercises(of: cindy)[0].target = .repRange(3...5)

        #expect(throws: BackupError.self) { try Backup(context: source.mainContext).export() }
    }
}
