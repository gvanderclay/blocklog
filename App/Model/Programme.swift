import Foundation
import SwiftData

/// An ordered list of routines you rotate through, such as Push → Pull → Legs. It owns its routines.
@Model
final class Programme {
    var id: UUID
    var name: String
    var creationDate: Date

    /// Unordered: order by `Routine.membership`. Deleting the programme keeps its routines and clears their link.
    @Relationship(deleteRule: .nullify, inverse: \Routine.programme)
    var routines: [Routine] = []

    init(id: UUID = UUID(), name: String, creationDate: Date) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
}
