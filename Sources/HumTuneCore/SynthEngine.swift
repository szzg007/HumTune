// GM 音色合成引擎：加载 gs_instruments.dls / sf2，切换 128 种音色，发声
import Foundation
import AVFoundation

/// GM 128 音色名称（Standard General MIDI Level 1）
public enum GMInstruments {
    public static let names: [String] = [
        // 0-7 钢琴类
        "Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano",
        "Honky-tonk Piano", "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet",
        // 8-15 半音打击乐
        "Celesta", "Glockenspiel", "Music Box", "Vibraphone", "Marimba", "Xylophone",
        "Tubular Bells", "Dulcimer",
        // 16-23 风琴
        "Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ", "Reed Organ",
        "Accordion", "Harmonica", "Tango Accordion",
        // 24-31 吉他
        "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)", "Electric Guitar (jazz)",
        "Electric Guitar (clean)", "Electric Guitar (muted)", "Overdriven Guitar",
        "Distortion Guitar", "Guitar Harmonics",
        // 32-39 低音
        "Acoustic Bass", "Electric Bass (finger)", "Electric Bass (pick)", "Fretless Bass",
        "Slap Bass 1", "Slap Bass 2", "Synth Bass 1", "Synth Bass 2",
        // 40-47 弦乐
        "Violin", "Viola", "Cello", "Contrabass", "Tremolo Strings", "Pizzicato Strings",
        "Orchestral Harp", "Timpani",
        // 48-55 合奏
        "String Ensemble 1", "String Ensemble 2", "Synth Strings 1", "Synth Strings 2",
        "Choir Aahs", "Voice Oohs", "Synth Voice", "Orchestra Hit",
        // 56-63 铜管
        "Trumpet", "Trombone", "Tuba", "Muted Trumpet", "French Horn", "Brass Section",
        "Synth Brass 1", "Synth Brass 2",
        // 64-71 簧片
        "Soprano Sax", "Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe", "English Horn",
        "Bassoon", "Clarinet",
        // 72-79 管乐
        "Piccolo", "Flute", "Recorder", "Pan Flute", "Blown Bottle", "Shakuhachi",
        "Whistle", "Ocarina",
        // 80-87 合成主音
        "Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)",
        "Lead 5 (charang)", "Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)",
        // 88-95 合成铺垫
        "Pad 1 (new age)", "Pad 2 (warm)", "Pad 3 (polysynth)", "Pad 4 (choir)",
        "Pad 5 (bowed)", "Pad 6 (metallic)", "Pad 7 (halo)", "Pad 8 (sweep)",
        // 96-103 合成效果
        "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)", "FX 4 (atmosphere)",
        "FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)", "FX 8 (sci-fi)",
        // 104-111 民族乐器
        "Sitar", "Banjo", "Shamisen", "Koto", "Kalimba", "Bag pipe", "Fiddle", "Shanai",
        // 112-119 打击乐
        "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock", "Taiko Drum", "Melodic Tom",
        "Synth Drum", "Reverse Cymbal",
        // 120-127 音效
        "Guitar Fret Noise", "Breath Noise", "Seashore", "Bird Tweet", "Telephone Ring",
        "Helicopter", "Applause", "Gunshot",
    ]

    /// 常用乐器快捷表（小白友好）
    public static let favorites: [(name: String, program: UInt8)] = [
        ("钢琴 Piano", 0), ("电钢琴 Electric Piano", 4), ("风琴 Organ", 19),
        ("木吉他 Acoustic Guitar", 24), ("电吉他 Electric Guitar", 29),
        ("小提琴 Violin", 40), ("大提琴 Cello", 42), ("弦乐合奏 Strings", 48),
        ("小号 Trumpet", 56), ("萨克斯 Sax", 65), ("长笛 Flute", 73),
        ("口琴 Harmonica", 22), ("古筝 Koto", 107), ("钢片琴 Music Box", 10),
        ("贝斯 Bass", 33), ("合唱 Choir", 52),
    ]
}

/// GM 音色合成器：封装 AVAudioEngine + AVAudioUnitSampler
/// 加载系统 gs_instruments.dls 或外部 sf2，支持切换音色、单音发声、按旋律播放
public final class SynthEngine {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    public var isLoaded = false
    public private(set) var currentProgram: UInt8 = 0
    public private(set) var soundFontPath: String?

    /// 系统 GM 音色库默认路径
    public static let systemDLS = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"

    public init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
    }

    /// 用 sampler 载入音色库（gs_instruments.dls / .sf2 均适用）
    public func loadSoundFont(path: String) throws {
        let url = URL(fileURLWithPath: path)
        // 先启动引擎，否则加载可能失败
        try start()
        try sampler.loadInstrument(at: url)
        isLoaded = true
        soundFontPath = path
    }

    /// 加载系统默认 GM 音色库
    public func loadSystemGM() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: SynthEngine.systemDLS) else {
            throw NSError(domain: "SynthEngine", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "系统 GM 音色库不存在: \(SynthEngine.systemDLS)"])
        }
        try loadSoundFont(path: SynthEngine.systemDLS)
    }

    /// 启动音频引擎
    public func start() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    /// 停止引擎
    public func stop() {
        if engine.isRunning {
            engine.stop()
        }
    }

    /// 切换音色（GM program 0-127）
    public func setProgram(_ program: UInt8) {
        let p = min(program, 127)
        currentProgram = p
        sampler.sendProgramChange(p, onChannel: 0)
    }

    /// 按名称切换音色（模糊匹配）
    public func setProgram(named name: String) {
        if let idx = GMInstruments.names.firstIndex(where: { $0.lowercased().contains(name.lowercased()) }) {
            setProgram(UInt8(idx))
        }
    }

    /// 发声（note on）
    public func noteOn(_ midiNote: UInt8, velocity: UInt8 = 100) {
        sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
    }

    /// 止音（note off）
    public func noteOff(_ midiNote: UInt8) {
        sampler.stopNote(midiNote, onChannel: 0)
    }

    /// 播放单个音：on 后按 duration 自动 off
    public func playNote(_ midiNote: UInt8, duration: Double, velocity: UInt8 = 100) {
        noteOn(midiNote, velocity: velocity)
        DispatchQueue.global().asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.noteOff(midiNote)
        }
    }

    /// 按旋律顺序播放音符（试听）
    public func playMelody(_ notes: [Note]) {
        guard !notes.isEmpty else { return }
        let base = notes[0].time
        for n in notes.sorted(by: { $0.time < $1.time }) {
            let delay = max(0, n.time - base)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.noteOn(n.midiNote, velocity: 100)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay + n.duration) { [weak self] in
                self?.noteOff(n.midiNote)
            }
        }
    }
}