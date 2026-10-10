import SwiftData
import SwiftUI

/// A routine's format, unless it is Sets, and its exercises with their plans, such as "3 × 8–12", plus Edit and a
/// start by format: Start Workout for Sets, or the rounds and Start that open the stretch player for Stretch. A
/// Timed AMRAP routine offers no start until its player exists.
struct RoutineDetail: View {
    let routine: Routine
    /// Shows the started workout, with its progressions, in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var isEditing = false
    @State private var saveFailed = false
    @State private var rounds = StretchPlayer.roundChoices.lowerBound
    @State private var player: StretchPlayer?

    var body: some View {
        let format = routine.format
        List {
            if let summary = format.summary {
                Section {
                    Text(summary)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .accessibilityLabel(format.spokenSummary ?? summary)
                        .accessibilityIdentifier("routineDetail.format")
                }
            }
            Section {
                ForEach(RoutineLibrary.orderedExercises(of: routine).enumerated(), id: \.element.id)
                {
                    index, routineExercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routineExercise.exercise?.name ?? "Exercise")
                        Text(RoutineLibrary.summary(of: routineExercise))
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    // .ignore with an explicit label and value: .combine reads the row twice.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(routineExercise.exercise?.name ?? "Exercise")
                    .accessibilityValue(RoutineLibrary.spokenSummary(of: routineExercise))
                    .accessibilityIdentifier("routineDetail.exercise.\(index)")
                }
            }
            if format.kind != .timedAMRAP {
                Section {
                    if format == .stretch {
                        Picker("Rounds", selection: $rounds) {
                            ForEach(StretchPlayer.roundChoices, id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }
                        .accessibilityIdentifier("routineDetail.rounds")
                    }
                    Button(format == .stretch ? "Start" : "Start Workout") { start() }
                        .disabled(!inProgressWorkouts.isEmpty)
                        .accessibilityIdentifier("routineDetail.start")
                } footer: {
                    if !inProgressWorkouts.isEmpty {
                        Text("Finish or discard the workout in progress first.")
                    }
                }
            }
        }
        .navigationTitle(routine.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .accessibilityIdentifier("routineDetail.edit")
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineEditor(routine: routine)
        }
        .saveFailedAlert(isPresented: $saveFailed)
        .fullScreenCover(item: $player) { StretchPlayerScreen(player: $0) }
    }

    private func start() {
        if routine.format == .stretch {
            player = StretchPlayer.start(routine, rounds: rounds, in: modelContext)
            return
        }
        do {
            if let started = try RoutineStart(context: modelContext).startWorkout(from: routine) {
                present(started)
            }
        } catch {
            saveFailed = true
        }
    }
}
