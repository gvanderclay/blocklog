import AVFoundation

/// Plays `rest-chime.caf` through an ambient audio session: it mixes with the user's music, never pausing or
/// ducking it, and the silent switch mutes it.
@MainActor
final class RestChime {
    private var player: AVAudioPlayer?

    func play() {
        // A missing file or a failed session only loses the sound; the haptic still tells the user.
        guard let url = Bundle.main.url(forResource: "rest-chime", withExtension: "caf"),
            (try? AVAudioSession.sharedInstance().setCategory(.ambient)) != nil,
            let player = try? AVAudioPlayer(contentsOf: url)
        else { return }
        self.player = player  // kept, or it stops when released
        player.play()
    }
}
