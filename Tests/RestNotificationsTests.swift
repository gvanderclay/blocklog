import Foundation
import Testing
import UserNotifications

@testable import Blocklog

/// A clock tests advance by hand.
@MainActor
private final class FakeClock {
    var date = Date(timeIntervalSince1970: 1_000_000)
}

/// A notification center whose permission prompt and `add` can be held open, recording what reached it
/// in order.
@MainActor
private final class FakeCenter: RestNotificationCenter {
    var holdsAdds = false
    var holdsAuthorization = false
    private(set) var authorizationRequests = 0
    private var heldAuthorizations: [CheckedContinuation<Void, Never>] = []
    private var authorizationStarted: CheckedContinuation<Void, Never>?
    private(set) var log: [String] = []
    private var held: [CheckedContinuation<Void, Never>] = []
    private var addStarted: CheckedContinuation<Void, Never>?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        authorizationStarted?.resume()
        authorizationStarted = nil
        if holdsAuthorization { await withCheckedContinuation { heldAuthorizations.append($0) } }
        return true
    }

    /// Returns once the permission prompt is open.
    func waitForAuthorization() async {
        guard authorizationRequests == 0 else { return }
        await withCheckedContinuation { authorizationStarted = $0 }
    }

    func answerAuthorization() {
        holdsAuthorization = false
        heldAuthorizations.forEach { $0.resume() }
        heldAuthorizations = []
    }

    func add(_ request: UNNotificationRequest) async throws {
        log.append("add \(request.content.body)")
        addStarted?.resume()
        addStarted = nil
        if holdsAdds { await withCheckedContinuation { held.append($0) } }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        log.append("remove")
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    /// Returns once an `add` has begun.
    func waitForAdd() async {
        guard !log.contains(where: { $0.hasPrefix("add") }) else { return }
        await withCheckedContinuation { addStarted = $0 }
    }

    func releaseAdds() {
        holdsAdds = false
        held.forEach { $0.resume() }
        held = []
    }
}

@MainActor
struct RestNotificationsTests {
    private let center = FakeCenter()
    private let clock = FakeClock()
    private let notifications: RestNotifications

    init() {
        let clock = clock
        notifications = RestNotifications(center: center, now: { clock.date })
    }

    private var soon: Date { clock.date.addingTimeInterval(60) }

    @Test func scheduleAddsTheNotification() async {
        notifications.schedule(at: soon, exerciseName: "A")
        await notifications.settled()
        #expect(center.log == ["add Next set: A"])
    }

    @Test func aCancelDuringAnAddRemovesWhatTheAddScheduled() async {
        center.holdsAdds = true
        notifications.schedule(at: soon, exerciseName: "A")
        await center.waitForAdd()
        notifications.cancel()
        center.releaseAdds()
        await notifications.settled()
        #expect(center.log == ["add Next set: A", "remove"])
    }

    @Test func aNewerScheduleIsAddedAfterTheOlderOne() async {
        center.holdsAdds = true
        notifications.schedule(at: soon, exerciseName: "A")
        await center.waitForAdd()
        notifications.schedule(at: soon, exerciseName: "B")
        center.releaseAdds()
        await notifications.settled()
        #expect(center.log == ["add Next set: A", "add Next set: B"])
    }

    @Test func aScheduleThatEndedMeanwhileAddsNothing() async {
        notifications.schedule(at: clock.date.addingTimeInterval(-1), exerciseName: "A")
        await notifications.settled()
        #expect(center.log.isEmpty)
    }

    @Test func theFirstScheduleRequestsPermissionOnce() async {
        notifications.schedule(at: soon, exerciseName: "A")
        notifications.schedule(at: soon, exerciseName: "B")
        await notifications.settled()
        notifications.schedule(at: soon, exerciseName: "C")
        await notifications.settled()
        #expect(center.authorizationRequests == 1)
        // A was replaced by B before it ran.
        #expect(center.log == ["add Next set: B", "add Next set: C"])
    }

    @Test func aCancelWhilePermissionIsPendingPreventsScheduling() async {
        center.holdsAuthorization = true
        notifications.schedule(at: soon, exerciseName: "A")
        await center.waitForAuthorization()
        notifications.cancel()
        center.answerAuthorization()
        await notifications.settled()
        #expect(center.log == ["remove"])
    }

    @Test func anEndThatPassesDuringThePermissionPromptSchedulesNothing() async {
        center.holdsAuthorization = true
        notifications.schedule(at: soon, exerciseName: "A")
        await center.waitForAuthorization()
        clock.date.addTimeInterval(61)
        center.answerAuthorization()
        await notifications.settled()
        #expect(center.log.isEmpty)
    }
}
