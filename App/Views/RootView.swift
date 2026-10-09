import SwiftData
import SwiftUI

/// The tabs, and the in-progress workout as a full-screen cover over them.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var presentedWorkout: Workout?
    @State private var hasCheckedForInProgressWorkout = false
    @State private var restTimer = RestTimer()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timerSoundEnabled") private var timerSoundEnabled = true
    /// Owned here with the timer, so the end of a rest is announced whichever screen is showing.
    @State private var chime = RestChime()
    @State private var endCount = 0
    /// The running rest, kept so a relaunch mid-rest shows the time left. Zero means none.
    @AppStorage("restEndDate") private var storedRestEnd = 0.0
    @AppStorage("restTotalSeconds") private var storedRestTotal = 0.0

    var body: some View {
        TabView {
            Tab("Workout", systemImage: "dumbbell.fill") {
                WorkoutTab { presentedWorkout = $0 }
            }
            .accessibilityIdentifier("tabs.workout")
            Tab("History", systemImage: "clock.arrow.circlepath") {
                PlaceholderTab(title: "History", systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("tabs.history")
            Tab("Settings", systemImage: "gearshape") {
                SettingsTab()
            }
            .accessibilityIdentifier("tabs.settings")
        }
        .fullScreenCover(item: $presentedWorkout) { workout in
            WorkoutScreen(workout: workout)
        }
        // After the cover, which gets only the environment set outside it.
        .environment(restTimer)
        .onChange(of: restTimer.endDate) { storeRest() }
        .sensoryFeedback(.warning, trigger: endCount)
        // One sleep until the end date, not a polling loop; a new end date (±15, restart) restarts it.
        .task(id: restTimer.endDate) {
            while restTimer.remaining > 0 {
                do { try await Task.sleep(for: .seconds(restTimer.remaining)) } catch { return }
            }
            announceEnd(appActive: scenePhase == .active)
        }
        .onChange(of: scenePhase) {
            // A rest that ended in the background was announced by its notification: show overtime silently.
            if scenePhase == .active { announceEnd(appActive: false) }
        }
        .onAppear {
            // Only at launch: reopen straight into a workout left in progress.
            guard !hasCheckedForInProgressWorkout else { return }
            hasCheckedForInProgressWorkout = true
            restTimer.restore(storedEnd: storedRestEnd, storedTotal: storedRestTotal)
            storeRest()
            presentedWorkout = WorkoutLog(context: modelContext).inProgressWorkout()
        }
    }
}

extension RootView {
    /// The warning haptic and the chime, once, when a rest ends while the app is in the foreground.
    private func announceEnd(appActive: Bool) {
        guard restTimer.signalEndIfDue(appActive: appActive) else { return }
        endCount += 1
        if timerSoundEnabled { chime.play() }
    }

    private func storeRest() {
        storedRestEnd = restTimer.storedEnd
        storedRestTotal = restTimer.storedTotal
    }
}

/// A tab a later phase fills in.
private struct PlaceholderTab: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title, systemImage: systemImage,
                description: Text("This arrives in a later update.")
            )
            .navigationTitle(title)
        }
    }
}
