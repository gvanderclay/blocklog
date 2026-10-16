import SwiftData
import SwiftUI

/// The full-screen guided player for a Timed AMRAP: before Start, the dumbbell weights, the round and last time's
/// score; then the get-ready countdown, the big countdown with the round number and the round's exercises, Round
/// done and Pause; at time up, the rounds, the extra reps and Save; then today's and last time's score. Finish before
/// time up asks whether to end early, for the extra reps and Save, or discard it. The screen stays awake while it shows,
/// and the clock keeps running in the background.
struct AMRAPPlayerScreen: View {
    let player: AMRAPPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var askingToSave = false
    /// The progress shown in the Finish dialog, taken when Finish is tapped, since a dialog's message can't tick.
    @State private var finishProgress = ""
    @State private var saveFailed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // With Reduce Motion the swap is a cut, not a cross-fade.
        let fade: AnyTransition = reduceMotion ? .identity : .opacity
        NavigationStack {
            // A ZStack, not a Group: a Group passes .animation(value:) to each branch, and a branch that is just
            // inserted never sees the value change.
            ZStack {
                switch player.phase {
                case .setup: AMRAPSetupView(player: player)
                case .getReady, .running, .paused:
                    AMRAPRunView(player: player)
                        .safeAreaInset(edge: .bottom) { AMRAPControls(player: player) }
                        .transition(fade)
                case .timeUp:
                    AMRAPTimeUpView(player: player) { _ = save() }
                        .transition(fade)
                case .finished:
                    AMRAPFinishedView(player: player)
                        .transition(fade)
                }
            }
            .animation(.default, value: player.phase == .timeUp)
            .animation(.default, value: player.phase == .finished)
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                switch player.phase {
                case .finished:
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("amrap.done")
                    }
                case .setup:
                    // Nothing has started, so there is nothing to save or discard.
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("amrap.cancel")
                    }
                case .timeUp:
                    finishItem(title: "Discard")
                default:
                    finishItem(title: "Finish")
                }
            }
        }
        .guidedPlayerClock(player.countdown, advance: { player.advance() })
        // Time up with the Finish dialog open goes on as it would without it.
        .onChange(of: player.phase) { _, phase in
            if phase == .timeUp {
                askingToSave = false
                if !player.endedEarly { AccessibilityNotification.Announcement("Time’s up").post() }
            }
        }
        .onChange(of: player.roundNumber) { _, round in
            if player.phase == .running {
                AccessibilityNotification.Announcement("Round \(round)").post()
            }
        }
        // Round done only; correcting the rounds at time up gives the stepper's selection tick instead.
        .sensoryFeedback(trigger: player.score.rounds) { _, _ in
            player.phase == .running ? .success : nil
        }
        .sensoryFeedback(trigger: player.loggedWorkout != nil) { _, logged in
            logged ? .success : nil
        }
        .confirmationDialog(
            player.phase == .timeUp ? "Discard your score?" : "Finish early?",
            isPresented: $askingToSave, titleVisibility: .visible
        ) {
            if player.phase != .timeUp {
                Button("End Early") { player.send(.finishEarly) }
                    .accessibilityIdentifier("amrap.endEarly")
            }
            Button("Discard", role: .destructive) { dismiss() }
                .accessibilityIdentifier("amrap.discard")
            Button(player.phase == .timeUp ? "Cancel" : "Keep Going", role: .cancel) {}
                .accessibilityIdentifier("amrap.keepGoing")
        } message: {
            if player.phase != .timeUp {
                Text(
                    "\(finishProgress)\nStops the clock. Then add the reps of the round you’re in and save."
                )
            }
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// Finish, or Discard at time up beside Save; either asks before closing.
    private func finishItem(title: String) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(title) {
                finishProgress = player.progressText(at: .now)
                askingToSave = true
            }
            .accessibilityIdentifier("amrap.finish")
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
                // Always laid out, so Get ready and Pause don't move the countdown.
                Text(status ?? " ")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .opacity(status == nil ? 0 : 1)
                    .contentTransition(.identity)
                    .accessibilityHidden(status == nil)
                    .accessibilityIdentifier("amrap.status")
                if let countdown = player.countdown {
                    // A new view per step, so the digits don't roll from 0:01 to 20:00 as the run starts.
                    CountdownText(countdown: countdown, identifier: "amrap.countdown")
                        .font(.system(size: countdownSize, weight: .semibold))
                        .id(countdown.index)
                        .transition(.identity)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility sizes Pause sits above the wide button, with its title.
    var body: some View {
        let isPaused = player.phase == .paused
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout =
            isLarge
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Button(
                isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill"
            ) { player.send(isPaused ? .resume : .pause) }
            .bottomBarLabels(isLarge: isLarge)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("amrap.pause")
            // During get ready, Start Now takes Round done's place, which can't be tapped until the clock runs.
            if player.phase == .getReady {
                // The frame sits on the label, so the visible button fills the row beside Pause.
                Button {
                    player.send(.startNow)
                } label: {
                    Text("Start Now").frame(maxWidth: .infinity)
                }
                .font(.headline)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("amrap.startNow")
            } else {
                Button {
                    player.send(.roundDone)
                } label: {
                    Text("Round done").frame(maxWidth: .infinity)
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .disabled(player.phase != .running)
                .accessibilityIdentifier("amrap.roundDone")
            }
        }
        .controlSize(.large)
        .bottomBarTextFit()
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
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
