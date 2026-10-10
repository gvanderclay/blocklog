import SwiftUI

/// A starter stretch routine's stretches with their holds, such as "30 s per side", why it is built that way, and its
/// estimated time for one round.
struct StretchRoutineDetail: View {
    let starterRoutine: StarterRoutine

    var body: some View {
        List {
            Section {
                Text(starterRoutine.why)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                // The starter routine never changes, so a position is a stable identity.
                ForEach(starterRoutine.exercises.enumerated(), id: \.offset) { index, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.exercise)
                        Text(entry.holdSummary)
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(entry.exercise)
                    .accessibilityValue(entry.spokenHoldSummary)
                    .accessibilityIdentifier("stretchRoutineDetail.exercise.\(index)")
                }
            } footer: {
                Text(
                    "About \(starterRoutine.estimatedMinutes(restSeconds: 0)) min for one round, plus any pauses between sides."
                )
                .accessibilityIdentifier("stretchRoutineDetail.estimate")
            }
        }
        .navigationTitle(starterRoutine.name)
    }
}
