import Foundation
import UserNotifications

/// The system notification a rest timer schedules, behind a protocol so tests can replace it.
@MainActor
protocol RestNotifying {
    /// Schedules the one rest notification for the date, replacing any scheduled one.
    func schedule(at date: Date, exerciseName: String?)
    /// Removes the scheduled and the delivered rest notification.
    func cancel()
}

/// The part of `UNUserNotificationCenter` the rest notification uses, so tests can replace it.
@MainActor
protocol RestNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: RestNotificationCenter {}

/// One notification, identifier `rest-timer`, "Rest over". Every change to the notification center runs
/// in order, each after the one before, so a cancel or a newer schedule can't be overtaken by an add
/// still in flight.
@MainActor
final class RestNotifications: RestNotifying {
    static let identifier = "rest-timer"

    private let center: any RestNotificationCenter
    private let foregroundSilencer = ForegroundSilencer()
    /// False in unit tests, which must not raise the system's permission alert.
    private let requestsPermission: Bool
    private var hasRequestedPermission = false
    /// The last queued operation; the next one waits for it.
    private var tail: Task<Void, Never>?
    /// Bumped by every schedule and cancel, so a queued schedule that was replaced does nothing.
    private var generation = 0

    init(
        center: any RestNotificationCenter = UNUserNotificationCenter.current(),
        requestsPermission: Bool = true
    ) {
        self.center = center
        self.requestsPermission = requestsPermission
        (center as? UNUserNotificationCenter)?.delegate = foregroundSilencer
    }

    /// Returns once every queued operation has run.
    func settled() async { await tail?.value }

    func schedule(at date: Date, exerciseName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = exerciseName.map { "Next set: \($0)" } ?? "Time for your next set"
        // The Timer Sound setting is read here so a ±15 reschedule keeps the current choice.
        let soundOn = UserDefaults.standard.object(forKey: "timerSoundEnabled") as? Bool ?? true
        content.sound =
            soundOn ? UNNotificationSound(named: UNNotificationSoundName("rest-chime.caf")) : nil
        let askFirst = requestsPermission && !hasRequestedPermission
        hasRequestedPermission = hasRequestedPermission || requestsPermission
        generation += 1
        let mine = generation
        enqueue { [self] in
            if askFirst { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
            // The trigger is built only now, from the time left, so a wait on the permission prompt
            // doesn't make it late; an end that passed meanwhile schedules nothing.
            let remaining = date.timeIntervalSinceNow
            guard mine == generation, remaining > 0 else { return }
            let request = UNNotificationRequest(
                identifier: Self.identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false))
            try? await center.add(request)
        }
    }

    func cancel() {
        generation += 1
        enqueue { [self] in
            center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await operation()
        }
    }
}

/// In the foreground the app handles the end of rest itself, so a notification shows nothing.
@MainActor
private final class ForegroundSilencer: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [] }
}
