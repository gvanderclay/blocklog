import SwiftData
import SwiftUI

/// The full-screen guided player for a Timed AMRAP: before Start, the dumbbell weights, the round and last time's
/// score; then the get-ready countdown, the big countdown with the round number and the round's exercises, Round
/// done and Pause; at time up, the extra reps and Save; then today's and last time's score. Quitting after a round
/// asks whether to save it. The screen stays awake while it shows, and leaving the app pauses it.
struct AMRAPPlayerScreen: View {
    let player: AMRAPPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var askingToSave = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Group {
                switch player.phase {
                case .setup: AMRAPSetupView(player: player)
                case .getReady, .running, .paused:
                    AMRAPRunView(player: player)
                        .safeAreaInset(edge: .bottom) { AMRAPControls(player: player) }
                case .timeUp: AMRAPTimeUpView(player: player)
                case .finished: AMRAPFinishedView(player: player)
                }
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                switch player.phase {
                case .finished:
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("amrap.done")
                    }
                case .timeUp:
                    quitItem
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { _ = save() }
                            .accessibilityIdentifier("amrap.save")
                    }
                default:
                    quitItem
                }
            }
        }
        .guidedPlayerClock(
            player.countdown, advance: { player.advance() }, pause: { player.send(.pause) }
        )
        .sensoryFeedback(.success, trigger: player.score.rounds)
        .sensoryFeedback(trigger: player.loggedWorkout != nil) { _, logged in
            logged ? .success : nil
        }
        .confirmationDialog(
            "Save what you did?", isPresented: $askingToSave, titleVisibility: .visible
        ) {
            Button("Save") { if save() { dismiss() } }
                .accessibilityIdentifier("amrap.quitSave")
            Button("Discard", role: .destructive) { dismiss() }
                .accessibilityIdentifier("amrap.discard")
            Button("Keep Going", role: .cancel) {}
                .accessibilityIdentifier("amrap.keepGoing")
        } message: {
            Text("Save logs your score so far, \(player.score.text), to History.")
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    private var quitItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Quit") {
                if player.hasSomethingToSave { askingToSave = true } else { dismiss() }
            }
            .accessibilityIdentifier("amrap.quit")
        }
    }

    /// Logs the AMRAP, or closes the player when there is nothing to log (0 rounds + 0 reps); false, with the
    /// alert, when the save failed.
    private func save() -> Bool {
        do {
            if try player.log(in: modelContext) == nil { dismiss() }
            return true
        } catch {
            saveFailed = true
            return false
        }
    }
}

/// One exercise of the round with its reps, such as "5 Pull-up", and its weight for a dumbbell exercise.
private struct AMRAPExerciseRow: View {
    let player: AMRAPPlayer
    let index: Int

