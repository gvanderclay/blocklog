import SwiftData
import SwiftUI

/// A programme's routines in order, each with Start, plus rename, reorder, Add Routine and Delete Programme.
struct ProgrammeDetail: View {
    let programme: Programme
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
        // A deleted programme is detached from the store until the screen has popped.
        if programme.modelContext != nil { content }
    }

    @ViewBuilder private var content: some View {
        let routines = ProgrammeLibrary.orderedRoutines(of: programme)
        List {
            Section {
                ForEach(routines.enumerated(), id: \.element.id) { index, routine in
                    HStack {
                        RoutineLink(routine: routine)
                            .accessibilityIdentifier("programme.routine.\(index)")
                        StartRoutineButton(routine: routine, present: present)
                            .accessibilityIdentifier("programme.routine.\(index).start")
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "minus.circle") { remove(routine) }
                            .tint(.orange)
                            .accessibilityIdentifier("programme.routine.\(index).remove")
                    }
                }
                Button("Add Routine", systemImage: "plus") { isAddingRoutine = true }
                    .accessibilityIdentifier("programme.addRoutine")
            } footer: {
                if routines.isEmpty {
                    Text("No routines yet. Add one to start rotating.")
                } else if !inProgressWorkouts.isEmpty {
                    Text("Finish or discard the workout in progress first.")
                }
            }
            Section {
                Button("Delete Programme", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
                .accessibilityIdentifier("programme.delete")
                // On the button, so the dialog appears by it rather than at the top of the list.
                .confirmationDialog("Delete this programme?", isPresented: $isConfirmingDelete) {
                    Button("Delete Programme", role: .destructive) { delete() }
                        .accessibilityIdentifier("programme.deleteConfirm")
                } message: {
                    Text("Its routines move to My Routines.")
                }
            }
        }
        .navigationTitle(programme.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Reorder", systemImage: "arrow.up.arrow.down") { isReordering = true }
                    .disabled(routines.count < 2)
                    .accessibilityIdentifier("programme.reorder")
                Button("Rename", systemImage: "pencil") {
                    newName = programme.name
                    isRenaming = true
                }
                .accessibilityIdentifier("programme.rename")
            }
        }
        .alert("Rename Programme", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("programme.renameField")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("programme.renameCancel")
            Button("Save") { rename() }
                .accessibilityIdentifier("programme.renameSave")
        }
        .sheet(isPresented: $isReordering) {
            ReorderSheet(items: routines, name: \.name) { ordered in
                try ProgrammeLibrary(context: modelContext).reorder(ordered, in: programme)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isAddingRoutine, onDismiss: createIfRequested) {
            AddRoutineSheet(programme: programme) { wantsNewRoutine = true }
        }
        .sheet(isPresented: $isCreatingRoutine) {
            RoutineEditor(newIn: programme)
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
            try ProgrammeLibrary(context: modelContext).rename(programme, to: newName)
        } catch {
            saveFailed = true
        }
    }

    private func remove(_ routine: Routine) {
        withAnimation(reduceMotion ? nil : .default) {
            do {
                try ProgrammeLibrary(context: modelContext).remove(routine)
            } catch {
                saveFailed = true
            }
        }
    }

    private func delete() {
        do {
            try ProgrammeLibrary(context: modelContext).delete(programme)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
