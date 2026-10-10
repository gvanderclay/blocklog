import SwiftData
import SwiftUI

/// The full-screen guided player for a stretch routine, a starter one or a Stretch-format routine: the stretch's
/// name, its cue, the countdown, Easier and Harder chips, up next, and Back, Pause, Skip and +15. The last seconds
/// of each hold tick and its end chimes.
/// Finishing logs the routine as a workout; Finish before the end asks whether to save what was done or discard it. The screen stays
/// awake while it shows, and leaving the app pauses it.
struct StretchPlayerScreen: View {
    let player: StretchPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var addCount = 0
    @State private var askingToSave = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if player.countdown.isFinished {
                    StretchFinishedView(logged: player.loggedWorkout != nil)
                } else {
                    StretchStepView(player: player)
                        .safeAreaInset(edge: .bottom) {
                            StretchControls(player: player) { addCount += 1 }
                        }
                }
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if player.countdown.isFinished {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { saveAndClose() }
                            .accessibilityIdentifier("stretch.done")
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Finish") { askingToSave = true }
                            .accessibilityIdentifier("stretch.finish")
                    }
                }
            }
        }
        .guidedPlayerClock(
            player.countdown, advance: { player.countdown.advance() },
            pause: { player.countdown.pause() }
        )
        .onChange(of: player.countdown.isFinished) { _, finished in
            // Ending with the Finish dialog open ends as it would without it.
            if finished {
                askingToSave = false
                save()
            }
        }
        .sensoryFeedback(.selection, trigger: addCount)
        .sensoryFeedback(trigger: player.loggedWorkout != nil) { _, logged in
            logged ? .success : nil
        }
        .confirmationDialog(
            "Finish early?", isPresented: $askingToSave, titleVisibility: .visible
        ) {
            Button("Save What I Did") { saveAndClose() }
                .accessibilityIdentifier("stretch.save")
            Button("Discard", role: .destructive) { dismiss() }
                .accessibilityIdentifier("stretch.discard")
            Button("Keep Going", role: .cancel) {}
                .accessibilityIdentifier("stretch.keepGoing")
        } message: {
            Text(
                "Save What I Did logs the holds so far, the current one for the seconds held, to History."
            )
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// Logs what was done; false, with the alert, when the save failed.
    @discardableResult
    private func save() -> Bool {
        do {
            _ = try player.log(in: modelContext)
            return true
        } catch {
            saveFailed = true
            return false
        }
    }

    private func saveAndClose() {
        if save() { dismiss() }
    }
}

/// The current step: round, stretch name, lead-in or side, countdown, cue with Easier and Harder, and up next.
private struct StretchStepView: View {
    let player: StretchPlayer

    @State private var variation: Variation?

    private enum Variation { case easier, harder }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let round = player.roundText {
                    Text(round)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(player.stretchName ?? "")
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("stretch.name")
                if let status = player.countdown.isPaused ? "Paused" : player.step?.status {
                    Text(status)
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .accessibilityIdentifier("stretch.status")
                }
                CountdownText(countdown: player.countdown, identifier: "stretch.countdown")
                    .font(.largeTitle.weight(.semibold))
                if let cue = player.cue {
                    Text(cue.cue)
                        .multilineTextAlignment(.center)
                    HStack {
                        chip("Easier", .easier, identifier: "stretch.easier")
                        chip("Harder", .harder, identifier: "stretch.harder")
                    }
                    if let variation {
                        Text(variation == .easier ? cue.easier : cue.harder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("stretch.variation")
                    }
                }
                Text(player.upNext.map { "Up next: \($0)" } ?? "Last stretch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("stretch.upNext")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .animation(.default, value: player.countdown.index)
        }
        .onChange(of: player.stretchName) { variation = nil }
    }

    private func chip(_ title: String, _ chip: Variation, identifier: String) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { variation == chip },
                set: { variation = $0 ? chip : nil })
        )
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .accessibilityIdentifier(identifier)
    }
}

/// Back, Pause or Resume, Skip and +15.
private struct StretchControls: View {
    let player: StretchPlayer
    /// Called for +15, for its haptic.
    let added: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Back", systemImage: "backward.fill") { player.back() }
                .accessibilityIdentifier("stretch.back")
            Button(
                player.countdown.isPaused ? "Resume" : "Pause",
                systemImage: player.countdown.isPaused ? "play.fill" : "pause.fill"
            ) { player.togglePause() }
            .accessibilityIdentifier("stretch.pause")
            // During a lead-in the button starts its hold, so it says so; during a hold it skips it.
            if player.step?.kind == .leadIn {
                Button("Start Now") { player.skip() }
                    .font(.headline)
                    .accessibilityIdentifier("stretch.startNow")
            } else {
                Button("Skip", systemImage: "forward.fill") { player.skip() }
                    .accessibilityIdentifier("stretch.skip")
            }
            Button("+15") {
                added()
                player.addTime()
            }
            .accessibilityLabel("Add 15 seconds")
            .accessibilityIdentifier("stretch.addTime")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// The end of the routine.
private struct StretchFinishedView: View {
    let logged: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Routine done")
                .font(.title2.weight(.semibold))
            if logged {
                Text("Logged to History.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stretch.finished")
    }
}
