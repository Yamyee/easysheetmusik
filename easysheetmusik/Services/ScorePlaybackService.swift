import AVFoundation

final class ScorePlaybackService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private(set) var isPlaying = false
    var onFinish: (() -> Void)?

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(events: [PlaybackEvent]) throws {
        stop()
        guard !events.isEmpty else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        if !engine.isRunning {
            try engine.start()
        }

        for (index, event) in events.enumerated() {
            let buffer = makeBuffer(for: event)
            let isLast = index == events.count - 1
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard isLast else { return }
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.onFinish?()
                }
            }
        }
        isPlaying = true
        player.play()
    }

    func stop() {
        player.stop()
        player.reset()
        isPlaying = false
    }

    private func makeBuffer(for event: PlaybackEvent) -> AVAudioPCMBuffer {
        let duration = max(event.duration, 0.05)
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else {
            return buffer
        }
        channel.initialize(repeating: 0, count: Int(frameCount))
        guard let midiNote = event.midiNote else { return buffer }

        let frequency = 440 * pow(2, (Double(midiNote) - 69) / 12)
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = Double(frame) / Double(frameCount)
            let envelope = min(progress / 0.03, 1) * min((1 - progress) / 0.08, 1)
            channel[frame] = Float(sin(2 * .pi * frequency * time) * 0.16 * max(envelope, 0))
        }
        return buffer
    }
}
