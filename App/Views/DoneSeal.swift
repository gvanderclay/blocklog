import SwiftUI

/// The green seal on the workout, AMRAP and stretch summaries: it bounces once when it appears, and not under Reduce
/// Motion.
struct DoneSeal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.largeTitle)
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: hasAppeared)
            .symbolEffectsRemoved(reduceMotion)
            .accessibilityHidden(true)
            .onAppear { hasAppeared = true }
    }
}
