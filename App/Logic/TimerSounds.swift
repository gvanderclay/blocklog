import AVFoundation

/// Plays the timer sounds with the ambient audio category: they mix with the user's music, never pausing or
/// ducking it, and the silent switch mutes them. The callers check the Timer Sounds setting.
@MainActor
final class TimerSounds {
    enum Sound: String {
        /// `rest-chime.caf`: the end of a rest or a hold.
        case chime = "rest-chime"
        /// `timer-tick.caf`: one of a hold's last seconds.
        case tick = "timer-tick"
    }

    private var player: AVAudioPlayer?

    func play(_ sound: Sound) {
        // A missing file or a failed audio setup only loses the sound; the haptic still tells the user.
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
            (try? AVAudioSession.sharedInstance().setCategory(.ambient)) != nil,
            let player = try? AVAudioPlayer(contentsOf: url)
        else { return }
        self.player = player  // kept, or it stops when released
        player.play()
    }
}
