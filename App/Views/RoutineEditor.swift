import SwiftData
import SwiftUI

/// Creates or edits a routine: its name, its format (with a time cap for Timed AMRAP), and its exercises with their
/// planned sets and a rep range or a target duration, or in a Timed AMRAP one fixed rep count. Changes stay in a
/// draft until Save; Cancel drops them, asking first when there are any.
struct RoutineEditor: View {
    /// The routine to edit; nil creates a new one.
    let routine: Routine?
    /// The program a new routine is added to the end of; nil for My Routines.
    private var program: Program?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: RoutineDraft
    /// The draft as the editor opened, so Cancel knows whether there is anything to discard.
    private let original: RoutineDraft
    @FocusState private var focusedRange: RoutineDraft.RangeField?
    /// The text typed into the focused range field, written to the draft when focus leaves it, so ends that
    /// cross swap only then and not mid-typing. Nil until the user types.
    @State private var rangeEdit: (field: RoutineDraft.RangeField, text: String)?
    @State private var isConfirmingDiscard = false
    @State private var isPickingExercise = false
    @State private var isReordering = false
    @State private var deleteCount = 0
    @State private var saveFailed = false
    /// Why the last format switch was refused, shown in an alert.
    @State private var formatRefusal: String?

    init(routine: Routine?) {
        self.routine = routine
        let draft = routine.map(RoutineDraft.init(routine:)) ?? RoutineDraft()
        self.draft = draft
        self.original = draft
    }

    /// A new routine at the end of the program.
    init(newIn program: Program) {
        self.routine = nil
        self.program = program
        self.draft = RoutineDraft()
        self.original = RoutineDraft()
    }

