/// The names the exercise picker and the new-exercise form show for each choice.
extension MuscleGroup {
    var title: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .core: "Core"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .fullBody: "Full Body"
        }
    }
}

extension Equipment {
    var title: String {
        switch self {
        case .dumbbell: "Dumbbell"
        case .pullUpBar: "Pull-up bar"
        case .bodyweight: "Bodyweight"
        }
    }
}

extension ExerciseKind {
    var title: String {
        switch self {
        case .weightReps: "Weight × Reps"
        case .bodyweightReps: "Bodyweight Reps"
        case .duration: "Duration"
        }
    }
}

extension SetType {
    var title: String {
        switch self {
        case .normal: "Normal"
        case .warmUp: "Warm-up"
        case .drop: "Drop"
        case .failure: "Failure"
        }
    }
}
