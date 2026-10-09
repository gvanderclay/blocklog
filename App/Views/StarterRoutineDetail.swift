import SwiftData
import SwiftUI

/// A starter routine's exercises with their plans, such as "3 × 8–12", why it is built that way, and Start Workout,
/// Add to My Routines and, for a programme of several routines, Add Programme.
struct StarterRoutineDetail: View {
    let starterRoutine: StarterRoutine
    /// Shows the started workout in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    // Presented with sheet(item:): a sheet(isPresented:) closure read a stale, empty draft.
    @State private var draft: RoutineDraft?
    @State private var programmeAdded = false
    @State private var saveFailed = false

    private var programme: StarterProgramme? {
        StarterRoutine.programme(of: starterRoutine, in: StarterRoutine.bundled)
    }

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
                        .accessibilityIdentifier("starterRoutineDetail.exercise.\(index).summary")
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                Button("Start Workout") { start() }
                    .disabled(!inProgressWorkouts.isEmpty)
                    .accessibilityIdentifier("starterRoutineDetail.start")
                Button("Add to My Routines") { addToRoutines() }
                    .accessibilityIdentifier("starterRoutineDetail.addToRoutines")
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
                    .accessibilityIdentifier("starterRoutineDetail.addProgramme")
                } footer: {
                    Text(
                        "Adds \(programme.routines.map(\.name).formatted(.list(type: .and))) as routines."
                    )
                }
            }
        }
        .navigationTitle(starterRoutine.name)
        .sheet(item: $draft) { draft in
            RoutineEditor(newFrom: draft)
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private func start() {
        do {
            if let started = try StarterLibrary(context: modelContext).startWorkout(
                from: starterRoutine)
            {
                present(started)
            }
        } catch {
            saveFailed = true
        }
    }

    private func addToRoutines() {
        do {
            draft = try StarterLibrary(context: modelContext).draft(of: starterRoutine)
        } catch {
            saveFailed = true
        }
    }

    private func add(_ programme: StarterProgramme) {
        do {
            try StarterLibrary(context: modelContext).addProgramme(programme)
            programmeAdded = true
        } catch {
            saveFailed = true
        }
    }
}
