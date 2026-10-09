import SwiftUI

/// The block diagram for a set's weight at medium height, with the set row's − and + so the user can browse setups.
struct SetupSheet: View {
    let set: WorkoutSet
    let onChange: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let values = set.values
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PowerBlockDiagram(weight: values.weight ?? 0)
                    WeightControl(
                        weight: values.weight, isAdded: values.weightIsAdded,
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
        .onChange(of: set.values.weight) { if set.values.weight == nil { dismiss() } }
    }
}
