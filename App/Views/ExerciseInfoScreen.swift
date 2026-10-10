import AVFoundation
import SwiftUI
import UIKit

/// An exercise's name, its looping animation when it has one, its muscle group and its equipment. The exercise
/// picker pushes it; a workout's exercise menu opens it in a sheet, with Done.
struct ExerciseInfoScreen: View {
    let exercise: Exercise
    /// True in a sheet, which needs a Done button to close.
    var showsDone = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if let animation = ExerciseAnimation.animation(for: exercise) {
                    AnimationClip(animation: animation)
                        .listRowInsets(EdgeInsets())
                }
            } header: {
                Text(exercise.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("exerciseInfo.name")
            }
            Section {
                LabeledContent("Muscle Group", value: exercise.muscleGroup.title)
                LabeledContent("Equipment", value: exercise.equipment.title)
            }
        }
        .navigationTitle("Exercise Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("exerciseInfo.done")
                }
            }
        }
    }
}

/// The clip, square and full width, looping muted on the cell background. A tap plays or pauses it; the still
/// shows under Reduce Motion until a tap, and until the first frame is ready.
private struct AnimationClip: View {
    let animation: ExerciseAnimation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var playback = ExerciseAnimation.Playback(reduceMotion: true)
    @State private var player: AVQueuePlayer?
    /// Kept, or the clip stops looping when it is released.
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Button {
            playback.toggle()
        } label: {
            ZStack {
                if let player {
                    PlayerLayerView(player: player, runs: playback.runs) {
                        playback.frameBecameReady()
                    }
                }
                if playback.showsStill, let still = UIImage(contentsOfFile: animation.still.path) {
                    Image(uiImage: still)
                        .resizable()
                        .scaledToFit()
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(animation.description)
        .accessibilityValue(playback.isPlaying ? "Playing" : "Paused")
        .accessibilityIdentifier("exerciseInfo.animation")
        .onAppear {
            playback = ExerciseAnimation.Playback(reduceMotion: reduceMotion)
            playback.sceneChanged(isActive: scenePhase == .active)
            guard player == nil else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            // A looping clip shouldn't keep the screen awake.
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: animation.clip))
            self.player = player
        }
        .onDisappear { player?.pause() }
        .onChange(of: reduceMotion) { playback.reduceMotionChanged(to: reduceMotion) }
        .onChange(of: scenePhase) { playback.sceneChanged(isActive: scenePhase == .active) }
    }
}

/// Shows the player in an `AVPlayerLayer` on a clear background, so the clip's alpha shows the cell behind it,
/// runs or pauses it, and reports when its first frame is ready.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    let runs: Bool
    let onReady: () -> Void

    final class LayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var onReady: () -> Void = {}
        private var readyObservation: NSKeyValueObservation?

        func observeReadiness() {
            readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) {
                [weak self] layer, _ in
                guard layer.isReadyForDisplay else { return }
                Task { @MainActor in self?.onReady() }
            }
        }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        view.onReady = onReady
        view.observeReadiness()
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.onReady = onReady
        if runs {
            player.play()
        } else {
            player.pause()
        }
    }
}
