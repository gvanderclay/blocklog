import SwiftData

@MainActor
extension ModelContext {
    /// Saves pending changes. When the save throws, rolls the context back first, so a failed change leaves
    /// nothing pending for a later save to commit, then rethrows.
    func saveOrRollBack() throws {
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}
