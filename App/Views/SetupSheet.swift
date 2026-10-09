import SwiftUI

/// The block diagram for a set's weight at medium height, with the set row's − and + so the user can browse setups.
struct SetupSheet: View {
    let set: WorkoutSet
    let kind: ExerciseKind
    let onChange: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PowerBlockDiagram(weight: set.weight ?? 0)
                    WeightControl(
                        weight: set.weight, isAdded: kind == .bodyweightReps,
                        identifierPrefix: "diagram", onChange: onChange)
                }
                .padding()
            }
            .navigationTitle("Block Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("diagram.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Stepping a bodyweight set down to BW leaves nothing to draw.
        .onChange(of: set.weight) { if set.weight == nil { dismiss() } }
    }
}
