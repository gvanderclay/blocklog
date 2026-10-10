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

/// "Workout N", the title, and the duration, completed sets and exercise count; after a program
/// workout, "Next in <program>: <routine>".
private struct FinishSummary: View {
    let summary: WorkoutSummary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: hasAppeared)
                    .symbolEffectsRemoved(reduceMotion)
                    .accessibilityHidden(true)
                Text("Workout \(summary.workoutNumber)")
                    .font(.title.weight(.bold))
                    .accessibilityIdentifier("summary.workoutNumber")
                Text(summary.title)
                    .font(.headline)
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
