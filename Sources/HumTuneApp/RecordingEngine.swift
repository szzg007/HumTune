import Foundation
import AVFoundation
import HumTuneCore

/// 录音引擎：AVAudioEngine 采集 + 实时波形 + 实时音高
@MainActor
final class RecordingEngine: NSObject, ObservableObject {

    enum State {
        case idle
        case recording
        case stopped
    }

    @Published var state: State = .idle
    @Published var samples: [Float] = []
    @Published var liveAmplitude: Float = 0
    @Published var liveFrequency: Double = 0
    @Published var elapsedTime: Double = 0

    private let audioEngine = AVAudioEngine()
    private var sampleRate: Double = 44100.0

    override init() {
        super.init()
    }

    /// 开始录音
    func start() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // 强制 44.1kHz 单声道（避免硬件 48kHz 导致音高偏移）
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 44100.0,
                                         channels: 1,
                                         interleaved: false)!

        sampleRate = targetFormat.sampleRate
        samples = []
        elapsedTime = 0

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            let converter = AVAudioConverter(from: format, to: targetFormat)
            // 转换到目标格式
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            let capacity = Int(targetFormat.sampleRate * Double(buffer.frameLength) / Double(format.sampleRate))
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(capacity)) else { return }
            var error: NSError?
            converter?.convert(to: converted, error: &error, withInputFrom: inputBlock)

            let channelData = converted.floatChannelData![0]
            let frameLength = Int(converted.frameLength)
            var frameSamples: [Float] = []
            frameSamples.reserveCapacity(frameLength)
            for i in 0..<frameLength {
                frameSamples.append(channelData[i])
            }

            Task { @MainActor in
                // 追加采样
                self.samples.append(contentsOf: frameSamples)

                // 实时振幅（RMS）
                var sum: Float = 0
                for s in frameSamples { sum += s * s }
                let rms = sqrt(sum / Float(max(1, frameLength)))
                self.liveAmplitude = min(1, rms * 10)

                // 实时音高（轻量）
                self.elapsedTime += Double(frameLength) / self.sampleRate
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .recording
    }

    /// 停止录音
    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        state = .stopped
    }

    /// 转录当前录音
    func transcribe(onComplete: @escaping (TranscriptionResult) -> Void) {
        let capturedSamples = samples
        guard !capturedSamples.isEmpty else { return }
        // 在后台线程执行
        DispatchQueue.global(qos: .userInitiated).async {
            let transcriber = Transcriber()
            let result = transcriber.transcribe(samples: capturedSamples)
            DispatchQueue.main.async {
                onComplete(result)
            }
        }
    }
}