    var body: some View {
        let entry = player.round.entries[index]
        let weight = player.weights[index]
        HStack {
            Text("\(entry.reps)")
                .fontDesign(.rounded)
                .monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
            Text(entry.exercise.name)
            Spacer()
            if let weight {
                Text("\(weight.formatted()) lb")
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        // .ignore with an explicit label and value: .combine reads the row twice.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.exercise.name)
        .accessibilityValue(
            "\(entry.reps) \(entry.reps == 1 ? "rep" : "reps")"
                + (weight.map { ", \($0.formatted()) pounds" } ?? "")
        )
        .accessibilityIdentifier("amrap.exercise.\(index)")
    }
}

/// Before Start: each dumbbell exercise's weight with − and +, the round, last time's score and Start.
private struct AMRAPSetupView: View {
    let player: AMRAPPlayer

    var body: some View {
        let weighted = player.dumbbellEntries
        List {
            if !weighted.isEmpty {
                Section {
                    ForEach(weighted, id: \.self) { index in
                        HStack {
                            Text(player.round.entries[index].exercise.name)
                            Spacer()
                            WeightControl(
                                weight: player.weights[index],
                                identifierPrefix: "amrap.weight.\(index)",
                                usesStepIdentifiers: true
                            ) { weight in
                                if let weight {
                                    player.send(.setWeight(entry: index, weight: weight))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Weights")
                } footer: {
                    Text("The weights stay fixed for the whole AMRAP.")
                }
            }
            Section("Each Round") {
                ForEach(player.round.entries.indices, id: \.self) { index in
                    AMRAPExerciseRow(player: player, index: index)
                }
            }
            Section {
                HStack {
                    Text("Last time")
                    Spacer()
                    Text(player.lastScore?.text ?? "None yet")
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last time")
                .accessibilityValue(player.lastScore?.spokenText ?? "None yet")
                .accessibilityIdentifier("amrap.lastScore")
            }
            Section {
                Button("Start") { player.send(.start) }
                    .accessibilityIdentifier("amrap.start")
            } footer: {
                let minutes = player.timeCapSeconds / 60
                Text(
                    "\(minutes) \(minutes == 1 ? "minute" : "minutes"), after a \(AMRAPPlayer.getReadySeconds)-second get-ready countdown."
                )
            }
        }
    }
}

/// The run: the round number, Get ready or Paused, the big countdown and the round's exercises.
private struct AMRAPRunView: View {
    let player: AMRAPPlayer

    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = 72

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Round \(player.roundNumber)")
                    .font(.title.weight(.semibold))
                    .contentTransition(.numericText(value: Double(player.roundNumber)))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("amrap.round")
                if let status = status {
                    Text(status)
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .accessibilityIdentifier("amrap.status")
                }
                if let countdown = player.countdown {
                    CountdownText(countdown: countdown, identifier: "amrap.countdown")
                        .font(.system(size: countdownSize, weight: .semibold))
                }
                VStack(spacing: 8) {
                    ForEach(player.round.entries.indices, id: \.self) { index in
                        AMRAPExerciseRow(player: player, index: index)
                            .font(.title3)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .animation(.default, value: player.phase)
            .animation(.default, value: player.roundNumber)
        }
    }

    private var status: String? {
        switch player.phase {
        case .getReady: "Get ready"
        case .paused: "Paused"
        default: nil
        }
    }
}

/// Pause or Resume, and Round done.
private struct AMRAPControls: View {
    let player: AMRAPPlayer

    var body: some View {
        let isPaused = player.phase == .paused
        HStack(spacing: 12) {
            Button(
                isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill"
            ) { player.send(isPaused ? .resume : .pause) }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("amrap.pause")
            Button("Round done") { player.send(.roundDone) }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(player.phase != .running)
                .accessibilityIdentifier("amrap.roundDone")
        }
        .controlSize(.large)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// Time up: the rounds done, the extra reps of the unfinished round, and the score.
private struct AMRAPTimeUpView: View {
    let player: AMRAPPlayer

    var body: some View {
        let score = player.score
        Form {
            Section {
                Text("Time’s up")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("amrap.timeUp")
                Stepper(
                    value: Binding(
                        get: { score.extraReps }, set: { player.send(.setExtraReps($0)) }),
                    in: 0...(player.round.repsPerRound - 1)
                ) {
                    LabeledContent("Extra reps") {
                        Text("\(score.extraReps)")
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(score.extraReps)))
                            .animation(.default, value: score.extraReps)
                    }
                }
                .accessibilityValue("\(score.extraReps)")
                .accessibilityIdentifier("amrap.extraReps")
                .sensoryFeedback(.selection, trigger: score.extraReps)
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
    }
}

/// After Save at time up: today's score and last time's.
private struct AMRAPFinishedView: View {
    let player: AMRAPPlayer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: hasAppeared)
                .symbolEffectsRemoved(reduceMotion)
                .accessibilityHidden(true)
            Text(player.score.text)
                .font(.title.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .accessibilityLabel("Score, \(player.score.spokenText)")
                .accessibilityIdentifier("amrap.summary.score")
            Text("Last time: \(player.lastScore?.text ?? "none yet")")
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "Last time, \(player.lastScore?.spokenText ?? "none yet")"
                )
                .accessibilityIdentifier("amrap.summary.lastScore")
            Text("Logged to History.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { hasAppeared = true }
    }
}
