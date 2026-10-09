import SwiftData
import SwiftUI

/// A template's exercises with their plans, such as "3 × 8–12", why it is built that way, and Start Workout,
/// Add to My Routines and, for a programme of several sessions, Add Programme.
struct TemplateDetail: View {
    let template: Template
    /// Shows the started workout in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    // Presented with sheet(item:): a sheet(isPresented:) closure read a stale, empty draft.
    @State private var draft: RoutineDraft?
    @State private var programmeAdded = false
    @State private var saveFailed = false

    private var programme: Template.Programme? {
        Template.programme(of: template, in: Template.bundled)
    }

    var body: some View {
        List {
            Section {
                Text(template.why)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                // The template never changes, so a position is a stable identity.
                ForEach(template.exercises.enumerated(), id: \.offset) { index, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.exercise)
                        Text(
                            RoutineLibrary.summary(setCount: entry.sets.count, target: entry.target)
                        )
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(
                            RoutineLibrary.spokenSummary(
                                setCount: entry.sets.count, target: entry.target)
                        )
                        .accessibilityIdentifier("templateDetail.exercise.\(index).summary")
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                Button("Start Workout") { start() }
                    .disabled(!inProgressWorkouts.isEmpty)
                    .accessibilityIdentifier("templateDetail.start")
                Button("Add to My Routines") { addToRoutines() }
                    .accessibilityIdentifier("templateDetail.addToRoutines")
            } footer: {
                if !inProgressWorkouts.isEmpty {
                    Text("Finish or discard the workout in progress first.")
                }
            }
            if let programme {
                Section {
                    Button(programmeAdded ? "Programme Added" : "Add Programme") {
                        add(programme)
                    }
                    .disabled(programmeAdded)
                    .accessibilityIdentifier("templateDetail.addProgramme")
                } footer: {
                    Text(
                        "Adds \(programme.sessions.map(\.name).formatted(.list(type: .and))) as routines."
                    )
                }
            }
        }
        .navigationTitle(template.name)
        .sheet(item: $draft) { draft in
            RoutineEditor(newFrom: draft)
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private func start() {
        do {
            if let started = try TemplateLibrary(context: modelContext).startWorkout(from: template)
            {
                present(started)
            }
        } catch {
            saveFailed = true
        }
    }

    private func addToRoutines() {
        do {
            draft = try TemplateLibrary(context: modelContext).draft(of: template)
        } catch {
            saveFailed = true
        }
    }

    private func add(_ programme: Template.Programme) {
        do {
            try TemplateLibrary(context: modelContext).addProgramme(programme)
            programmeAdded = true
        } catch {
            saveFailed = true
        }
    }
}
