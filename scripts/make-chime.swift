// Synthesizes the timer sounds, written as 16-bit mono linear PCM, a format notification sounds accept:
// - rest-chime.caf: two soft bell tones a fifth apart (A5 then E6), about 0.6 seconds, ending a rest or a hold;
// - timer-tick.caf: one short, quiet wood-block click (E6), about 0.05 seconds, for a guided player's last seconds.
// Run with `just chime` from the repository root.

import AVFoundation

let sampleRate = 44_100.0

/// One bell tone: a sine with a quiet octave partial, a 12 ms attack and an exponential decay.
func tone(frequency: Double, start: Double, at time: Double) -> Double {
    let t = time - start
    guard t >= 0 else { return 0 }
    let attack = min(t / 0.012, 1)
    let decay = exp(-t / 0.16)
    let wave =
        sin(2 * .pi * frequency * t) + 0.25 * sin(2 * .pi * 2 * frequency * t) * exp(-t / 0.05)
    return wave * attack * decay
}

/// Samples `duration` seconds of `sound`, fading the last `fade` seconds to silence so the file never ends on a
/// click, normalized to a peak of `peak` (full scale is 1).
func render(duration: Double, fade: Double, peak: Double, _ sound: (Double) -> Double) -> [Double] {
    let frameCount = Int(sampleRate * duration)
    let samples = (0..<frameCount).map { index -> Double in
        let time = Double(index) / sampleRate
        return sound(time) * min((duration - time) / fade, 1)
    }
    let loudest = samples.map(abs).max()!
    return samples.map { $0 / loudest * peak }
}

func write(_ samples: [Double], to path: String) throws {
    let output = URL(filePath: path)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    for (index, sample) in samples.enumerated() {
        buffer.floatChannelData![0][index] = Float(sample)
    }
    try? FileManager.default.removeItem(at: output)
    let file = try AVAudioFile(
        forWriting: output,
        settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ])
    try file.write(from: buffer)
    file.close()
    print("wrote \(output.relativePath)")
}

// A soft peak of −6 dBFS.
try write(
    render(duration: 0.6, fade: 0.06, peak: 0.5) { time in
        tone(frequency: 880, start: 0, at: time) + tone(frequency: 1318.51, start: 0.15, at: time)
    }, to: "App/Resources/rest-chime.caf")

// Quieter than the chime, at −12 dBFS, with a 2 ms attack and a fast decay, so a tick never covers the chime.
try write(
    render(duration: 0.05, fade: 0.01, peak: 0.25) { time in
        sin(2 * .pi * 1318.51 * time) * min(time / 0.002, 1) * exp(-time / 0.012)
    }, to: "App/Resources/timer-tick.caf")
