import SwiftUI
import UIKit

extension View {
    /// Runs a guided player's countdown while the view shows: wakes at each next tick or phase end and calls
    /// `advance`, playing the signal it returns through Timer Sounds with its haptic (a light tap per tick, a
    /// warning at the chime). Keeps the screen awake. The countdown keeps running in the background, where nothing
    /// plays; back in the foreground it catches up, with one signal for whatever ended meanwhile.
    func guidedPlayerClock<Step: Equatable>(
        _ countdown: PhasedCountdown<Step>?,
        advance: @escaping () -> PhasedCountdown<Step>.Signal?
    ) -> some View {
        modifier(GuidedPlayerClock(countdown: countdown, advance: advance))
    }
}

/// The wake loop, sounds, haptics and screen lock of `guidedPlayerClock`.
private struct GuidedPlayerClock<Step: Equatable>: ViewModifier {
    let countdown: PhasedCountdown<Step>?
    let advance: () -> PhasedCountdown<Step>.Signal?

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timerSoundEnabled") private var timerSoundEnabled = true
    @State private var sounds = TimerSounds()
    @State private var tickCount = 0
    @State private var chimeCount = 0

    func body(content: Content) -> some View {
        content
            // One sleep until the next tick or phase end, not a polling loop; every change of state restarts it.
            // It stops in the background, so nothing plays there (the countdown's deadlines keep running), and
            // restarts on return, when its first advance catches up with one signal.
            .task(id: WakeKey(state: countdown?.state, isInBackground: scenePhase == .background)) {
                guard scenePhase != .background else { return }
                while let wake = countdown?.nextWake {
                    do {
                        // Zero tolerance: by default the system may wake a long sleep late in proportion to its
                        // length (measured 0.74 s late after 25 s on an iPhone), which made the first tick late.
                        try await Task.sleep(
                            for: .seconds(max(wake.timeIntervalSinceNow, 0)), tolerance: .zero)
                    } catch { return }
                    play(advance())
                }
            }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .sensoryFeedback(.impact(weight: .light), trigger: tickCount)
            .sensoryFeedback(.warning, trigger: chimeCount)
    }

    private struct WakeKey: Equatable {
        let state: PhasedCountdown<Step>.State?
        let isInBackground: Bool
    }

    private func play(_ signal: PhasedCountdown<Step>.Signal?) {
        switch signal {
        case .tick:
            tickCount += 1
            if timerSoundEnabled { sounds.play(.tick) }
        case .chime:
            chimeCount += 1
            if timerSoundEnabled { sounds.play(.chime) }
        case nil: break
        }
    }
}
