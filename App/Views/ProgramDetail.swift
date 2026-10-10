import SwiftData
import SwiftUI

/// A program's routines in order, each with Start, plus rename, reorder, Add Routine and Delete Program.
struct ProgramDetail: View {
    let program: Program
    /// Shows a started workout in the full-screen workout screen.
    let present: (RoutineStart.Started) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isReordering = false
    @State private var isAddingRoutine = false
    @State private var wantsNewRoutine = false
    @State private var isCreatingRoutine = false
    @State private var isConfirmingDelete = false
    @State private var saveFailed = false

    var body: some View {
        // A deleted program is detached from the store until the screen has popped.
        if program.modelContext != nil { content }
    }

    @ViewBuilder private var content: some View {
        let routines = ProgramLibrary.orderedRoutines(of: program)
        List {
            Section {
                ForEach(routines.enumerated(), id: \.element.id) { index, routine in
                    HStack {
                        RoutineLink(routine: routine)
                            .accessibilityIdentifier("program.routine.\(index)")
                        StartRoutineButton(routine: routine, present: present)
                            .accessibilityIdentifier("program.routine.\(index).start")
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "minus.circle") { remove(routine) }
                            .tint(.orange)
                            .accessibilityIdentifier("program.routine.\(index).remove")
                    }
                }
                Button("Add Routine", systemImage: "plus") { isAddingRoutine = true }
                    .accessibilityIdentifier("program.addRoutine")
            } footer: {
                if routines.isEmpty {
                    Text("No routines yet. Add one to start rotating.")
                } else if !inProgressWorkouts.isEmpty {
                    Text("Finish or discard the workout in progress first.")
                }
            }
            Section {
                Button("Delete Program", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
                .accessibilityIdentifier("program.delete")
                // On the button, so the dialog appears by it rather than at the top of the list.
                .confirmationDialog("Delete this program?", isPresented: $isConfirmingDelete) {
                    Button("Delete Program", role: .destructive) { delete() }
                        .accessibilityIdentifier("program.deleteConfirm")
                } message: {
                    Text("Its routines move to My Routines.")
                }
            }
        }
        .navigationTitle(program.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Reorder", systemImage: "arrow.up.arrow.down") { isReordering = true }
                    .disabled(routines.count < 2)
                    .accessibilityIdentifier("program.reorder")
                Button("Rename", systemImage: "pencil") {
                    newName = program.name
                    isRenaming = true
                }
                .accessibilityIdentifier("program.rename")
            }
        }
        .alert("Rename Program", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("program.renameField")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("program.renameCancel")
            Button("Save") { rename() }
                .accessibilityIdentifier("program.renameSave")
        }
        .sheet(isPresented: $isReordering) {
            ReorderSheet(items: routines, name: \.name) { ordered in
                try ProgramLibrary(context: modelContext).reorder(ordered, in: program)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isAddingRoutine, onDismiss: createIfRequested) {
            AddRoutineSheet(program: program) { wantsNewRoutine = true }
        }
        .sheet(isPresented: $isCreatingRoutine) {
            RoutineEditor(newIn: program)
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// The Add Routine sheet has closed after asking for a new routine, so the editor can now open.
    private func createIfRequested() {
        if wantsNewRoutine {
            wantsNewRoutine = false
            isCreatingRoutine = true
        }
    }

    private func rename() {
        do {
            try ProgramLibrary(context: modelContext).rename(program, to: newName)
        } catch {
            saveFailed = true
        }
    }

    private func remove(_ routine: Routine) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try ProgramLibrary(context: modelContext).remove(routine)
            } catch {
                saveFailed = true
            }
        }
    }

    private func delete() {
        do {
            try ProgramLibrary(context: modelContext).delete(program)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
