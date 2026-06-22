import AVFoundation

final class MetronomeSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer

    init() {
        let sampleRate: Double = 44100
        let duration: Double = 0.03 // 30ms click
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buf.frameLength = frameCount

        // 1500Hz sine with exponential decay — classic wood-block metronome click
        let samples = buf.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 100.0)
            samples[i] = Float(sin(2 * .pi * 1500 * t) * envelope * 0.85)
        }
        buffer = buf

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play() {
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }
    }
}
