import SwiftUI

/// Time up: the rounds done, which can be corrected, the extra reps of the unfinished round typed in, the score,
/// and a bottom Save, disabled at a score of 0 rounds + 0 reps.
struct AMRAPTimeUpView: View {
    let player: AMRAPPlayer
    let save: () -> Void

    /// The Extra reps field's text, set back to the player's after each edit, so a number past the cap shows the cap
    /// even when the held value hasn't changed (29, then 295).
    @State private var extraRepsText = ""

    var body: some View {
        let score = player.score
        Form {
            Section {
                Text(player.endedEarly ? "Finished early" : "Time’s up")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("amrap.timeUp")
                Stepper(
                    value: Binding(get: { score.rounds }, set: { player.send(.setRounds($0)) }),
                    in: AMRAPPlayer.roundBounds
                ) {
                    LabeledContent("Rounds") {
                        Text("\(score.rounds)")
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(score.rounds)))
                            .animation(.default, value: score.rounds)
                    }
                }
                .accessibilityValue("\(score.rounds) \(score.rounds == 1 ? "round" : "rounds")")
                .accessibilityIdentifier("amrap.rounds")
                .sensoryFeedback(.selection, trigger: score.rounds)
                LabeledContent("Extra reps") {
                    TextField("Extra reps", text: $extraRepsText, prompt: Text("0"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .accessibilityIdentifier("amrap.extraReps")
                        .onAppear { extraRepsText = player.extraRepsText }
                        .onChange(of: extraRepsText) { _, text in
                            player.extraRepsText = text
                            extraRepsText = player.extraRepsText
                        }
                }
            } footer: {
                Text("The reps you did in the round you didn’t finish, counted in exercise order.")
            }
            Section {
                LabeledContent("Score") {
                    Text(score.text)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Score")
                .accessibilityValue(score.spokenText)
                .accessibilityIdentifier("amrap.score")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: save) {
                    Text("Save").frame(maxWidth: .infinity)
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!player.canLog)
                .accessibilityIdentifier("amrap.save")
                if !player.canLog {
                    Text("Add a round or reps to save")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("amrap.saveHint")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}
