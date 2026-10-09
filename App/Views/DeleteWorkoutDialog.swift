import SwiftUI

extension View {
    /// Asks "Delete “<title>”? This can't be undone." for the workout, and runs `delete` when confirmed.
    func deleteWorkoutDialog(item: Binding<Workout?>, delete: @escaping (Workout) -> Void)
        -> some View
    {
        confirmationDialog(
            "Delete “\(item.wrappedValue?.title ?? "")”?", item: item, titleVisibility: .visible
        ) { workout in
            Button("Delete Workout", role: .destructive) { delete(workout) }
                .accessibilityIdentifier("deleteWorkout.confirm")
        } message: { _ in
            Text("This can’t be undone.")
        }
    }
}
