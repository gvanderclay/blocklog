import SwiftUI

/// The full-screen stopwatch for a live workout's duration set: before Start, the goal with − and + and Start;
/// then "Get ready" counting 5 to 1 with Start Now; then the count up, "0:30 / 0:45", with Stop. Cancel closes it at
/// any time with nothing written. It keeps the screen awake, and the count keeps going in the background.
struct StopwatchScreen: View {
    let stopwatch: Stopwatch
    /// Called with the whole seconds counted when Stop is tapped; the caller logs them and closes the screen. When it
    /// throws, the screen stays, still counting, so Stop can be tried again.
    let onStop: (Int) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Group {
                switch stopwatch.phase {
                case .setup: setup
                case .getReady, .running:
                    StopwatchRunView(stopwatch: stopwatch)
                        .safeAreaInset(edge: .bottom) { controls }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("stopwatch.cancel")
                }
            }
        }
        .guidedPlayerClock(stopwatch.countdown, chimeFeedback: .success) {
            let signal = stopwatch.advance()
            if signal == .chime { AccessibilityNotification.Announcement("Goal reached").post() }
            return signal
        }
        .saveFailedAlert(isPresented: $saveFailed)
    }

    /// "Plank · Set 1".
    private var title: String {
        let exercise = stopwatch.set.workoutExercise?.exercise?.name ?? "Exercise"
        return "\(exercise) · \(SetNumbering.spokenName(of: stopwatch.set))"
    }

    private var setup: some View {
        List {
            Section {
                let stacks = dynamicTypeSize.isAccessibilitySize
                let layout =
                    stacks
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout())
                layout {
                    Text("Goal")
                        .accessibilityHidden(true)
                    if !stacks { Spacer() }
                    goalControls
                }
                .buttonStyle(.borderless)
                .sensoryFeedback(.selection, trigger: stopwatch.goal)
            } footer: {
                Text("The goal is for this run only. The time keeps counting past it.")
            }
            Section {
                Button("Start") { stopwatch.start() }
                    .accessibilityIdentifier("stopwatch.start")
            } footer: {
                Text("Counts up after a \(Stopwatch.getReadySeconds)-second get-ready countdown.")
            }
        }
    }

    /// − goal +; the goal never wraps.
    private var goalControls: some View {
        HStack {
            Button("Decrease goal", systemImage: "minus") { stopwatch.decreaseGoal() }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .disabled(!stopwatch.canDecreaseGoal)
                .accessibilityIdentifier("stopwatch.goalMinus")
            Text(stopwatch.goal.map(RestTimer.clock) ?? "No goal")
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(stopwatch.goal ?? 0)))
                .animation(.default, value: stopwatch.goal)
                .fixedSize()
                .frame(minWidth: 72)
                .accessibilityLabel("Goal")
                .accessibilityValue(Self.spoken(goal: stopwatch.goal))
                .accessibilityIdentifier("stopwatch.goal")
            Button("Increase goal", systemImage: "plus") { stopwatch.increaseGoal() }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .disabled(!stopwatch.canIncreaseGoal)
                .accessibilityIdentifier("stopwatch.goalPlus")
        }
    }

    /// Pause or Resume, beside Start Now during get ready, then Stop, enabled once a second has counted.
    private var controls: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout =
            isLarge
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button(
                stopwatch.isPaused ? "Resume" : "Pause",
                systemImage: stopwatch.isPaused ? "play.fill" : "pause.fill"
            ) {
                if stopwatch.isPaused { stopwatch.resume() } else { stopwatch.pause() }
            }
            .bottomBarLabels(isLarge: isLarge)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("stopwatch.pause")
            if stopwatch.phase == .getReady {
                Button {
                    stopwatch.startNow()
                } label: {
                    Text("Start Now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(stopwatch.isPaused)
                .accessibilityIdentifier("stopwatch.startNow")
            } else {
                TimelineView(.periodic(from: stopwatch.countStart ?? .now, by: 1)) { context in
                    let date = context.date
                    Button {
                        do { try onStop(stopwatch.elapsed(at: .now)) } catch { saveFailed = true }
                    } label: {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!stopwatch.canStop(at: date))
                    .accessibilityIdentifier("stopwatch.stop")
                }
            }
        }
        .font(.headline)
        .controlSize(.large)
        .bottomBarTextFit()
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    /// "45 seconds", "1 minute, 30 seconds" or "No goal".
    static func spoken(goal: Int?) -> String {
        guard let goal else { return "No goal" }
        return Duration.seconds(goal).formatted(
            .units(allowed: [.minutes, .seconds], width: .wide))
    }
}

/// "Get ready" with the 5…1 countdown, then the big count up with the goal, green once reached.
private struct StopwatchRunView: View {
    let stopwatch: Stopwatch

    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 72

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Always laid out, so Pause and Resume don't move the count.
                Text(status ?? " ")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .opacity(status == nil ? 0 : 1)
                    .accessibilityHidden(status == nil)
                    .accessibilityIdentifier("stopwatch.status")
                if stopwatch.phase == .getReady, let countdown = stopwatch.countdown {
                    VStack(spacing: 8) {
                        CountdownText(countdown: countdown, identifier: "stopwatch.countdown")
                            .font(.system(size: countSize, weight: .semibold))
                        // Takes the goal line's place, so the count doesn't move when the run starts.
                        if let goal = stopwatch.goal {
                            Text(RestTimer.clock(goal))
                                .font(.title.weight(.semibold))
                                .fontDesign(.rounded)
                                .monospacedDigit()
                                .hidden()
                        }
                    }
                } else if let countStart = stopwatch.countStart {
                    TimelineView(.periodic(from: countStart, by: 1)) { context in
                        count(at: context.date)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        // Centred while it fits; at large text sizes it scrolls.
        .defaultScrollAnchor(.center, for: .alignment)
    }

    private var status: String? {
        if stopwatch.isPaused { return "Paused" }
        return stopwatch.phase == .getReady ? "Get ready" : nil
    }

    private func count(at date: Date) -> some View {
        let elapsed = stopwatch.elapsed(at: date)
        let isReached = stopwatch.isGoalReached(at: date)
        return VStack(spacing: 8) {
            Text(RestTimer.clock(elapsed))
                .font(.system(size: countSize, weight: .semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(elapsed)))
                .animation(.default, value: elapsed)
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(
                    Duration.seconds(elapsed).formatted(
                        .units(allowed: [.minutes, .seconds], width: .wide))
                )
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("stopwatch.elapsed")
            if let goal = stopwatch.goal {
                Label {
                    Text("Goal \(RestTimer.clock(goal))")
                } icon: {
                    // Space is kept, so reaching the goal doesn't shift the line.
                    Image(systemName: "checkmark").opacity(isReached ? 1 : 0)
                }
                .font(.title.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(isReached ? Color.green : Color.secondary)
                .accessibilityLabel("Goal")
                .accessibilityValue(
                    StopwatchScreen.spoken(goal: goal) + (isReached ? ", reached" : "")
                )
                .accessibilityIdentifier("stopwatch.goal")
            }
        }
    }
}
