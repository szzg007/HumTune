import Foundation
import AVFoundation
import HumTuneCore

/// 旋律播放器：播放转录结果，支持单音试听
@MainActor
final class AudioPlayer: ObservableObject {

    @Published var isPlaying = false

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100.0
    private let synth = SynthEngine()

    /// 播放完整旋律
    func play(notes: [Note], waveform: SynthEngine.Waveform = .sine) {
        stop()
        guard !notes.isEmpty else { return }
        let samples = synth.render(notes: notes, waveform: waveform, sampleRate: sampleRate)
        scheduleAndPlay(samples: samples)
    }

    /// 试听单个音符
    func previewNote(midi: Int, waveform: SynthEngine.Waveform = .sine) {
        stop()
        let samples = synth.renderNote(midi: midi, waveform: waveform, sampleRate: sampleRate)
        scheduleAndPlay(samples: samples)
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
    }

    // MARK: - Private

    private func scheduleAndPlay(samples: [Float]) {
        guard !samples.isEmpty else { return }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<samples.count {
            channelData[i] = samples[i]
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        self.engine = engine
        self.playerNode = player

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        })

        engine.prepare()
        try? engine.start()
        player.play()
        isPlaying = true
    }
}