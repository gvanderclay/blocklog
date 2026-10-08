import SwiftData
import SwiftUI

/// The tabs, and the in-progress workout as a full-screen cover over them.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var presentedWorkout: Workout?
    @State private var hasCheckedForInProgressWorkout = false

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
        .onAppear {
            // Only at launch: reopen straight into a workout left in progress.
            guard !hasCheckedForInProgressWorkout else { return }
            hasCheckedForInProgressWorkout = true
            presentedWorkout = WorkoutLog(context: modelContext).inProgressWorkout()
        }
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