    /// A new routine starting from the draft, such as a starter routine's.
    init(newFrom draft: RoutineDraft) {
        self.routine = nil
        self.draft = draft
        self.original = draft
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("routineEditor.name")
                } footer: {
                    if !draft.canSave {
                        Text("Add a name and at least one exercise to save.")
                    }
                }
                FormatSection(draft: $draft) { formatRefusal = $0 }
                ForEach($draft.exercises) { $entry in
                    EntrySection(
                        entry: $entry,
                        index: draft.exercises.firstIndex { $0.id == entry.id } ?? 0,
                        isFixed: draft.format.kind == .timedAMRAP,
                        showsSets: draft.format == .sets,
                        focusedRange: $focusedRange,
                        rangeText: rangeText
                    ) { remove(entry) }
                }
                Section {
                    Button("Add Exercise", systemImage: "plus") { isPickingExercise = true }
                        .accessibilityIdentifier("routineEditor.addExercise")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteCount)
            .onChange(of: focusedRange) { commitRange() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                        .accessibilityIdentifier("routineEditor.cancel")
                        .confirmationDialog(
                            "Discard changes?", isPresented: $isConfirmingDiscard,
                            titleVisibility: .visible
                        ) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                                .accessibilityIdentifier("routineEditor.discardConfirm")
                            Button("Keep Editing", role: .cancel) {}
                                .accessibilityIdentifier("routineEditor.keepEditing")
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commitRange()
                        save()
                    }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("routineEditor.save")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reorder", systemImage: "arrow.up.arrow.down") { isReordering = true }
                        .disabled(!draft.canReorder)
                        .accessibilityIdentifier("routineEditor.reorder")
                }
            }
            .sheet(isPresented: $isPickingExercise) {
                ExercisePicker(types: draft.format.allowedTypes) { exercise in
                    withAnimation(reduceMotion ? nil : .default) { _ = draft.addExercise(exercise) }
                }
            }
            .sheet(isPresented: $isReordering) {
                ReorderSheet(items: draft.exercises, name: \.exercise.name) { draft.exercises = $0 }
                    .interactiveDismissDisabled()
            }
            .saveFailedAlert(isPresented: $saveFailed)
            .alert("Can’t Switch Format", item: $formatRefusal) { _ in
                Button("OK") {}
                    .accessibilityIdentifier("routineEditor.formatRefusedOK")
            } message: { refusal in
                Text(refusal)
            }
        }
        // A swipe down would drop the draft; leaving goes through Cancel or Save.
        .interactiveDismissDisabled()
    }

    /// A range field's text: what the user typed while it holds focus, otherwise the draft's value.
    private func rangeText(_ field: RoutineDraft.RangeField) -> Binding<String> {
        Binding(
            get: {
                rangeEdit?.field == field ? rangeEdit?.text ?? "" : String(draft.rangeValue(field))
            },
            set: { text in
                // A newly focused field writes back its old text before the focus change is seen: commit the
                // other field's edit and drop that echo, which would undo a swap.
                if rangeEdit.map({ $0.field != field }) ?? false {
                    commitRange()
                    return
                }
                rangeEdit = (field, text)
            }
        )
    }

    /// Writes the typed range end to the draft; an emptied field keeps the old end.
    private func commitRange() {
        guard let rangeEdit else { return }
        draft.setRangeEnd(rangeEdit.field, to: TypedNumber.parse(rangeEdit.text, maxDigits: 2))
        self.rangeEdit = nil
    }

    private func cancel() {
        commitRange()
        if draft.hasChanges(from: original) { isConfirmingDiscard = true } else { dismiss() }
    }

    private func remove(_ entry: RoutineDraft.Entry) {
        withAnimation(reduceMotion ? nil : .default) {
            draft.exercises.removeAll { $0.id == entry.id }
        }
        deleteCount += 1
    }

    private func save() {
        do {
            if let program {
                try ProgramLibrary(context: modelContext).add(draft, to: program)
            } else {
                try RoutineLibrary(context: modelContext).save(draft, to: routine)
            }
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

/// The routine's format, and for a Timed AMRAP its time cap in minutes. A refused switch leaves the format as it was
/// and passes the message on.
private struct FormatSection: View {
    @Binding var draft: RoutineDraft
    let onRefusal: (String) -> Void

    var body: some View {
        Section {
            Picker(
                "Format",
                selection: Binding(
                    get: { draft.format.kind },
                    set: { kind in
                        if let refusal = draft.switchFormat(to: kind) { onRefusal(refusal) }
                    })
            ) {
                ForEach(RoutineFormat.Kind.allCases) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("routineEditor.format")
            if let minutes = draft.format.timeCapMinutes {
                Stepper(value: $draft.timeCapMinutes, in: RoutineFormat.timeCapMinuteBounds) {
                    NumberLabel(title: "Time Cap", value: minutes, unit: " min")
                }
                .accessibilityValue("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
                .accessibilityIdentifier("routineEditor.timeCap")
            }
        } footer: {
            switch draft.format {
            case .sets: EmptyView()
            case .timedAMRAP:
                Text(
                    "As many rounds as possible before the time cap, each exercise at a fixed rep count."
                )
            case .stretch: Text("Plays each exercise as a timed hold in the stretch player.")
            }
        }
    }
}

/// One exercise of the draft: its set count, its rep range or target duration, and its set types under a collapsed
/// disclosure; in a Timed AMRAP, only its fixed rep count.
private struct EntrySection: View {
    @Binding var entry: RoutineDraft.Entry
    let index: Int
    /// A Timed AMRAP entry: one rep count, no set list.
    let isFixed: Bool
    /// False in a Stretch routine, whose player holds each stretch once a round whatever its set count.
    let showsSets: Bool
    let focusedRange: FocusState<RoutineDraft.RangeField?>.Binding
    /// A range field's text, kept by the editor so Save and Cancel can write it.
    let rangeText: (RoutineDraft.RangeField) -> Binding<String>
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typeChangeCount = 0

    private var identifierPrefix: String { "routineEditor.exercise.\(index)" }

    var body: some View {
        Section {
            if isFixed {
                Stepper(value: $entry.reps, in: RoutineTarget.repBounds) {
                    NumberLabel(title: "Reps", value: entry.reps)
                }
                .accessibilityIdentifier("\(identifierPrefix).reps")
            } else {
                plan
            }
        } header: {
            HStack {
                Text(entry.exercise.name)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(identifierPrefix).name")
                Spacer()
                Menu {
                    Button(
                        "Remove Exercise", systemImage: "trash", role: .destructive,
                        action: onRemove
                    )
                    .accessibilityIdentifier("\(identifierPrefix).remove")
                } label: {
                    Label("Exercise Actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("\(identifierPrefix).menu")
            }
        }
        .headerProminence(.increased)
        .sensoryFeedback(.selection, trigger: typeChangeCount)
    }

    /// The set count, the rep range or target duration, and the set types.
    @ViewBuilder private var plan: some View {
        if showsSets {
            let count = entry.setCount
            Stepper(
                value: $entry.setCount.animation(reduceMotion ? nil : .default),
                in: entry.setCountBounds
            ) {
                NumberLabel(title: "Sets", value: count)
            }
            .accessibilityValue("\(count) \(count == 1 ? "set" : "sets")")
            .accessibilityIdentifier("\(identifierPrefix).sets")
        }
        switch entry.target {
        case .duration(let seconds):
            Stepper(
                value: $entry.targetDurationSeconds, in: RoutineTarget.durationBounds,
                step: RoutineTarget.durationStep
            ) {
                NumberLabel(title: "Target Duration", value: seconds, unit: " s")
            }
            .accessibilityValue("\(seconds) seconds")
            .accessibilityIdentifier("\(identifierPrefix).targetDuration")
        case .repRange:
            HStack {
                Text("Reps")
                Spacer()
                rangeField(.low, label: "Low reps", identifier: "repLow")
                Text("to")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                rangeField(.high, label: "High reps", identifier: "repHigh")
            }
        }
        if showsSets {
            DisclosureGroup("Set Types") { setTypes }
                .accessibilityIdentifier("\(identifierPrefix).setTypes")
        }
    }

    private func rangeField(
        _ end: RoutineDraft.RangeField.End, label: String, identifier: String
    ) -> some View {
        let field = RoutineDraft.RangeField(entryID: entry.id, end: end)
        let range = entry.target.repRange ?? RoutineTarget.defaultRepRange
        // An emptied field shows the end it keeps.
        let kept = end == .low ? range.lowerBound : range.upperBound
        return TextField(label, text: rangeText(field), prompt: Text(String(kept)))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .fontDesign(.rounded)
            .monospacedDigit()
            .frame(width: 56)
            .frame(minHeight: 44)
            .focused(focusedRange, equals: field)
            .accessibilityLabel(label)
            .accessibilityIdentifier("\(identifierPrefix).\(identifier)")
    }

    /// One set-type row per planned set.
    @ViewBuilder private var setTypes: some View {
        let labels = SetNumbering.labels(for: entry.sets.map(\.type))
        // Bindings from the collection, not by index, so a row being removed never reads past the end.
        ForEach($entry.sets) { $plannedSet in
            let setIndex = entry.sets.firstIndex { $0.id == plannedSet.id } ?? 0
            PlannedSetRow(
                type: $plannedSet.type, label: labels[setIndex],
                identifierPrefix: "\(identifierPrefix).set.\(setIndex)"
            ) { typeChangeCount += 1 }
        }
    }
}

/// A stepper's title and its number, which rolls as it changes.
private struct NumberLabel: View {
    let title: LocalizedStringKey
    let value: Int
    var unit = ""

    var body: some View {
        LabeledContent(title) {
            Text("\(value)\(unit)")
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.default, value: value)
        }
    }
}

/// One planned set: its label opens the set-type menu, and its type is named beside it.
private struct PlannedSetRow: View {
    @Binding var type: SetType
    let label: String
    /// `routineEditor.exercise.<e>.set.<s>`.
    let identifierPrefix: String
    let onTypeChange: () -> Void

    var body: some View {
        HStack {
            Menu {
                ForEach(SetType.allCases, id: \.self) { option in
                    Button {
                        type = option
                        onTypeChange()
                    } label: {
                        if type == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                    .accessibilityIdentifier("setMenu.type.\(option.rawValue)")
                }
            } label: {
                Text(label)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Set type")
            .accessibilityValue(type.title)
            .accessibilityIdentifier("\(identifierPrefix).typeMenu")
            Text(type.title)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
