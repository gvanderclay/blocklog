import SwiftData
import SwiftUI

/// Finish: a title and Save, then a short summary in the same sheet.
struct FinishSheet: View {
    let workout: Workout
    /// Closes the summary and the workout screen behind it.
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimer.self) private var restTimer
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var summary: WorkoutSummary?
    @State private var saveFailed = false
    @State private var isAskingToUpdateRoutine = false

    init(workout: Workout, onDone: @escaping () -> Void) {
        self.workout = workout
        self.onDone = onDone
        self.title = workout.title
    }

    var body: some View {
        let unchecked = WorkoutLog.uncheckedSetCount(workout)
        NavigationStack {
            if let summary {
                FinishSummary(summary: summary)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", action: onDone)
                                .accessibilityIdentifier("summary.done")
                        }
                    }
                    .transition(.opacity)
            } else {
                Form {
                    Section {
                        TextField("Title", text: $title, axis: .vertical)
                            .accessibilityIdentifier("finish.title")
                    } footer: {
                        if !WorkoutLog.hasCheckedSet(workout) {
                            Text("Check off at least one set to save this workout.")
                        } else if unchecked > 0 {
                            Text(
                                unchecked == 1
                                    ? "1 unchecked set won’t be saved."
                                    : "\(unchecked) unchecked sets won’t be saved."
                            )
                            .accessibilityIdentifier("finish.uncheckedNote")
                        }
                    }
                }
                .navigationTitle("Finish Workout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("finish.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do {
                                let saved = try WorkoutLog(
                                    context: modelContext, restTimer: restTimer
                                ).finish(
                                    workout, title: title)
                                withAnimation { summary = saved }
                                // The workout is saved; the alert only decides whether the routine changes.
                                isAskingToUpdateRoutine =
                                    saved != nil && RoutineDifference.isStructural(workout)
                            } catch {
                                saveFailed = true
                            }
                        }
                        .disabled(!WorkoutLog.hasCheckedSet(workout))
                        .accessibilityIdentifier("finish.save")
                    }
                }
            }
        }
        // Medium, so a short sheet isn't mostly blank; the summary shares the grouped background with the form, so
        // Save cross-fades the content rather than cutting between two backgrounds.
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemGroupedBackground))
        // Once saved, the workout is finished: leaving goes through Done.
        .interactiveDismissDisabled(summary != nil)
        .saveFailedAlert(isPresented: $saveFailed)
        .alert("Update “\(workout.routine?.name ?? "")”?", isPresented: $isAskingToUpdateRoutine) {
            Button("Update Routine") {
                guard let routine = workout.routine else { return }
                do {
                    try RoutineDifference(context: modelContext).update(routine, toMatch: workout)
                } catch {
                    saveFailed = true
                }
            }
            .accessibilityIdentifier("updateRoutine.accept")
            Button("Keep Routine", role: .cancel) {}
                .accessibilityIdentifier("updateRoutine.decline")
        } message: {
            Text("You changed exercises or sets. Update the routine to match this workout?")
        }
    }
}

/// The title, "Workout N", and the duration, completed sets and exercise count; after a program
/// workout, "Next in <program>: <routine>".
private struct FinishSummary: View {
    let summary: WorkoutSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DoneSeal()
                Text(summary.title)
                    .font(.title.weight(.bold))
                    .accessibilityIdentifier("summary.title")
                Text("Workout \(summary.workoutNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("summary.workoutNumber")
                let layout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 16))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                layout { stats }
                    .padding(.top, 8)
                if let next = summary.nextInProgram {
                    Text("Next in \(next.program): \(next.routine)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .accessibilityIdentifier("finish.upNext")
                }
            }
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
        }
        // Centred while it fits, as the other summaries are.
        .defaultScrollAnchor(.center, for: .alignment)
        .navigationTitle("Workout Saved")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear { hasAppeared = true }
    }

    @ViewBuilder private var stats: some View {
        SummaryStat(
            value: summary.duration.formatted(
                .units(allowed: [.hours, .minutes], width: .abbreviated)),
            label: "Total Time")
        SummaryStat(value: summary.completedSetCount.formatted(), label: "Sets")
        SummaryStat(value: summary.exerciseCount.formatted(), label: "Exercises")
    }
}

/// One summary number with its label under it.
private struct SummaryStat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title)
                .fontDesign(.rounded)
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
