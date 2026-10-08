import Foundation
import Testing
import UserNotifications

@testable import Blocklog

/// A notification center whose `add` can be held open, recording what reached it in order.
@MainActor
private final class FakeCenter: RestNotificationCenter {
    var holdsAdds = false
    private(set) var log: [String] = []
    private var held: [CheckedContinuation<Void, Never>] = []
    private var addStarted: CheckedContinuation<Void, Never>?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

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
    private let notifications: RestNotifications

    init() {
        notifications = RestNotifications(center: center, requestsPermission: false)
    }

    private var soon: Date { .now.addingTimeInterval(60) }

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
        notifications.schedule(at: .now.addingTimeInterval(-1), exerciseName: "A")
        await notifications.settled()
        #expect(center.log.isEmpty)
    }
}
