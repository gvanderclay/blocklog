import Foundation
import Observation

/// The rest countdown after a set is checked off. It stores the end date and the rest's total length,
/// never a ticking counter, and reads "now" from an injected clock.
@Observable
@MainActor
final class RestTimer {
    /// The rest lengths the pickers offer, in seconds: 0:30 to 5:00 in 15-second steps.
    static let choices = Array(stride(from: 30, through: 300, by: 15))

    /// When the rest ends; nil when idle.
    private(set) var endDate: Date?
    /// The rest's length so far, with every ±15 included; nil when idle.
    private(set) var total: TimeInterval?
    /// The set whose check-off started this rest, for the change hint; nil when idle or after a relaunch.
    private(set) var checkedSet: WorkoutSet?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let notifications: any RestNotifying
    /// The exercise the notification names. Not stored across launches.
    @ObservationIgnored private var exerciseName: String?
    /// True once the end of this rest was handled (announced or silently passed), so it fires once per rest.
    @ObservationIgnored private var hasSignalledEnd = false

    init(
        now: @escaping () -> Date = { .now },
        notifications: any RestNotifying = RestNotifications()
    ) {
        self.now = now
        self.notifications = notifications
    }

    var isRunning: Bool { endDate != nil }

    /// The seconds left at the clock's now, never negative.
    var remaining: TimeInterval { remaining(at: now()) }

    func remaining(at date: Date) -> TimeInterval {
        max(endDate?.timeIntervalSince(date) ?? 0, 0)
    }

    /// The seconds since the end date at the given time; 0 before the end and when idle.
    func overtime(at date: Date) -> TimeInterval {
        max(endDate.map { date.timeIntervalSince($0) } ?? 0, 0)
    }

    /// True when the rest has run out and keeps counting up.
    var isOvertime: Bool { isOvertime(at: now()) }

    func isOvertime(at date: Date) -> Bool { endDate.map { date >= $0 } ?? false }

    /// Reschedules the pending notification, so a changed Timer Sound applies to the rest in progress.
    /// Does nothing when idle or in overtime.
    func timerSoundChanged() {
        if isRunning, !isOvertime { scheduleNotification() }
    }

    /// m:ss, such as "1:30".
    static func clock(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1)))
    }

    /// +m:ss, such as "+0:45", for the overtime count.
    static func overtimeClock(_ seconds: Int) -> String { "+" + clock(seconds) }

    /// True for the last three seconds of a countdown as the whole seconds left go from `old` to `new`:
    /// each of those ticks gives a light haptic.
    static func isCountdownTick(from old: Int, to new: Int) -> Bool {
        (1...3).contains(new) && new < old
    }

    /// The exercise's rest override if it has one, otherwise the default rest.
    static func restSeconds(for exercise: Exercise?, defaultRest: Int) -> Int {
        exercise?.restOverrideSeconds ?? defaultRest
    }

    /// Starts or restarts the countdown and schedules the notification.
    func start(duration: Int, exerciseName: String? = nil) {
        guard duration > 0 else { return }
        self.exerciseName = exerciseName
        endDate = now().addingTimeInterval(TimeInterval(duration))
        hasSignalledEnd = false
        total = TimeInterval(duration)
        scheduleNotification()
    }

    /// Moves the end and the total by the same seconds (−15 or +15) and reschedules. A change that would put
    /// the end at or before now puts it at now instead: the rest is over and runs on in overtime, silently,
    /// as the user's own tap ended it. Does nothing when idle or already in overtime.
    func add(seconds: Int) {
        guard let endDate, let total, !isOvertime else { return }
        let current = now()
        let newEnd = max(endDate.addingTimeInterval(TimeInterval(seconds)), current)
        self.endDate = newEnd
        self.total = total + newEnd.timeIntervalSince(endDate)
        if newEnd > current {
            scheduleNotification()
        } else {
            hasSignalledEnd = true
            notifications.cancel()
        }
    }

    /// Ends the rest and cancels the notification. Finish, Discard and the Skip button use it.
    func skip() {
        endDate = nil
        total = nil
        checkedSet = nil
        hasSignalledEnd = false
        notifications.cancel()
    }

    /// Handles the end of the rest once, when the end date has passed: removes the notification and returns
    /// true when the caller should give the haptic and the chime, which is when the app is active as the end
    /// is reached. Pass false on return from the background: the notification already alerted the user, so
    /// the end is only marked as handled. Returns false before the end and after the first call. The timer
    /// itself runs on in overtime.
    func signalEndIfDue(appActive: Bool) -> Bool {
        guard endDate != nil, !hasSignalledEnd, isOvertime else { return false }
        hasSignalledEnd = true
        notifications.cancel()
        return appActive
    }

    /// Takes the stored end date and total at launch; an end date already past shows overtime, silently.
    func restore(endDate: Date?, total: TimeInterval?) {
        guard let endDate, let total else {
            skip()
            return
        }
        self.endDate = endDate
        self.total = total
        hasSignalledEnd = endDate <= now()
    }

    /// Checks the set off through the workout log and starts the rest for its exercise, as the checkmark
    /// and the keyboard's Done both do. An already checked set, or one that can't be checked off, starts
    /// nothing. Returns the set to focus next.
    func checkOff(
        _ set: WorkoutSet, in workout: Workout, using log: WorkoutLog, defaultRest: Int
    ) throws -> WorkoutSet? {
        let wasChecked = set.isCompleted
        let next = try log.checkOffAndAdvance(set, in: workout)
        if !wasChecked, set.isCompleted {
            let exercise = set.workoutExercise?.exercise
            start(
                duration: Self.restSeconds(for: exercise, defaultRest: defaultRest),
                exerciseName: exercise?.name)
            checkedSet = set
        }
        return next
    }

    private func scheduleNotification() {
        if let endDate { notifications.schedule(at: endDate, exerciseName: exerciseName) }
    }
}
