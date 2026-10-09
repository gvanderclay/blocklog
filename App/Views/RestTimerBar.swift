import SwiftUI

/// The rest countdown pinned to the bottom of the workout screen: a draining ring, the time left, and
/// −15, +15 and Skip. Past the end it counts up in overtime with only Skip. One `TimelineView` ticking on
/// the end date's seconds drives every update; the end itself is signalled by `RootView`.
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var restTimer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var adjustCount = 0
    @State private var previewWeights: PreviewWeights?

    private struct PreviewWeights: Identifiable {
        let now: Double
        let next: Double
        var id: Double { now * 1000 + next }
    }

    var body: some View {
        // Anchored at the rest's start, in the past (a future anchor freezes the view until it arrives); whole
        // seconds of total keep every tick on the end date's seconds.
        let anchor =
            restTimer.endDate.map { $0.addingTimeInterval(-(restTimer.total ?? 0)) } ?? .now
        VStack(spacing: 8) {
            TimelineView(.periodic(from: anchor, by: 1)) { context in
                let remaining = restTimer.remaining(at: context.date)
                content(
                    seconds: Int(remaining.rounded(.up)), remaining: remaining,
                    overtime: restTimer.overtime(at: context.date),
                    isOvertime: restTimer.isOvertime(at: context.date))
            }
            changeHint
        }
        .padding()
        .background(.bar)
        .sensoryFeedback(.selection, trigger: adjustCount)
    }

    /// What to change on the block for the next set; fades in, and cross-fades when the next weight is edited.
    @ViewBuilder private var changeHint: some View {
        let weights = restTimer.checkedSet.flatMap { NextSet.weights(after: $0) }
        let line = weights.flatMap { PowerBlockTable.changeLine(from: $0.now, to: $0.next) }
        ZStack {
            if let weights, let line {
                Button {
                    previewWeights = PreviewWeights(now: weights.now, next: weights.next)
                } label: {
                    Text(line)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .id(line)
                .transition(.opacity)
                .accessibilityHint("Shows the block change")
                .accessibilityIdentifier("restTimer.change")
            }
        }
        .animation(.default, value: line)
        .sheet(item: $previewWeights) { ChangePreviewSheet(now: $0.now, next: $0.next) }
    }

    private func content(
        seconds: Int, remaining: TimeInterval, overtime: TimeInterval, isOvertime: Bool
    ) -> some View {
        let shown = isOvertime ? Int(overtime) : seconds
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack(spacing: 12) {
                RestRing(progress: remaining / (restTimer.total ?? 1), seconds: seconds)
                Text(isOvertime ? RestTimer.overtimeClock(shown) : RestTimer.clock(shown))
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
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 8) {
                if !isOvertime {
                    adjustButton(-15, identifier: "restTimer.minus15")
                    adjustButton(15, identifier: "restTimer.plus15")
                }
                Button("Skip") {
                    withAnimation { restTimer.skip() }
                }
                .accessibilityIdentifier("restTimer.skip")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .sensoryFeedback(trigger: seconds) { old, new in
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

    @ScaledMetric(relativeTo: .title2) private var size = 36

    var body: some View {
        Circle()
            .stroke(.quaternary, lineWidth: 4)
            .overlay {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: seconds)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
