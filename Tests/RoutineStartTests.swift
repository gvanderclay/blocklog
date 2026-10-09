import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Checks starting a workout from a routine, and its pre-fill, against an in-memory store seeded with the
/// starters.
@MainActor
struct RoutineStartTests {
    let container: ModelContainer
    let log: WorkoutLog
    let start: RoutineStart

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        log = WorkoutLog(context: container.mainContext)
        start = RoutineStart(context: container.mainContext)
    }

    private func exercise(_ name: String) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        return try #require(try container.mainContext.fetch(descriptor).first)
    }

    /// The day with the given number in October 2026, at noon.
    private func day(_ number: Int) throws -> Date {
        try #require(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 10, day: number, hour: 12)))
    }

    /// Logs and finishes a workout of `name` with one checked set per (type, weight, reps) entry.
    private func logFinished(
        on date: Date, _ name: String = "Dumbbell Bench Press", sets: [(SetType, Double, Int)]
    ) throws {
        let workout = try #require(try log.startEmptyWorkout(at: date))
        try log.addExercise(try exercise(name), to: workout)
        let workoutExercise = try #require(workout.exercises.first)
        for (index, spec) in sets.enumerated() {
            if index > 0 { try log.addSet(to: workoutExercise) }
            let set = WorkoutLog.orderedSets(of: workoutExercise)[index]
            try log.setType(spec.0, of: set)
            try log.setWeight(spec.1, of: set)
            set.repsText = String(spec.2)
            try log.toggleCompleted(set)
        }
        _ = try log.finish(workout, title: "Logged", at: date.addingTimeInterval(3600))
    }

    /// Saves a routine with one entry per (exercise name, planned set types), each at 8–12 or a 30 s target.
    private func routine(_ name: String, _ entries: [(String, [SetType])]) throws -> Routine {
        var draft = RoutineDraft()
        draft.name = name
        for (exerciseName, types) in entries {
            draft.addExercise(try exercise(exerciseName))
            draft.exercises[draft.exercises.count - 1].sets = types.map {
                RoutineDraft.PlannedSet(type: $0)
            }
        }
        return try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))
    }

    /// The sets of the workout's first exercise with the given name, in position order.
    private func sets(of workout: Workout, _ name: String = "Dumbbell Bench Press") throws
        -> [WorkoutSet]
    {
        let match = try #require(
            WorkoutLog.orderedExercises(of: workout).first { $0.exercise?.name == name })
        return WorkoutLog.orderedSets(of: match)
    }

    @Test func setsPastLastTimeStartLikeANewSet() throws {
        try logFinished(on: try day(7), sets: [(.normal, 15, 10), (.normal, 15, 10)])
        let push = try routine("Push", [("Dumbbell Bench Press", [.normal, .normal, .normal])])

        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)

        let started = try sets(of: workout)
        #expect(started.map(\.weight) == [15, 15, 5])
        #expect(started.map(\.reps) == [10, 10, nil])
        #expect(started.allSatisfy { !$0.isCompleted })
    }

    @Test func theWorkoutTakesTheRoutinesNameLinkOrderAndSetTypes() throws {
        let push = try routine(
            "Push",
            [
                ("Dumbbell Bench Press", [.warmUp, .normal, .failure]),
                ("Hammer Curl", [.normal, .drop]),
            ])

        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)

        #expect(workout.title == "Push")
        #expect(workout.routine === push)
        #expect(workout.endDate == nil)
        let exercises = WorkoutLog.orderedExercises(of: workout)
        #expect(exercises.map { $0.exercise?.name } == ["Dumbbell Bench Press", "Hammer Curl"])
        #expect(
            exercises.map { WorkoutLog.orderedSets(of: $0).map(\.setType) } == [
                [.warmUp, .normal, .failure], [.normal, .drop],
            ])
        // Saved: a fresh context reads it back.
        let id = workout.id
        let fresh = ModelContext(container)
        let saved = try #require(
            try fresh.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first)
        #expect(saved.routine?.name == "Push")
    }

    @Test func warmUpsPreFillFromLastTimesWarmUpsInOrder() throws {
        try logFinished(
            on: try day(7),
            sets: [(.warmUp, 5, 12), (.warmUp, 10, 8), (.normal, 20, 6), (.normal, 25, 5)])
        let push = try routine(
            "Push", [("Dumbbell Bench Press", [.warmUp, .warmUp, .warmUp, .normal, .normal])])

        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)

        let started = try sets(of: workout)
        #expect(started.map(\.weight) == [5, 10, 5, 20, 25])
        #expect(started.map(\.reps) == [12, 8, nil, 6, 5])
    }

    @Test func aDurationSetGetsTheTargetDuration() throws {
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise("Plank"), to: source)
        let logged = try #require(try sets(of: source, "Plank").first)
        logged.durationText = "45"
        try log.toggleCompleted(logged)
        _ = try log.finish(source, title: "Core", at: try day(7))
        var draft = RoutineDraft()
        draft.name = "Core"
        draft.addExercise(try exercise("Plank"))
        draft.exercises[0].addSet()
        draft.exercises[0].targetDurationSeconds = 60
        let core = try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))

        let workout = try #require(try start.startWorkout(from: core, at: try day(9))?.workout)

        let started = try sets(of: workout, "Plank")
        #expect(started.map(\.durationSeconds) == [60, 60])
        #expect(started.allSatisfy { $0.weight == nil && $0.reps == nil })
    }

    @Test func noHistoryGivesTheDefaults() throws {
        let mixed = try routine(
            "Mixed", [("Dumbbell Bench Press", [.warmUp, .normal]), ("Push-up", [.normal])])

        let workout = try #require(try start.startWorkout(from: mixed, at: try day(9))?.workout)

        let bench = try sets(of: workout)
        #expect(bench.map(\.weight) == [5, 5])
        #expect(bench.map(\.reps) == [nil, nil])
        let pushUp = try #require(try sets(of: workout, "Push-up").first)
        #expect(pushUp.weight == nil)
        #expect(pushUp.reps == nil)
    }

    @Test func bodyweightKeepsLastTimesAddedWeightOrBodyweight() throws {
        let source = try #require(try log.startEmptyWorkout(at: try day(7)))
        try log.addExercise(try exercise("Push-up"), to: source)
        let workoutExercise = try #require(source.exercises.first)
        try log.addSet(to: workoutExercise)
        let logged = WorkoutLog.orderedSets(of: workoutExercise)
        try log.setWeight(10, of: logged[0])
        try log.setWeight(nil, of: logged[1])
        for set in logged {
            // Short of the range's top (8–12), so progression leaves the weights alone.
            set.repsText = "10"
            try log.toggleCompleted(set)
        }
        _ = try log.finish(source, title: "Logged", at: try day(7))
        let push = try routine("Push", [("Push-up", [.normal, .normal])])

        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)

        let started = try sets(of: workout, "Push-up")
        #expect(started.map(\.weight) == [10, nil])
        #expect(started.map(\.reps) == [10, 10])
    }

    @Test func startingIsRefusedWhileAnotherWorkoutIsInProgress() throws {
        let push = try routine("Push", [("Dumbbell Bench Press", [.normal])])
        _ = try #require(try log.startEmptyWorkout(at: try day(9)))

        #expect(try start.startWorkout(from: push, at: try day(9)) == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
    }

    @Test func repsFieldsShowTheRoutinesRangeOnlyForRepExercisesFromARoutine() throws {
        var draft = RoutineDraft()
        draft.name = "Push"
        draft.addExercise(try exercise("Dumbbell Bench Press"))
        draft.exercises[0].repLow = 6
        draft.exercises[0].repHigh = 10
        draft.addExercise(try exercise("Plank"))
        let push = try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))
        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)
        let exercises = WorkoutLog.orderedExercises(of: workout)

        #expect(RoutineLibrary.repRangeText(for: exercises[0]) == "6–10")
        #expect(RoutineLibrary.repRangeText(for: exercises[1]) == nil)

        try log.addExercise(try exercise("Hammer Curl"), to: workout)
        let added = try #require(WorkoutLog.orderedExercises(of: workout).last)
        #expect(RoutineLibrary.repRangeText(for: added) == nil)
    }

    @Test func anExerciseListedTwiceShowsEachOccurrencesRange() throws {
        var draft = RoutineDraft()
        draft.name = "Bench Twice"
        for range in [(6, 8), (10, 12)] {
            draft.addExercise(try exercise("Dumbbell Bench Press"))
            draft.exercises[draft.exercises.count - 1].repLow = range.0
            draft.exercises[draft.exercises.count - 1].repHigh = range.1
        }
        let twice = try #require(
            try RoutineLibrary(context: container.mainContext).save(draft, to: nil))
        let workout = try #require(try start.startWorkout(from: twice, at: try day(9))?.workout)
        let exercises = WorkoutLog.orderedExercises(of: workout)

        #expect(RoutineLibrary.repRangeText(for: exercises[0]) == "6–8")
        #expect(RoutineLibrary.repRangeText(for: exercises[1]) == "10–12")
    }

    @Test func aDurationSetWithNoTargetGetsThirtySeconds() throws {
        let plank = try exercise("Plank")
        let routine = Routine(name: "Core", creationDate: try day(1))
        container.mainContext.insert(routine)
        let entry = RoutineExercise(
            exercise: plank, position: 0, plannedSetTypes: [.normal, .normal])
        container.mainContext.insert(entry)
        routine.exercises.append(entry)

        let workout = try #require(try start.startWorkout(from: routine, at: try day(9))?.workout)

        #expect(try sets(of: workout, "Plank").map(\.durationSeconds) == [30, 30])
    }

    @Test func aStoredRangeWithLowAboveHighOrOnlyOneEndShowsNoRange() throws {
        let bench = try exercise("Dumbbell Bench Press")
        let routine = Routine(name: "Odd", creationDate: try day(1))
        container.mainContext.insert(routine)
        let stored: [(Int?, Int?)] = [(12, 8), (6, nil), (nil, 10)]
        for (position, ends) in stored.enumerated() {
            let entry = RoutineExercise(
                exercise: bench, position: position, plannedSetTypes: [.normal],
                repRangeLow: ends.0, repRangeHigh: ends.1)
            container.mainContext.insert(entry)
            routine.exercises.append(entry)
        }

        let workout = try #require(try start.startWorkout(from: routine, at: try day(9))?.workout)

        let exercises = WorkoutLog.orderedExercises(of: workout)
        #expect(exercises.map { RoutineLibrary.repRangeText(for: $0) } == [nil, nil, nil])
    }

    @Test func aFreeformWorkoutShowsNoRange() throws {
        let workout = try #require(try log.startEmptyWorkout(at: try day(9)))
        try log.addExercise(try exercise("Dumbbell Bench Press"), to: workout)

        #expect(RoutineLibrary.repRangeText(for: try #require(workout.exercises.first)) == nil)
    }

    @Test func finishWithABlankTitleKeepsTheRoutineName() throws {
        let push = try routine("Push", [("Dumbbell Bench Press", [.normal])])
        let workout = try #require(try start.startWorkout(from: push, at: try day(9))?.workout)
        let set = try #require(try sets(of: workout).first)
        set.repsText = "8"
        try log.toggleCompleted(set)

        _ = try log.finish(workout, title: "  ", at: try day(9))

        #expect(workout.title == "Push")
    }

    @Test func aFailedStartRollsBackAndThrows() throws {
        let store = try ReadOnlyStore { context in
            let curl = Exercise(
                name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell, kind: .weightReps)
            context.insert(curl)
            let routine = Routine(name: "Pull", creationDate: .now)
            context.insert(routine)
            let routineExercise = RoutineExercise(
                exercise: curl, position: 0, plannedSetTypes: [.normal, .normal], repRangeLow: 6,
                repRangeHigh: 10)
            context.insert(routineExercise)
            routine.exercises.append(routineExercise)
        }
        defer { store.remove() }
        let context = store.context
        let routine = try #require(try context.fetch(FetchDescriptor<Routine>()).first)

        #expect(throws: (any Error).self) {
            try RoutineStart(context: context).startWorkout(from: routine)
        }

        #expect(!context.hasChanges)
        // `fetchCount` on the failed context still reports the rolled-back workout; a fetch and a fresh
        // context agree that no row exists.
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        #expect(routine.name == "Pull")
        let planned = RoutineLibrary.orderedExercises(of: routine)
        #expect(planned.count == 1)
        #expect(
            planned.first?.plannedSetTypeRawValues == [
                SetType.normal.rawValue, SetType.normal.rawValue,
            ])
        #expect(planned.first?.repRangeLow == 6)
        #expect(planned.first?.repRangeHigh == 10)
    }
}
