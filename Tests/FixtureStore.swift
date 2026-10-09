import Foundation
import SwiftData
import Testing

@testable import Blocklog

/// Opens a copy of a committed store from `Tests/Fixtures/` with the app's current schema, so a test can
/// check that SwiftData migrated the data. The test deletes the copy with `defer { fixture.remove() }`.
/// To add a fixture, write a store from the code before the model change, with a throwaway test and
/// `ModelConfiguration(schema:url:)`, then run `sqlite3 <file> "PRAGMA journal_mode=DELETE"` so it is one file.
@MainActor
struct FixtureStore {
    let container: ModelContainer
    private let url: URL

    /// `name` is the fixture's file name without ".store"; it opens `Fixtures/<name>.store`.
    init(_ name: String) throws {
        final class BundleAnchor {}
        let source = try #require(
            Bundle(for: BundleAnchor.self).url(forResource: name, withExtension: "store"),
            "Fixture \(name).store isn't in the test bundle")
        url = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        try FileManager.default.copyItem(at: source, to: url)
        let schema = BlocklogApp.schema
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url))
    }

    var context: ModelContext { container.mainContext }

    /// Removes the store files; call it with `defer`.
    func remove() {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
    }
}
