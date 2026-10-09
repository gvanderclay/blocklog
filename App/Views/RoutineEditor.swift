import SwiftData
import SwiftUI

/// Creates or edits a routine: its name, and its exercises with their planned sets and a rep range or a
/// target duration. Changes stay in a draft until Save; Cancel drops them.
struct RoutineEditor: View {
    /// The routine to edit; nil creates a new one.
    let routine: Routine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: RoutineDraft
    @State private var isPickingExercise = false
    @State private var isReordering = false
    @State private var deleteCount = 0
    @State private var saveFailed = false

    init(routine: Routine?) {
        self.routine = routine
        self.draft = routine.map(RoutineDraft.init(routine:)) ?? RoutineDraft()
    }

    /// A new routine starting from the draft, such as a template's.
    init(newFrom draft: RoutineDraft) {
        self.routine = nil
        self.draft = draft
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
                ForEach($draft.exercises) { $entry in
                    EntrySection(
                        entry: $entry,
                        index: draft.exercises.firstIndex { $0.id == entry.id } ?? 0,
                        deleteCount: $deleteCount
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("routineEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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
                ExercisePicker { exercise in
                    withAnimation(reduceMotion ? nil : .default) { draft.addExercise(exercise) }
                }
            }
            .sheet(isPresented: $isReordering) {
                ReorderSheet(items: draft.exercises, name: \.exercise.name) { draft.exercises = $0 }
                    .interactiveDismissDisabled()
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
        // A swipe down would drop the draft; leaving goes through Cancel or Save.
        .interactiveDismissDisabled()
    }

    private func remove(_ entry: RoutineDraft.Entry) {
        withAnimation(reduceMotion ? nil : .default) {
            draft.exercises.removeAll { $0.id == entry.id }
        }
        deleteCount += 1
    }

    private func save() {
        do {
            try RoutineLibrary(context: modelContext).save(draft, to: routine)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

/// One exercise of the draft: its rep range or target duration, its planned sets and an Add Set button.
private struct EntrySection: View {
    @Binding var entry: RoutineDraft.Entry
    let index: Int
    /// Bumped on every set deletion, so the editor plays the delete haptic.
    @Binding var deleteCount: Int
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typeChangeCount = 0

    private var identifierPrefix: String { "routineEditor.exercise.\(index)" }

    var body: some View {
        Section {
            switch entry.target {
            case .duration(let seconds):
                Stepper(
                    value: $entry.targetDurationSeconds, in: RoutineTarget.durationBounds,
                    step: RoutineTarget.durationStep
                ) {
                    NumberLabel(title: "Target", value: seconds, unit: " s")
                }
                .accessibilityValue("\(seconds) seconds")
                .accessibilityIdentifier("\(identifierPrefix).targetDuration")
            case .repRange(let range):
                Stepper(value: $entry.repLow, in: RoutineTarget.lowBounds(of: range)) {
                    NumberLabel(title: "Low reps", value: range.lowerBound)
                }
                .accessibilityIdentifier("\(identifierPrefix).repLow")
                Stepper(value: $entry.repHigh, in: RoutineTarget.highBounds(of: range)) {
                    NumberLabel(title: "High reps", value: range.upperBound)
                }
                .accessibilityIdentifier("\(identifierPrefix).repHigh")
            }
            let labels = SetNumbering.labels(for: entry.sets.map(\.type))
            // Bindings from the collection, not by index, so a row being deleted never reads past the end.
            ForEach($entry.sets) { $plannedSet in
                let setIndex = entry.sets.firstIndex { $0.id == plannedSet.id } ?? 0
                PlannedSetRow(
                    type: $plannedSet.type, label: labels[setIndex],
                    identifierPrefix: "\(identifierPrefix).set.\(setIndex)"
                ) { typeChangeCount += 1 }
            }
            .onDelete { offsets in
                withAnimation(reduceMotion ? nil : .default) {
                    entry.sets.remove(atOffsets: offsets)
                }
                deleteCount += 1
            }
            Button("Add Set", systemImage: "plus") {
                withAnimation(reduceMotion ? nil : .default) { entry.addSet() }
            }
            .accessibilityIdentifier("\(identifierPrefix).addSet")
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
