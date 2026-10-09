import SwiftData
import SwiftUI

/// One set: its type label, the fields its exercise kind records, and a check-off button.
/// Swipe left deletes it; a long press opens its set-type, duplicate and delete menu.
struct SetRow: View {
    let set: WorkoutSet
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// The set's workout, which decides where focus goes after the set is checked off.
    let workout: Workout
    /// Called after the set is deleted, so the screen plays the delete haptic.
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimer.self) private var restTimer
    @AppStorage("defaultRestSeconds") private var defaultRest = 90
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The reps and seconds fields grow with the text size, so a number and the placeholder never clip.
    @ScaledMetric(relativeTo: .body) private var fieldWidth = 64
    @State private var checkOffCount = 0
    @State private var previousCopyCount = 0
    @State private var saveFailed = false
    @State private var showsDiagram = false

    var body: some View {
        @Bindable var set = set
        let label = SetNumbering.label(of: set)
        let kind = set.workoutExercise?.exercise?.kind ?? .weightReps
        let previous = PreviousSetLookup(context: modelContext).previous(for: set)
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 4))
        VStack(alignment: .leading, spacing: 0) {
            layout {
                Menu {
                    typeButtons(identifier: "setMenu.type")
                } label: {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Set type")
                .accessibilityValue(label)
                .accessibilityIdentifier("\(identifierPrefix).typeMenu")
                previousValue(previous, kind: kind)
                switch kind {
                case .weightReps:
                    if let weight = set.weight {
                        WeightControl(weight: weight, identifierPrefix: identifierPrefix) {
                            changeWeight($0, kind: kind)
                        }
                    }
                case .bodyweightReps:
                    WeightControl(
                        weight: set.weight, isAdded: true, identifierPrefix: identifierPrefix
                    ) {
                        changeWeight($0, kind: kind)
                    }
                case .duration:
                    EmptyView()
                }
                Spacer(minLength: 0)
                if kind == .duration {
                    HStack(spacing: 4) {
                        TextField("Seconds", text: $set.durationText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .frame(width: fieldWidth * 1.5)
                            .frame(minHeight: 44)
                            .focused(focusedRepsSetID, equals: set.id)
                            .accessibilityLabel("Seconds")
                            .accessibilityIdentifier("\(identifierPrefix).duration")
                        // The field's own label says "Seconds", so the unit isn't read a second time.
                        Text("s").foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                } else {
                    // A workout from a routine shows the exercise's rep range, such as "8–12", in an empty field.
                    TextField(
                        set.workoutExercise.flatMap(RoutineStart.repRangeText(for:)) ?? "Reps",
                        text: $set.repsText
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .frame(width: fieldWidth)
                    .frame(minHeight: 44)
                    .focused(focusedRepsSetID, equals: set.id)
                    .accessibilityLabel("Reps")
                    .accessibilityIdentifier("\(identifierPrefix).reps")
                }
                Button {
                    withAnimation {
                        if set.isCompleted {
                            attempt { try $0.toggleCompleted(set) }
                        } else {
                            attempt(restTimer: restTimer) {
                                focusedRepsSetID.wrappedValue = try $0.checkOff(
                                    set, in: workout, defaultRest: defaultRest)?.id
                            }
                        }
                    }
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(
                            set.isCompleted ? Color.green : Color.secondary
                        )
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: checkOffCount)
                        .symbolEffectsRemoved(reduceMotion)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .disabled(!set.isCompleted && !WorkoutLog.canCheckOff(set))
                .accessibilityLabel("Set \(label)")
                .accessibilityValue(set.isCompleted ? "done" : "not done")
                .accessibilityIdentifier("\(identifierPrefix).check")
            }
            setupLine(kind: kind)
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.15) : nil)
        .sensoryFeedback(trigger: set.isCompleted) { _, isCompleted in
            isCompleted ? .success : .impact(weight: .light)
        }
        // Also fires when the keyboard's Done checks the set off, so the bounce matches the checkmark.
        .onChange(of: set.isCompleted) { if set.isCompleted { checkOffCount += 1 } }
        .sensoryFeedback(.selection, trigger: set.setType)
        .sensoryFeedback(.selection, trigger: previousCopyCount)
        .swipeActions(edge: .trailing) {
            deleteButton
        }
        .contextMenu {
            Menu("Set Type", systemImage: "list.number") {
                typeButtons(identifier: "setMenu.type")
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                withAnimation(reduceMotion ? nil : .default) {
                    attempt { try $0.duplicateSet(set) }
                }
            }
            .accessibilityIdentifier("setMenu.duplicate")
            deleteButton
        }
        .onChange(of: set.reps) {
            attempt { try $0.context.saveOrRollBack() }
        }
        .onChange(of: set.durationSeconds) {
            attempt { try $0.context.saveOrRollBack() }
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// The small line under the inputs that opens the block diagram; nothing without a weight.
    @ViewBuilder
    private func setupLine(kind: ExerciseKind) -> some View {
        if let line = PowerBlockTable.setupLine(for: set.weight) {
            Button {
                showsDiagram = true
            } label: {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)  // not .secondary, which fades the tint inside a button
                    // The tap area grows to 44 pt by overlapping neighbouring space, not by adding row height.
                    .padding(.vertical, 14)
                    .contentShape([.interaction, .accessibility], .rect)
                    .padding(.vertical, -14)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the block diagram")
            .accessibilityIdentifier("\(identifierPrefix).setup")
            .sheet(isPresented: $showsDiagram) {
                SetupSheet(set: set, kind: kind) { changeWeight($0, kind: kind) }
            }
        }
    }

    /// Sets the weight from the row's control or the diagram sheet's, animated so the numbers roll.
    private func changeWeight(_ newWeight: Double?, kind: ExerciseKind) {
        withAnimation {
            if kind == .bodyweightReps {
                attempt { try $0.setAddedWeight(newWeight, of: set) }
            } else if let newWeight {
                attempt { try $0.setWeight(newWeight, of: set) }
            }
        }
    }

    /// Last time's values: a button that copies them into an unchecked set, or plain text when it can't.
    @ViewBuilder
    private func previousValue(_ previous: PreviousValues?, kind: ExerciseKind) -> some View {
        let text = previous?.text(for: kind) ?? "—"
        let label = Text(text)
            .font(.footnote)
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(Color.secondary)  // not .secondary, which fades the tint inside a button
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            // `.accessibility` too: without it the element is only as big as the text, a hit-area audit failure.
            .contentShape([.interaction, .accessibility], .rect)
        Group {
            if previous != nil, !set.isCompleted {
                Button {
                    copyPrevious()
                } label: {
                    label
                }
                .buttonStyle(.plain)  // keeps the secondary grey; .borderless tints the label
                .accessibilityHint("Copies last time's values")
            } else {
                label
            }
        }
        .accessibilityLabel("Previous")
        .accessibilityValue(previous?.spokenText(for: kind) ?? "none")
        .accessibilityIdentifier("\(identifierPrefix).previous")
    }

    /// Copies the previous values in, animated so the weight rolls. The selection tick comes from the weight
    /// control when the weight changes, so this ticks only when the copy leaves the weight alone.
    private func copyPrevious() {
        let weightBefore = set.weight
        var copied = false
        withAnimation {
            attempt { copied = try $0.copyPrevious(to: set) }
        }
        if copied, set.weight == weightBefore { previousCopyCount += 1 }
    }

    private var deleteButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(reduceMotion ? nil : .default) {
                attempt { try $0.deleteSet(set) }
            }
            onDelete()
        }
        .accessibilityIdentifier("setMenu.delete")
    }

    /// One button per set type, the current one checked.
    private func typeButtons(identifier: String) -> some View {
        ForEach(SetType.allCases, id: \.self) { type in
            Button {
                attempt { try $0.setType(type, of: set) }
            } label: {
                if set.setType == type {
                    Label(type.title, systemImage: "checkmark")
                } else {
                    Text(type.title)
                }
            }
            .accessibilityIdentifier("\(identifier).\(type.rawValue)")
        }
    }

    /// Runs a change through the workout log, showing the alert if it fails to save.
    private func attempt(
        restTimer: RestTimer? = nil, _ change: (WorkoutLog) throws -> Void
    ) {
        do {
            try change(WorkoutLog(context: modelContext, restTimer: restTimer))
        } catch {
            saveFailed = true
        }
    }
}
