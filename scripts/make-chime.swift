// Synthesizes the rest-end chime: two soft bell tones a fifth apart (A5 then E6),
// about 0.6 seconds, written as 16-bit mono linear PCM, a format notification sounds accept.
// Run with `just chime` from the repository root.

import AVFoundation

let sampleRate = 44_100.0
let duration = 0.6
let output = URL(filePath: "App/Resources/rest-chime.caf")

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

let frameCount = Int(sampleRate * duration)
var samples = (0..<frameCount).map { index -> Double in
    let time = Double(index) / sampleRate
    // The last 60 ms fade to silence so the file never ends on a click.
    let tail = min((duration - time) / 0.06, 1)
    return
        (tone(frequency: 880, start: 0, at: time) + tone(frequency: 1318.51, start: 0.15, at: time))
        * tail
}
// Normalize to a soft peak of −6 dBFS.
let peak = samples.map(abs).max()!
samples = samples.map { $0 / peak * 0.5 }

let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
buffer.frameLength = AVAudioFrameCount(frameCount)
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
