import SwiftData
import SwiftUI

/// One set: a one-line summary, or, when it is the workout's open set, its type menu, Previous with Copy,
/// weight, reps (or seconds) and a check-off button. Swipe left deletes it; a long press opens its set-type,
/// duplicate and delete menu.
struct SetRow: View {
    let set: WorkoutSet
    /// `workout.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let focusedRepsSetID: FocusState<UUID?>.Binding
    /// The id of the set shown open; view state, never stored.
    @Binding var openSetID: UUID?
    /// Moves VoiceOver to a newly opened set, whose check button (where focus was) is gone.
    let accessibilityFocus: AccessibilityFocusState<UUID?>.Binding
    /// The set's workout, which decides which set opens after a check-off or a delete.
    let workout: Workout
    /// Decides whether the weight shows highlighted, and hears when the user ends the highlight.
    @Binding var progressions: AppliedProgressions
    /// Called after the set is deleted, so the screen plays the delete haptic.
    let onDelete: () -> Void
    /// Called when checking the set off leaves no unchecked set in the workout.
    let onAllSetsDone: () -> Void
    /// True when the row edits a finished workout: the set counts as done, so there is no check-off control,
    /// Previous has no Copy, and a set missing its required values shows a red outline and a hint.
    var isEditingPast = false
    /// Opens the stopwatch for the set; nil where there is none (past editing).
    var onStartStopwatch: ((WorkoutSet) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimer.self) private var restTimer
    @AppStorage("defaultRestSeconds") private var defaultRest = 90
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Grow with the text size, so a number and the placeholder never clip.
    @ScaledMetric(relativeTo: .title3) private var fieldWidth: CGFloat = 58
    @State private var missingValueCount = 0
    @State private var checkOffCount = 0
    @State private var previousCopyCount = 0
    @State private var saveFailed = false

    private var isOpen: Bool { openSetID == set.id }

    /// The focus value of the workout screen's hidden number field. A check-off parks the keyboard there
    /// while the checked set's field goes away, and the next set's field takes it back as it appears, so the
    /// keyboard never drops between sets.
    static let keyboardHolderID = UUID()

