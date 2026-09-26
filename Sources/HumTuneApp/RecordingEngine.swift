// 实时录音引擎：AVAudioEngine 采集麦克风 → 提取波形 + 实时音高
import AVFoundation
import Combine
import HumTuneCore

@MainActor
final class RecordingEngine: ObservableObject {
    @Published var isRecording = false
    @Published var level: Float = 0            // 当前音量（0-1）
    @Published var currentNote: String = "—"  // 当前识别音名
    @Published var currentFreq: Double = 0     // 当前基频 Hz
    @Published var elapsed: Double = 0

    private let engine = AVAudioEngine()
    private var sampleBuffer: [Float] = []      // 累积采样（采样率采样）
    private let sampleRate = 44100.0

    private let pitchEngine = YINPitchEngine(sampleRate: 44100)
    private let splitter = FrameSplitter(frameLength: 2048, hopLength: 512, sampleRate: 44100)

    var fullSamples: [Float] { sampleBuffer }

    func requestPermission() -> Bool {
        var granted = false
        let sem = DispatchSemaphore(value: 0)
        if #available(macOS 10.14, *) {
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                sem.signal()
            }
        }
        _ = sem.wait(timeout: .now() + 3)
        return granted
    }

    func start() {
        let input = engine.inputNode
        // 强制使用 44.1kHz 单声道浮点格式：让 AVAudioEngine 自动重采样硬件输入
        // （硬件可能是 48kHz，若不统一会导致音高整体偏移）
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: self.sampleRate,
                                   channels: 1,
                                   interleaved: false)!

        sampleBuffer.removeAll()
        currentNote = "—"
        currentFreq = 0
        elapsed = 0

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let chData = buffer.floatChannelData?[0]
            guard let chData = chData else { return }
            let frames = Int(buffer.frameLength)
            let ptr = UnsafeBufferPointer(start: chData, count: frames)

            // 累积采样
            for i in 0..<frames {
                self.sampleBuffer.append(ptr[i])
            }

            // 计算音量
            var sum: Float = 0
            for i in 0..<frames { sum += abs(ptr[i]) }
            let avg = sum / Float(frames)
            Task { @MainActor in
                self.level = min(1, avg * 8)
                self.elapsed = Double(self.sampleBuffer.count) / self.sampleRate
            }

            // 实时音高：取最近一帧 2048 采样
            let count = self.sampleBuffer.count
            if count >= 2048 {
                let start = count - 2048
                let frame = Array(self.sampleBuffer[start..<count]).map { Double($0) }
                let (freq, conf) = self.pitchEngine.estimate(samples: frame)
                Task { @MainActor in
                    if freq > 0 && (conf > 0.15 || avg > 0.002) {
                        self.currentFreq = freq
                        let midi = PitchConverter.midiNote(fromHz: freq)
                        let n = Note(time: 0, duration: 1, pitchHz: freq, midiNote: midi)
                        self.currentNote = n.name
                    } else {
                        self.currentNote = "—"
                        self.currentFreq = 0
                    }
                }
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            print("录音启动失败: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }

    /// 把累积采样转成音符序列（调核心引擎）
    func transcribe() -> Melody {
        let samples = sampleBuffer.map { Double($0) }
        let tracker = PitchTracker(engine: YINPitchEngine(sampleRate: sampleRate),
                                   splitter: FrameSplitter(frameLength: 2048, hopLength: 512, sampleRate: sampleRate))
        let frames = tracker.track(samples: samples)
        let notes = NoteSegmenter().segment(frames: frames)
        let bpm = BPMEstimator.estimate(notes: notes)
        return Melody(notes: notes, bpm: bpm)
    }
}