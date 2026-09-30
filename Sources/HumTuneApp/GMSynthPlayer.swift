import Foundation
import AVFoundation
import HumTuneCore

/// GM 采样播放引擎：加载 macOS 系统 GM 音色库（128 真乐器音色）
/// 替代 v1 的波形合成——「换乐器」能听到真正的钢琴/小提琴/长笛音色。
/// 若系统音色库加载失败，自动回退到波形合成器，保证 app 始终可用。
///
/// 关键设计：采样器 engine 一旦启动就长期保持运行（不随 stop 销毁），
/// 否则 AVAudioUnitSampler 会因 engine stop 而永久静音。
@MainActor
final class GMSynthPlayer: ObservableObject {

    @Published var isPlaying = false
    @Published var playingIndex = 0
    @Published var instrumentLoaded = false

    // 采样器路径（长期保持运行）
    private var sampler: AVAudioUnitSampler?
    private var samplerEngine: AVAudioEngine?

    private let sampleRate: Double = 44100.0
    private let fallbackSynth = SynthEngine()
    private var currentProgram: Int = 0
    private var playTask: Task<Void, Never>?
    private var samplerReady = false

    // 回退 PCM 播放（仅当采样器不可用时，每次新建）
    private var fallbackEngine: AVAudioEngine?
    private var fallbackPlayerNode: AVAudioPlayerNode?

    /// 系统 GM 音色库路径（macOS 自带，128 音色）
    private static let soundBankURL: URL? = {
        let path = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }()

    init() {
        setupSampler()
    }

    // MARK: - 采样器初始化

    private func setupSampler() {
        guard let url = Self.soundBankURL else {
            print("⚠️ 系统 GM 音色库不存在，回退波形合成")
            return
        }

        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        do {
            // 加载 GM 音色库，先选 program 0（大钢琴）
            try sampler.loadSoundBankInstrument(at: url, program: 0, bankMSB: 0x79, bankLSB: 0)
            engine.prepare()
            try engine.start()
            // 长期保持 engine 运行，不随 stop 销毁
            self.samplerEngine = engine
            self.sampler = sampler
            self.samplerReady = true
            self.instrumentLoaded = true
            print("✅ GM 音色库已加载：128 音色可用")
        } catch {
            print("⚠️ GM 音色库加载失败，回退波形合成：\(error)")
            self.samplerReady = false
            self.samplerEngine = nil
            self.sampler = nil
        }
    }

    // MARK: - 音色切换

    /// 切换音色（program 0~127）
    func selectInstrument(_ program: Int) {
        currentProgram = max(0, min(127, program))
        if samplerReady, let sampler = sampler {
            sampler.sendProgramChange(UInt8(currentProgram), onChannel: 0)
        }
    }

    func currentInstrument() -> Int {
        return currentProgram
    }

    // MARK: - 播放

    /// 试听单个音符
    func previewNote(midi: Int) {
        stop()
        let m = UInt8(max(0, min(127, midi)))
        if samplerReady, let sampler = sampler {
            sampler.startNote(m, withVelocity: 100, onChannel: 0)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.sampler?.stopNote(m, onChannel: 0)
            }
        } else {
            let samples = fallbackSynth.renderNote(midi: midi, duration: 0.5)
            playPCM(samples: samples)
        }
    }

    /// 播放整段旋律（逐步，带 playhead 光标）
    func play(notes: [Note], instrument: Int) {
        stop()
        guard !notes.isEmpty else { return }
        selectInstrument(instrument)

        let sorted = notes.sorted { $0.startTime < $1.startTime }
        isPlaying = true

        playTask = Task { [weak self] in
            guard let self = self else { return }
            for (idx, note) in sorted.enumerated() {
                guard !Task.isCancelled else { break }
                self.playingIndex = idx
                self.startNote(midi: note.midi)
                let seconds = max(0.05, note.duration)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                self.stopNote(midi: note.midi)
            }
            self.playingIndex = 0
            self.isPlaying = false
        }
    }

    /// 停止播放：只停音符，【不销毁采样器 engine】
    func stop() {
        playTask?.cancel()
        playTask = nil

        // 采样器路径：停掉所有发声的音符，engine 保持运行
        if samplerReady {
            for n in 0..<128 {
                sampler?.stopNote(UInt8(n), onChannel: 0)
            }
        }

        // 回退 PCM 路径：停并释放（每次播放前重建）
        fallbackPlayerNode?.stop()
        fallbackPlayerNode = nil
        fallbackEngine?.stop()
        fallbackEngine = nil

        isPlaying = false
        playingIndex = 0
    }

    private func startNote(midi: Int) {
        if samplerReady {
            sampler?.startNote(UInt8(max(0, min(127, midi))), withVelocity: 100, onChannel: 0)
        }
    }

    private func stopNote(midi: Int) {
        if samplerReady {
            sampler?.stopNote(UInt8(max(0, min(127, midi))), onChannel: 0)
        }
    }

    // MARK: - 波形回退播放（采样器不可用时）

    private func playPCM(samples: [Float]) {
        guard !samples.isEmpty else { return }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let ch = buffer.floatChannelData![0]
        for i in 0..<samples.count { ch[i] = samples[i] }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        self.fallbackEngine = engine
        self.fallbackPlayerNode = player
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
            Task { @MainActor in self?.isPlaying = false }
        })
        engine.prepare()
        try? engine.start()
        player.play()
        isPlaying = true
    }
}