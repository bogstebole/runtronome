import AVFoundation

final class MetronomeSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        let sampleRate: Double = 44100
        let duration: Double = 0.03
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buf.frameLength = frameCount

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            if !engine.isRunning { try? engine.start() }
            if !player.isPlaying { player.play() }
        default:
            break
        }
    }

    func play() {
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }
    }
}