    var body: some View {
        @Bindable var set = set
        let spokenName = SetNumbering.spokenName(of: set)
        let hint = isEditingPast ? PastWorkoutEditing.hint(for: set) : nil
        // One root, not a Group, so the List row stays a single row when it switches between its two forms.
        VStack(alignment: .leading, spacing: 0) {
            // `.identity`: the List resizes the row at once, so the default cross-fade left it blank for a moment.
            if isOpen {
                openSet(spokenName: spokenName, hint: hint)
                    .transition(.identity)
            } else {
                HStack(spacing: 8) {
                    summary(spokenName: spokenName, hint: hint)
                    stopwatchButton(spokenName: spokenName)
                }
                .transition(.identity)
            }
        }
        .overlay {
            if isEditingPast, !PastWorkoutEditing.isValid(set) {
                RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2)
                    .padding(-4)
                    .allowsHitTesting(false)
            }
        }
        // Only a done summary is tinted; the open set stands out by being the one expanded row.
        .listRowBackground(
            set.isCompleted && !isEditingPast && !isOpen ? Color.green.opacity(0.15) : nil
        )
        .sensoryFeedback(trigger: set.isCompleted) { _, isCompleted in
            guard !isEditingPast else { return nil }
            return isCompleted ? .success : .impact(weight: .light)
        }
        // Also fires when the keyboard's Done checks the set off, so the bounce matches the checkmark.
        .onChange(of: set.isCompleted) {
            progressions.checkedOff(set)
            if set.isCompleted { checkOffCount += 1 }
        }
        .onChange(of: set.values.weight) { progressions.weightChanged(of: set) }
        .sensoryFeedback(.impact(weight: .light), trigger: missingValueCount)
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
                    attempt {
                        if let copy = try $0.duplicateSet(set, completed: isEditingPast) {
                            openSetID = copy.id
                        }
                    }
                }
            }
            .accessibilityIdentifier("setMenu.duplicate")
            deleteButton
        }
        .onChange(of: set.reps) { saveEdit() }
        .onChange(of: set.durationSeconds) { saveEdit() }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    // MARK: Open set

    private func openSet(spokenName: String, hint: String?) -> some View {
        @Bindable var set = set
        let values = set.values
        let type = set.workoutExercise?.exercise?.type ?? .weightReps
        let titles = SetValues.fieldTitles(for: type)
        let placeholder =
            values.isFieldEmpty && (!set.isCompleted || isEditingPast)
            ? SetPlaceholder(context: modelContext).value(for: set) : nil
        let stacks = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
        return VStack(alignment: .leading, spacing: 0) {
            Menu {
                typeButtons(identifier: "setMenu.type")
            } label: {
                HStack(spacing: 6) {
                    Text(spokenName).font(.headline).foregroundStyle(Color.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel("\(spokenName) type")
            .accessibilityValue(set.setType.title)
            .accessibilityIdentifier("\(identifierPrefix).typeMenu")
            .accessibilityFocused(accessibilityFocus, equals: set.id)
            previousValue(PreviousSetLookup(context: modelContext).previousNumbers(for: set))
            layout {
                switch values {
                case .weightReps(let weight, _):
                    labelled(titles.weight) {
                        WeightControl(
                            weight: weight, isHighlighted: progressions.isHighlighted(set),
                            identifierPrefix: identifierPrefix, spokenSetName: spokenName
                        ) {
                            changeWeight($0)
                        }
                        .font(.title3)
                    }
                case .bodyweightReps(let addedWeight, _):
                    labelled(titles.weight) {
                        WeightControl(
                            weight: addedWeight, isAdded: true,
                            isHighlighted: progressions.isHighlighted(set),
                            identifierPrefix: identifierPrefix, spokenSetName: spokenName
                        ) {
                            changeWeight($0)
                        }
                        .font(.title3)
                    }
                case .duration:
                    EmptyView()
                }
                if case .duration = values {
                    labelled(titles.value) {
                        valueField(
                            placeholder.map(String.init) ?? "Seconds", text: $set.durationText,
                            width: fieldWidth * 1.4
                        )
                        .accessibilityLabel("\(spokenName) seconds")
                        .accessibilityIdentifier("\(identifierPrefix).duration")
                    }
                    stopwatchButton(spokenName: spokenName)
                } else {
                    labelled(titles.value) {
                        valueField(
                            placeholder.map(String.init) ?? "Reps", text: $set.repsText,
                            width: fieldWidth
                        )
                        .accessibilityLabel("\(spokenName) reps")
                        .accessibilityIdentifier("\(identifierPrefix).reps")
                    }
                }
                if !isEditingPast {
                    if !stacks { Spacer(minLength: 0) }
                    checkButton(spokenName: spokenName, showsText: stacks)
                }
            }
            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .accessibilityIdentifier("\(identifierPrefix).hint")
            }
        }
    }

    private func summary(spokenName: String, hint: String?) -> some View {
        SetSummary(
            label: SetNumbering.label(of: set), spokenName: spokenName,
            values: SetPlaceholder(context: modelContext).summaryValues(for: set),
            isDone: set.isCompleted, isHighlighted: progressions.isHighlighted(set),
            isEditingPast: isEditingPast, hint: hint, identifierPrefix: identifierPrefix,
            checkOffCount: checkOffCount
        ) {
            open(set)
        }
    }

    /// Play, on an unchecked duration set of a live workout: opens the stopwatch.
    @ViewBuilder
    private func stopwatchButton(spokenName: String) -> some View {
        if let onStartStopwatch, !set.isCompleted, case .duration = set.values {
            Button("\(spokenName) stopwatch", systemImage: "play.fill") { onStartStopwatch(set) }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("\(identifierPrefix).stopwatch")
        }
    }

    /// A small label above a control; the control's own accessibility label names it, so the text is hidden.
    @ViewBuilder
    private func labelled(_ title: String?, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            content()
        }
    }

    private func valueField(_ prompt: String, text: Binding<String>, width: CGFloat) -> some View {
        TextField(prompt, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .font(.title3)
            .fontDesign(.rounded)
            .monospacedDigit()
            .frame(width: width)
            .frame(minHeight: 44)
            .focused(focusedRepsSetID, equals: set.id)
            .onAppear {
                if focusedRepsSetID.wrappedValue == Self.keyboardHolderID {
                    focusedRepsSetID.wrappedValue = set.id
                }
            }
    }

    // MARK: Actions

    /// Opens the set with the keyboard down, as tapping its summary does.
    private func open(_ set: WorkoutSet) {
        withAnimation(reduceMotion ? nil : .default) {
            openSetID = set.id
            focusedRepsSetID.wrappedValue = nil
        }
    }

    /// Saves a reps or seconds change; in a past workout the set stays completed.
    private func saveEdit() {
        if isEditingPast {
            do { try PastWorkoutEditing(context: modelContext).saveEdit(of: set) } catch {
                saveFailed = true
            }
        } else {
            attempt { try $0.context.saveOrRollBack() }
        }
    }

    private func checkButton(spokenName: String, showsText: Bool) -> some View {
        Button {
            if set.isCompleted {
                withAnimation(reduceMotion ? nil : .default) {
                    attempt { try $0.toggleCompleted(set) }
                }
            } else if focusedRepsSetID.wrappedValue != nil {
                // Park the keyboard before this set's field goes away, then check off on the next turn,
                // so the keyboard stays up while the next set opens.
                focusedRepsSetID.wrappedValue = Self.keyboardHolderID
                Task { checkOff(keyboardWasUp: true) }
            } else {
                checkOff(keyboardWasUp: false)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.largeTitle)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffectsRemoved(reduceMotion)
                if showsText {
                    Text(set.isCompleted ? "Uncheck" : "Check Off")
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(spokenName)
        .accessibilityValue(set.isCompleted ? "done" : "not done")
        .accessibilityIdentifier("\(identifierPrefix).check")
    }

    /// Sets the weight from the row's control, animated so the numbers roll.
    private func changeWeight(_ newWeight: Double?) {
        withAnimation {
            attempt { try $0.setWeight(newWeight, of: set) }
        }
    }

    /// Last time's values: a button that copies them into an unchecked set, or plain text when it can't.
    @ViewBuilder
    private func previousValue(_ previous: SetValues?) -> some View {
        let canCopy = previous != nil && !set.isCompleted
        let label = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Previous").foregroundStyle(Color.secondary)
            Text(previous?.text ?? "—")
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 0)
            if canCopy { Text("Copy").foregroundStyle(Color.accentColor) }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        // `.accessibility` too: without it the element is only as big as the text, a hit-area audit failure.
        .contentShape([.interaction, .accessibility], .rect)
        Group {
            if canCopy {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(SetNumbering.spokenName(of: set)) previous")
        .accessibilityValue(previous?.spokenText ?? "none")
        .accessibilityIdentifier("\(identifierPrefix).previous")
    }

    /// Copies the previous values in, animated so the weight rolls. The selection tick comes from the weight
    /// control when the weight changes, so this ticks only when the copy leaves the weight alone.
    private func copyPrevious() {
        let weightBefore = set.values.weight
        var copied = false
        withAnimation {
            attempt { copied = try $0.copyPrevious(to: set) }
        }
        if copied, set.values.weight == weightBefore { previousCopyCount += 1 }
    }

    private var deleteButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            let wasOpen = isOpen
            var deleted = false
            withAnimation(reduceMotion ? nil : .default) {
                attempt {
                    try $0.deleteSet(set)
                    deleted = true
                }
                // A deleted open set leaves the live screen on the set to do next, and a past workout on none.
                if deleted, wasOpen {
                    openSetID = isEditingPast ? nil : NextSet.current(in: workout)?.id
                }
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
    private func checkOff(keyboardWasUp: Bool) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                switch try WorkoutLog(context: modelContext, restTimer: restTimer)
                    .checkOff(set, in: workout, defaultRest: defaultRest)
                {
                case .open(let next):
                    openSetID = next?.id
                    // The next set's field takes the parked keyboard as it appears; with it down, it stays down.
                    focusedRepsSetID.wrappedValue =
                        keyboardWasUp && next != nil ? Self.keyboardHolderID : nil
                    accessibilityFocus.wrappedValue = next?.id
                case .allSetsDone:
                    openSetID = nil
                    focusedRepsSetID.wrappedValue = nil
                    onAllSetsDone()
                case .missingValue(let missing):
                    focusedRepsSetID.wrappedValue = missing.id
                    missingValueCount += 1
                }
            } catch {
                // The set stays open; hand the parked keyboard back to its field.
                if keyboardWasUp { focusedRepsSetID.wrappedValue = set.id }
                saveFailed = true
            }
        }
    }

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
