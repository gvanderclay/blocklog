import SwiftUI

/// The time left in a guided player's current countdown phase, such as a stretch hold or a Timed AMRAP's time cap,
/// updated every second and read aloud as "Time left". The caller sets its font.
struct CountdownText<Step: Equatable>: View {
    let countdown: PhasedCountdown<Step>
    let identifier: String

    var body: some View {
        TimelineView(.periodic(from: countdown.timelineAnchor, by: 1)) { context in
            let seconds = countdown.seconds(at: context.date)
            Text(RestTimer.clock(seconds))
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: seconds)
                .accessibilityLabel("Time left")
                .accessibilityValue(
                    Duration.seconds(seconds).formatted(
                        .units(allowed: [.minutes, .seconds], width: .wide))
                )
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier(identifier)
        }
    }
}
