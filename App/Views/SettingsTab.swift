import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Export and import of the backup document.
struct SettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutLog.inProgressWorkouts) private var inProgressWorkouts: [Workout]
    @State private var isChoosingFile = false
    /// A validated document waiting for the user's confirmation.
    @State private var pendingImport: BackupDocument?
    @State private var failure: BackupFailure?
    /// Set when the stored data can't be exported, so Export is off until it is fixed.
    @State private var exportProblem: BackupFailure?
    @State private var importCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ShareLink(
                        item: BackupFile(container: modelContext.container),
                        preview: SharePreview("Blocklog Backup")
                    ) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exportProblem != nil)
                    .accessibilityIdentifier("settings.export")
                } footer: {
                    Text(
                        "Exports your exercises, routines and finished workouts. A workout in progress is left out."
                    )
                }
                Section {
                    Button("Import Data", systemImage: "square.and.arrow.down") {
                        isChoosingFile = true
                    }
                    .disabled(!inProgressWorkouts.isEmpty)
                    .accessibilityIdentifier("settings.import")
                } footer: {
                    Text(
                        inProgressWorkouts.isEmpty
                            ? "Importing replaces all data on this phone with a backup file."
                            : "Finish or discard your workout in progress to import."
                    )
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json]) { result in
                read(result)
            }
            .alert("Replace all data?", item: $pendingImport) { document in
                Button("Replace All Data", role: .destructive) { replaceAll(with: document) }
                    .accessibilityIdentifier("import.confirm")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("import.cancel")
            } message: { document in
                Text(confirmationMessage(for: document))
            }
            .alert(failure?.title ?? "", item: $failure) { _ in
                Button("OK") {}
                    .accessibilityIdentifier("importFailed.ok")
            } message: { failure in
                Text(failure.message)
            }
            .sensoryFeedback(.success, trigger: importCount)
            .onAppear(perform: checkExport)
        }
    }

    /// Exports and validates what is stored, so a backup that import would reject is reported here, not
    /// after the user shares it.
    private func checkExport() {
        do {
            _ = try Backup(context: modelContext).export()
            exportProblem = nil
        } catch {
            exportProblem = BackupFailure(
                title: "Couldn’t Export", message: error.localizedDescription)
            failure = exportProblem
        }
    }

    private func confirmationMessage(for document: BackupDocument) -> String {
        let stored = (try? Backup(context: modelContext).storedCounts())?.summary ?? "everything"
        return
            "This deletes \(stored) on this phone and restores \(Backup.counts(of: document).summary)."
    }

    /// Reads and validates the chosen file, then asks for confirmation. Nothing is stored yet.
    private func read(_ result: Result<URL, any Error>) {
        do {
            pendingImport = try Backup.read(contentsOf: result.get())
        } catch {
            failure = BackupFailure(title: "Couldn’t Import", message: error.localizedDescription)
        }
    }

    private func replaceAll(with document: BackupDocument) {
        do {
            try Backup(context: modelContext).replaceAll(with: document)
            importCount += 1
            checkExport()
        } catch {
            failure = BackupFailure(title: "Couldn’t Import", message: error.localizedDescription)
        }
    }
}

/// An export or import error the alert shows.
private struct BackupFailure {
    let title: String
    let message: String
}
