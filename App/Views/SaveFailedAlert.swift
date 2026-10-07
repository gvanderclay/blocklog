import SwiftUI

extension View {
    /// The plain alert a view shows when a `WorkoutLog` change failed to save.
    func saveFailedAlert(isPresented: Binding<Bool>) -> some View {
        alert("Couldn’t Save", isPresented: isPresented) {
            Button("OK") {}
                .accessibilityIdentifier("saveFailed.ok")
        } message: {
            Text("Your last change wasn’t saved. Try again.")
        }
    }
}
