import SwiftUI

/// The bundled starter routines: each program's routines, the standalone ones, then the stretch routines. A row
/// opens its detail.
struct StarterRoutinesSheet: View {
    /// Shows a workout started from a starter routine.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(StarterRoutine.programs(in: StarterRoutine.bundled)) { program in
                    Section("\(program.name) Program") {
                        ForEach(program.routines) { starterRoutine in
                            StarterRoutineLink(starterRoutine: starterRoutine, present: present)
                                .accessibilityIdentifier(
                                    "starterRoutines.row.\(starterRoutine.name)")
                        }
                    }
                }
                Section("Routines") {
                    ForEach(StarterRoutine.standalone(in: StarterRoutine.bundled)) {
                        starterRoutine in
                        StarterRoutineLink(starterRoutine: starterRoutine, present: present)
                            .accessibilityIdentifier("starterRoutines.row.\(starterRoutine.name)")
                    }
                }
                Section("Stretching") {
                    ForEach(StarterRoutine.stretching(in: StarterRoutine.bundled)) {
                        starterRoutine in
                        StarterRoutineLink(starterRoutine: starterRoutine, present: present)
                            .accessibilityIdentifier("starterRoutines.row.\(starterRoutine.name)")
                    }
                }
            }
            .navigationTitle("Starter Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("starterRoutines.done")
                }
            }
        }
    }
}
