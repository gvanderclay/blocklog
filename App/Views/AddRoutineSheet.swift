import SwiftData
import SwiftUI

/// Offers a copy of one of My Routines, a copy of a starter routine, or a new routine to add to a programme.
struct AddRoutineSheet: View {
    let programme: Programme
    /// Called when New Routine is tapped; the sheet closes first.
    let onNewRoutine: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(ProgrammeLibrary.myRoutines) private var myRoutines: [Routine]
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("New Routine", systemImage: "plus") {
                        onNewRoutine()
                        dismiss()
                    }
                    .accessibilityIdentifier("addRoutine.new")
                }
                if !myRoutines.isEmpty {
                    Section("Copy of My Routine") {
                        ForEach(myRoutines) { routine in
                            Button(routine.name) { add(RoutineDraft(routine: routine)) }
                                .accessibilityIdentifier("addRoutine.myRoutine.\(routine.name)")
                        }
                    }
                }
                Section("Copy of Starter Routine") {
                    ForEach(StarterRoutine.copyable(in: StarterRoutine.bundled)) { starterRoutine in
                        Button(starterRoutine.name) {
                            do {
                                add(
                                    try StarterLibrary(context: modelContext).draft(
                                        of: starterRoutine))
                            } catch {
                                saveFailed = true
                            }
                        }
                        .accessibilityIdentifier("addRoutine.starter.\(starterRoutine.name)")
                    }
                }
            }
            .foregroundStyle(.primary)
            .navigationTitle("Add Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("addRoutine.cancel")
                }
            }
            .saveFailedAlert(isPresented: $saveFailed)
        }
    }

    private func add(_ draft: RoutineDraft) {
        do {
            try ProgrammeLibrary(context: modelContext).add(draft, to: programme)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
