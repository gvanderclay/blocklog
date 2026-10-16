import SwiftUI

/// The rest countdown pinned to the bottom of the workout screen: a draining ring, the time left, and
/// −15, +15 and Skip. Past the end it counts up in overtime with only Skip. One `TimelineView` ticking on
/// the end date's seconds drives every update; the end itself is signalled by `RootView`.
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var restTimer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var adjustCount = 0

    var body: some View {
        TimelineView(.periodic(from: restTimer.timelineAnchor, by: 1)) { context in
            content(restTimer.reading(at: context.date))
        }
        // A new timeline on every phase change, so returning to the app reads the time at once instead of
        // showing the last tick until the old timeline's next one.
        .id(scenePhase)
        .padding()
        .background(.bar)
        .sensoryFeedback(.selection, trigger: adjustCount)
    }

    private func content(_ reading: RestTimer.Reading) -> some View {
        let shown = reading.seconds
        let isOvertime = reading.isOvertime
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let clock = HStack(spacing: 12) {
            RestRing(
                progress: reading.progress, seconds: reading.countdownSeconds, isCapped: isLarge)
            Text(isOvertime ? RestTimer.overtimeClock(shown) : RestTimer.clock(shown))
                // Overtime and countdown are different views, so a new rest swaps the text instead of
                // rolling "+0:10" into "1:30".
                .id(isOvertime)
                .transition(.identity)
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: shown)
                .accessibilityLabel(isOvertime ? "Rest overtime" : "Rest remaining")
                .accessibilityValue(
                    Duration.seconds(shown).formatted(
                        .units(allowed: [.minutes, .seconds], width: .wide))
                )
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("restTimer.remaining")
        }
        let skip = Button("Skip") {
            withAnimation { restTimer.skip() }
        }
        .accessibilityIdentifier("restTimer.skip")
        // At accessibility sizes the clock and Skip share the first row and −15 and +15 the second, so the
        // bar stays slim and no label breaks.
        return Group {
            if isLarge {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        clock
                        Spacer(minLength: 0)
                        skip
                    }
                    if !isOvertime {
                        HStack(spacing: 12) {
                            adjustButton(-15, identifier: "restTimer.minus15")
                            adjustButton(15, identifier: "restTimer.plus15")
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    clock
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        if !isOvertime {
                            adjustButton(-15, identifier: "restTimer.minus15")
                            adjustButton(15, identifier: "restTimer.plus15")
                        }
                        skip
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .bottomBarTextFit()
        .sensoryFeedback(trigger: reading.countdownSeconds) { old, new in
            RestTimer.isCountdownTick(from: old, to: new) ? .impact(weight: .light) : nil
        }
    }

    private func adjustButton(_ seconds: Int, identifier: String) -> some View {
        Button(seconds < 0 ? "−15" : "+15") {
            adjustCount += 1
            withAnimation { restTimer.add(seconds: seconds) }
        }
        .accessibilityLabel(seconds < 0 ? "Subtract 15 seconds" : "Add 15 seconds")
        .accessibilityIdentifier(identifier)
    }
}

/// A ring that drains as the rest runs out. It animates linearly between ticks, so it looks continuous.
private struct RestRing: View {
    let progress: Double
    let seconds: Int
    /// Keeps the ring from growing with the text, so the bar stays slim at accessibility sizes.
    let isCapped: Bool

    @ScaledMetric(relativeTo: .title2) private var scaledSize = 36
    private var size: CGFloat { isCapped ? 44 : scaledSize }

    var body: some View {
        Circle()
            .stroke(.quaternary, lineWidth: 4)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // Linear only for the timeline's ticks, which carry no animation; Skip and ±15 keep theirs, or the
                    // arc would take a second to follow the bar off screen.
                    .transaction(value: seconds) {
                        if $0.animation == nil { $0.animation = .linear(duration: 1) }
                    }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
