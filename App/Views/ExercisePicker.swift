import SwiftData
import SwiftUI

/// The exercises a workout can add, grouped by muscle group and filtered by name and equipment. Tapping one
/// adds it to the workout; New Exercise creates a custom one.
struct ExercisePicker: View {
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutLog.addableExercises) private var exercises: [Exercise]
    @State private var query = ""
    @State private var equipment: Equipment?
    @State private var isCreating = false
    @State private var infoExercise: Exercise?

    private var sections: [ExerciseCatalog.Section] {
        ExerciseCatalog.sections(from: exercises, matching: query, equipment: equipment)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.muscleGroup.title) {
                        ForEach(section.exercises) { exercise in
                            HStack {
                                Button(exercise.name) {
                                    onPick(exercise)
                                    dismiss()
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("exercisePicker.row.\(exercise.name)")
                                // Borderless, so only the symbol opens the info and the rest of the row still adds.
                                Button {
                                    infoExercise = exercise
                                } label: {
                                    Label("Exercise Info", systemImage: "info.circle")
                                        .labelStyle(.iconOnly)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("exercisePicker.row.\(exercise.name).info")
                            }
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
            .navigationDestination(item: $infoExercise) { exercise in
                ExerciseInfoScreen(exercise: exercise)
            }
            .navigationDestination(isPresented: $isCreating) {
                NewExerciseForm { exercise in
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
