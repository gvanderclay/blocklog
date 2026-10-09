import SwiftUI

/// A row opening a template's detail: its name, exercise count and estimated time.
struct TemplateLink: View {
    let template: Template
    let present: (RoutineStart.Started) -> Void

    @AppStorage("defaultRestSeconds") private var defaultRest = 90

    var body: some View {
        NavigationLink {
            TemplateDetail(template: template, present: present)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                Text(template.summary(restSeconds: defaultRest))
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
