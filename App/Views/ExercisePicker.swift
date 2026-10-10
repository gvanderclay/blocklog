import SwiftData
import SwiftUI

/// The exercises a workout or routine can add, grouped by muscle group and filtered by name and equipment.
/// Tapping one adds it; New Exercise creates a custom one.
struct ExercisePicker: View {
    /// The exercise types offered, such as only rep exercises for a Timed AMRAP routine.
    var types = ExerciseType.allCases
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutLog.addableExercises) private var exercises: [Exercise]
    @State private var query = ""
    @State private var equipment: Equipment?
    @State private var isCreating = false

    private var sections: [ExerciseCatalog.Section] {
        ExerciseCatalog.sections(
            from: exercises, matching: query, equipment: equipment, types: types)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.muscleGroup.title) {
                        ForEach(section.exercises) { exercise in
                            Button(exercise.name) {
                                onPick(exercise)
                                dismiss()
                            }
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("exercisePicker.row.\(exercise.name)")
                        }
                    }
                }
            }
            .animation(reduceMotion ? nil : .default, value: query)
            .animation(reduceMotion ? nil : .default, value: equipment)
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isCreating) {
                NewExerciseForm(types: types) { exercise in
                    onPick(exercise)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("exercisePicker.cancel")
                }
                ToolbarItem(placement: .bottomBar) {
                    Menu("Equipment", systemImage: "line.3.horizontal.decrease.circle") {
                        Picker("Equipment", selection: $equipment) {
                            Text("All").tag(Equipment?.none)
                            ForEach(Equipment.allCases, id: \.self) { option in
                                Text(option.title).tag(Equipment?.some(option))
                            }
                        }
                    }
                    .accessibilityValue(equipment?.title ?? "All")
                    .accessibilityIdentifier("exercisePicker.equipmentFilter")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Exercise", systemImage: "plus") { isCreating = true }
                        .accessibilityIdentifier("exercisePicker.new")
                }
            }
        }
    }
}
