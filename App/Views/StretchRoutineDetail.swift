import SwiftData
import SwiftUI

/// A starter stretch routine's stretches with their holds, such as "30 s per side", why it is built that way, its
/// estimated time for one round, the rounds and Start that open the guided player, and Add to My Routines, which
/// copies it as a Stretch routine.
struct StretchRoutineDetail: View {
    let starterRoutine: StarterRoutine

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var rounds = StretchPlayer.roundChoices.lowerBound
    @State private var player: StretchPlayer?
    // Presented with sheet(item:), as the starter routine detail does.
    @State private var draft: RoutineDraft?
    @State private var saveFailed = false

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
            Section {
                Picker("Rounds", selection: $rounds) {
                    ForEach(StretchPlayer.roundChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .accessibilityIdentifier("stretch.rounds")
                Button("Start") {
                    player = StretchPlayer.start(starterRoutine, rounds: rounds, in: modelContext)
                }
                .disabled(!inProgressWorkouts.isEmpty)
                .accessibilityIdentifier("stretch.start")
            } footer: {
                if !inProgressWorkouts.isEmpty {
                    Text("Finish or discard the workout in progress first.")
                }
            }
            Section {
                Button("Add to My Routines") { addToRoutines() }
                    .accessibilityIdentifier("stretchRoutineDetail.addToRoutines")
            }
        }
        .navigationTitle(starterRoutine.name)
        .fullScreenCover(item: $player) { StretchPlayerScreen(player: $0) }
        .sheet(item: $draft) { RoutineEditor(newFrom: $0) }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private func addToRoutines() {
        do {
            draft = try StarterLibrary(context: modelContext).draft(of: starterRoutine)
        } catch {
            saveFailed = true
        }
    }
}
