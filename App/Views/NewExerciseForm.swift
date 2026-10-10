import SwiftData
import SwiftUI

/// The form that creates a custom exercise. Save creates it and hands it to `onCreate`, which adds it to the workout.
struct NewExerciseForm: View {
    /// The types the new exercise can have.
    let types: [ExerciseType]
    let onCreate: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var name = ""
    @State private var muscleGroup = MuscleGroup.chest
    @State private var equipment = Equipment.dumbbell
    @State private var type: ExerciseType
    @State private var saveFailed = false

    init(types: [ExerciseType] = ExerciseType.allCases, onCreate: @escaping (Exercise) -> Void) {
        self.types = types
        self.onCreate = onCreate
        self.type = types.first ?? .weightReps
    }

    private var problem: ExerciseCatalog.NameProblem? {
        ExerciseCatalog.nameProblem(for: name, among: exercises)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("newExercise.name")
            } footer: {
                if problem == .duplicate {
                    Text("An exercise with this name already exists.")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("newExercise.error")
                }
            }
            Section {
                Picker("Muscle group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("newExercise.muscleGroup")
                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("newExercise.equipment")
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                .accessibilityIdentifier("newExercise.type")
            }
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(problem != nil)
                    .accessibilityIdentifier("newExercise.save")
            }
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private func save() {
        do {
            let catalog = ExerciseCatalog(context: modelContext)
            if let exercise = try catalog.createCustomExercise(
                named: name, muscleGroup: muscleGroup, equipment: equipment, type: type)
            {
                onCreate(exercise)
            }
        } catch {
            saveFailed = true
        }
    }
}
