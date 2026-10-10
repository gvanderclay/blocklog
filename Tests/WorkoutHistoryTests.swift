import Foundation
import SwiftData
import Testing

@testable import Blocklog

@MainActor
struct WorkoutHistoryTests {
    private func workout(minutes: Double, in context: ModelContext, finished: Bool = true)
        -> Workout
    {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let workout = Workout(
            title: "W", startDate: start,
            endDate: finished ? start.addingTimeInterval(minutes * 60) : nil)
        context.insert(workout)
        return workout
    }

    @Test func inProgressWorkoutIsNotListedAndFinishedAreNewestFirst() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let old = workout(minutes: 5, in: context)
        let inProgress = workout(minutes: 0, in: context, finished: false)
        let newer = Workout(
            title: "N", startDate: old.startDate.addingTimeInterval(1000),
            endDate: old.startDate.addingTimeInterval(2000))
        context.insert(newer)
        let listed = try context.fetch(WorkoutHistory.finishedWorkouts)
        #expect(listed.map(\.id) == [newer.id, old.id])
        #expect(!listed.contains { $0.id == inProgress.id })
    }

    @Test func durationFormat() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        #expect(WorkoutHistory.durationText(of: workout(minutes: 42, in: context)) == "42m")
        #expect(WorkoutHistory.durationText(of: workout(minutes: 65, in: context)) == "1h 05m")
        #expect(
            WorkoutHistory.durationText(of: workout(minutes: 0, in: context, finished: false))
                == nil)
    }

    @Test func rowTitleAddsTheProgramName() throws {
        let container = try BlocklogApp.makeContainer(inMemory: true)
        let context = container.mainContext
        let program = Program(name: "PPL", creationDate: .now)
        let routine = Routine(name: "Push", creationDate: .now)
        context.insert(program)
        context.insert(routine)
        routine.membership = ProgramMembership(program: program, position: 0)
        let workout = workout(minutes: 1, in: context)
        workout.title = "Push"
        #expect(WorkoutHistory.rowTitle(of: workout) == "Push")
        workout.routine = routine
        #expect(WorkoutHistory.rowTitle(of: workout) == "Push · PPL")
        #expect(WorkoutHistory.exerciseCountText(of: workout) == "0 exercises")
    }
}
