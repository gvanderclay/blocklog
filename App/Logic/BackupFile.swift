import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

/// What the Export Data share link shares: the backup, written to a temporary JSON file when the user
/// picks a share target, so it holds what is stored then.
// Not @MainActor: `Transferable`'s static `transferRepresentation` is a nonisolated requirement; the export
// itself hops to the main actor below.
struct BackupFile: Transferable {
    /// ModelContainer is Sendable; the export itself runs on the main actor with its main context.
    let container: ModelContainer

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let (data, name) = try await MainActor.run {
                (
                    try Backup(context: file.container.mainContext).export().encoded(),
                    Backup.fileName(for: .now)
                )
            }
            // A fresh folder per export keeps the file name the user sees.
            let folder = FileManager.default.temporaryDirectory.appending(
                path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
