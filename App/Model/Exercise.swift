import Foundation
import SwiftData

/// A movement the user can log, from the starter list or custom.
@Model
final class Exercise {
    var id: UUID
    var name: String
    /// A `MuscleGroup` raw value.
    var muscleGroupRawValue: String
    /// An `Equipment` raw value.
    var equipmentRawValue: String
    /// An `ExerciseKind` raw value.
    var kindRawValue: String
    /// The exercise's own rest length, replacing the default rest. Nil uses the default rest.
    var restOverrideSeconds: Int?
    var isCustom: Bool

    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise] = []
    @Relationship(deleteRule: .nullify, inverse: \RoutineExercise.exercise)
    var routineExercises: [RoutineExercise] = []

    init(
        id: UUID = UUID(), name: String, muscleGroup: MuscleGroup, equipment: Equipment,
        kind: ExerciseKind, restOverrideSeconds: Int? = nil, isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRawValue = muscleGroup.rawValue
        self.equipmentRawValue = equipment.rawValue
        self.kindRawValue = kind.rawValue
        self.restOverrideSeconds = restOverrideSeconds
        self.isCustom = isCustom
    }

    // Typed views of the stored raw values; an unknown raw value reads as the first case.
    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRawValue) ?? .chest }
        set { muscleGroupRawValue = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRawValue) ?? .dumbbell }
        set { equipmentRawValue = newValue.rawValue }
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRawValue) ?? .weightReps }
        set { kindRawValue = newValue.rawValue }
    }
}

/// The muscle group an exercise trains, in display order.
enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest, back, shoulders, biceps, triceps, forearms, core, quads, hamstrings, glutes,
        calves, fullBody
}

/// What the exercise is done with.
enum Equipment: String, CaseIterable, Codable, Sendable {
    case dumbbell, pullUpBar, bodyweight
}

/// What a set of the exercise records.
enum ExerciseKind: String, CaseIterable, Codable, Sendable {
    /// Dumbbell weight and reps.
    case weightReps
    /// Reps, with optional added PowerBlock weight.
    case bodyweightReps
    /// Seconds.
    case duration
}
