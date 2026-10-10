import Foundation
import SwiftData

/// An ordered list of routines you rotate through, such as Push → Pull → Legs. It owns its routines.
@Model
final class Program {
    var id: UUID
    var name: String
    var creationDate: Date

    /// Unordered: order by `Routine.membership`. Deleting the program keeps its routines and clears their link.
    @Relationship(deleteRule: .nullify, inverse: \Routine.program)
    var routines: [Routine] = []

    init(id: UUID = UUID(), name: String, creationDate: Date) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
}
