import Foundation
import SwiftData

/// One logged effort in a workout exercise. Weights are pounds per dumbbell.
@Model
final class WorkoutSet {
    var id: UUID
    var position: Int
    /// A `SetType` raw value.
    var setTypeRawValue: String
    /// The dumbbell weight, or the added weight on bodyweight reps.
    var weight: Double?
    var reps: Int?
    var durationSeconds: Int?
    var isCompleted: Bool
    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(), position: Int, setType: SetType = .normal, weight: Double? = nil,
        reps: Int? = nil, durationSeconds: Int? = nil, isCompleted: Bool = false
    ) {
        self.id = id
        self.position = position
        self.setTypeRawValue = setType.rawValue
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
    }

    // A typed view of the stored raw value; an unknown raw value reads as normal.
    var setType: SetType {
        get { SetType(rawValue: setTypeRawValue) ?? .normal }
        set { setTypeRawValue = newValue.rawValue }
    }
}

/// The kind of effort a set was.
enum SetType: String, CaseIterable, Codable, Sendable {
    case normal, warmUp, drop, failure
}
