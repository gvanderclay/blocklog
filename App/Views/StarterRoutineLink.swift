import SwiftUI

/// A row opening a starter routine's detail: its name, exercise count and estimated time.
struct StarterRoutineLink: View {
    let starterRoutine: StarterRoutine
    let present: (RoutineStart.Started) -> Void

    @AppStorage("defaultRestSeconds") private var defaultRest = 90

    var body: some View {
        NavigationLink {
            StarterRoutineDetail(starterRoutine: starterRoutine, present: present)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(starterRoutine.name)
                Text(starterRoutine.summary(restSeconds: defaultRest))
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
