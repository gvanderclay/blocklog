import SwiftUI

/// The bundled templates: each programme's sessions, then the one-off workouts. A row opens its detail.
struct TemplatesSheet: View {
    /// Shows a workout started from a template.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Template.programmes(in: Template.bundled)) { programme in
                    Section("\(programme.name) Programme") {
                        ForEach(programme.sessions) { template in
                            TemplateLink(template: template, present: present)
                                .accessibilityIdentifier("templates.row.\(template.name)")
                        }
                    }
                }
                Section("One-Off Workouts") {
                    ForEach(Template.oneOffs(in: Template.bundled)) { template in
                        TemplateLink(template: template, present: present)
                            .accessibilityIdentifier("templates.row.\(template.name)")
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("templates.done")
                }
            }
        }
    }
}
