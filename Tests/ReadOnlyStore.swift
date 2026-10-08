import Foundation
import SwiftData

@testable import Blocklog

/// A store on disk whose saves fail, standing in for a full disk, holding what `populate` saved first.
/// Read-only needs an existing store file, so a writable container writes it first.
@MainActor
struct ReadOnlyStore {
    let container: ModelContainer
    private let url: URL

    init(populate: (ModelContext) throws -> Void = { _ in }) throws {
        url = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        let schema = Schema([
            Exercise.self, Workout.self, WorkoutExercise.self, WorkoutSet.self, Routine.self,
            RoutineExercise.self,
        ])
        let writable = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        try populate(writable.mainContext)
        try writable.mainContext.save()
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false))
    }

    var context: ModelContext { container.mainContext }

    /// Removes the store files; call it with `defer`.
    func remove() {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: url.path() + suffix)
        }
    }
}
