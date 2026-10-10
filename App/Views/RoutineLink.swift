import SwiftUI

/// A row opening a routine's detail: its name and, for a routine that isn't of the Sets format, its format, such as
/// "Timed AMRAP · 20 min".
struct RoutineLink: View {
    let routine: Routine

    var body: some View {
        let format = routine.format
        NavigationLink(value: routine) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                if let summary = format.summary {
                    Text(summary)
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(routine.name)
        .accessibilityValue(format.spokenSummary ?? "")
    }
}
