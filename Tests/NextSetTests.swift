import SwiftData
import Testing

@testable import Blocklog

@MainActor
struct NextSetTests {
    /// Held by the suite instance: a model is unusable once its container is gone.
    private let container: ModelContainer
    private let workout = Workout(title: "Test", startDate: .now)

    init() throws {
        container = try BlocklogApp.makeContainer(inMemory: true)
        container.mainContext.insert(workout)
    }

    /// Adds an exercise whose sets have the given weights and checked states, at the next position.
    private func addExercise(_ sets: [(weight: Double?, done: Bool)]) -> [WorkoutSet] {
        let exercise = Exercise(
            name: "X", muscleGroup: .biceps, equipment: .dumbbell, kind: .weightReps)
        let workoutExercise = WorkoutExercise(exercise: exercise, position: workout.exercises.count)
        workoutExercise.workout = workout
        container.mainContext.insert(workoutExercise)
        return sets.enumerated().map { index, spec in
            let set = WorkoutSet(position: index, weight: spec.weight, isCompleted: spec.done)
            set.workoutExercise = workoutExercise
            container.mainContext.insert(set)
            return set
        }
    }

    @Test func nextIsTheFollowingUncheckedSetInTheExercise() {
        let sets = addExercise([(30, true), (30, false), (30, false)])
        #expect(NextSet.after(sets[0]) === sets[1])
    }

    @Test func checkingSet3WithSet2UncheckedGivesSet4() {
        let sets = addExercise([(30, true), (30, false), (30, true), (30, false)])
        #expect(NextSet.after(sets[2]) === sets[3])
    }

    @Test func rollsOverToTheNextExercise() {
        let first = addExercise([(30, true)])
        let second = addExercise([(30, false)])
        #expect(NextSet.after(first[0]) === second[0])
    }

    @Test func skipsALaterExerciseWhoseSetsAreAllChecked() {
        let first = addExercise([(30, true)])
        _ = addExercise([(30, true), (30, true)])
        let third = addExercise([(30, true), (30, false)])
        #expect(NextSet.after(first[0]) === third[1])
    }

    @Test func neverWrapsAround() {
        let first = addExercise([(30, false)])
        let last = addExercise([(30, true)])
        #expect(NextSet.after(last[0]) == nil)
        #expect(first[0].isCompleted == false)
    }

    @Test func changeLineFromThirtyToThirtySevenPointFive() {
        let sets = addExercise([(30, true), (37.5, false)])
        let change = NextSet.change(after: sets[0])
        #expect(change?.line == "Pin 30 → 40 · remove 1 adder")
        #expect(change?.now == 30)
        #expect(change?.next == 37.5)
        #expect(PowerBlockTable.setupLine(for: sets[1].weight) == "Pin 40 · 1 adder")
    }

    @Test func equalWeightsGiveNoHint() {
        let sets = addExercise([(30, true), (30, false)])
        #expect(NextSet.change(after: sets[0]) == nil)
    }

    @Test func noWeightOnEitherSideGivesNoHint() {
        let sets = addExercise([(nil, true), (30, false), (nil, false)])
        #expect(NextSet.change(after: sets[0]) == nil)
        #expect(NextSet.change(after: sets[1]) == nil)
    }
}
