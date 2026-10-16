import SwiftUI

/// A row opening a routine's detail: its name and its summary, such as "6 exercises" or "Timed AMRAP · 20 min".
struct RoutineLink: View {
    let routine: Routine

    var body: some View {
        let format = routine.format
        NavigationLink(value: routine) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                Text(routine.listSummary)
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(routine.name)
        .accessibilityValue(format.spokenSummary ?? routine.listSummary)
    }
}
