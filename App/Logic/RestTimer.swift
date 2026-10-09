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

    /// What a rest looks like at one moment, for a view to render.
    struct Reading: Equatable {
        /// The whole seconds shown: the seconds left rounded up while counting down, the seconds past the
        /// end truncated in overtime; 0 when idle.
        let seconds: Int
        /// The seconds left rounded up, 0 from the end on. The countdown haptics and the ring's animation follow
        /// it, so they never fire from the overtime count.
        let countdownSeconds: Int
        /// True when the rest has run out and counts up.
        let isOvertime: Bool
        /// The share of the rest left, from 0 to 1.
        let progress: Double
    }

    /// The reading at the given time.
    func reading(at date: Date) -> Reading {
        let left = remaining(at: date)
        let overtime = isOvertime(at: date)
        let countdown = Int(left.rounded(.up))
        // A total of 0 (both ±15 presses before the clock moves) has no share left, so it reads 0, not NaN.
        let share = total.map { $0 > 0 ? left / $0 : 0 } ?? 0
        return Reading(
            seconds: overtime ? Int(self.overtime(at: date)) : countdown,
            countdownSeconds: countdown,
            isOvertime: overtime,
            progress: min(max(share, 0), 1))
    }

    /// Where a once-a-second timeline starts: the rest's start, in the past (a future anchor freezes a
    /// view until it arrives), so every tick falls on the end date's seconds.
    var timelineAnchor: Date {
        endDate.map { $0.addingTimeInterval(-(total ?? 0)) } ?? now()
    }

    /// The end date as stored between launches: seconds since 1970, and 0 when idle.
    var storedEnd: Double { endDate?.timeIntervalSince1970 ?? 0 }

    /// The total length as stored between launches; 0 when idle.
    var storedTotal: Double { total ?? 0 }

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

    /// Starts or restarts the countdown and schedules the notification. A given `checkedSet` becomes the
    /// set the change hint reads.
    func start(duration: Int, exerciseName: String? = nil, checkedSet: WorkoutSet? = nil) {
        if let checkedSet { self.checkedSet = checkedSet }
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

    /// Takes the values stored by `storedEnd` and `storedTotal`: an end date of 0 or less means no rest.
    func restore(storedEnd: Double, storedTotal: Double) {
        restore(
            endDate: storedEnd > 0 ? Date(timeIntervalSince1970: storedEnd) : nil,
            total: storedTotal)
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

    private func scheduleNotification() {
        if let endDate { notifications.schedule(at: endDate, exerciseName: exerciseName) }
    }
}
