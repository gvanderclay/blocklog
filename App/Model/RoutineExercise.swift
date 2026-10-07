import Foundation
import SwiftData

/// One exercise in a routine: its planned set types and a rep range or a target duration.
@Model
final class RoutineExercise {
    var id: UUID
    var position: Int
    var exercise: Exercise?
    var routine: Routine?
    /// `SetType` raw values, in set order.
    var plannedSetTypeRawValues: [String]
    var repRangeLow: Int?
    var repRangeHigh: Int?
    var targetDurationSeconds: Int?

    init(
        id: UUID = UUID(), exercise: Exercise, position: Int, plannedSetTypes: [SetType],
        repRangeLow: Int? = nil, repRangeHigh: Int? = nil, targetDurationSeconds: Int? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.position = position
        self.plannedSetTypeRawValues = plannedSetTypes.map(\.rawValue)
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.targetDurationSeconds = targetDurationSeconds
    }
}
