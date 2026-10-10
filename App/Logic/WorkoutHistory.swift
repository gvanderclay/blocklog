import Foundation
import SwiftData

/// What the History tab lists and how it words each finished workout.
@MainActor
enum WorkoutHistory {
    /// The finished workouts (end date set), newest start date first. Views use it in `@Query`.
    static var finishedWorkouts: FetchDescriptor<Workout> {
        FetchDescriptor(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }

    /// The title, followed by " · " and the program's name when the workout's routine belongs to one:
    /// "Push · PPL".
    static func rowTitle(of workout: Workout) -> String {
        guard let program = workout.routine?.membership?.program else { return workout.title }
        return "\(workout.title) · \(program.name)"
    }

    /// The start date as "Tue, Oct 7".
    static func dateText(of workout: Workout) -> String {
        workout.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// The start date and time, as "Tue, Oct 7 at 6:30 PM" in the user's locale.
    static func dateTimeText(of workout: Workout) -> String {
        workout.startDate.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    /// The duration as "42m", or "1h 05m" from an hour up; seconds are dropped. Nil for an unfinished workout.
    static func durationText(of workout: Workout) -> String? {
        guard let endDate = workout.endDate else { return nil }
        return durationText(seconds: endDate.timeIntervalSince(workout.startDate))
    }

    static func durationText(seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds)) / 60
        guard minutes >= 60 else { return "\(minutes)m" }
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    /// "1 exercise" or "4 exercises".
    static func exerciseCountText(of workout: Workout) -> String {
        let count = workout.exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }
}
