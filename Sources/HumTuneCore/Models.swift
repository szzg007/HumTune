// 核心数据模型：从"哼唱的音频采样"到"音符序列"
import Foundation
import AVFoundation

/// 一个音符（量化后）
public struct Note: Equatable, Codable {
    /// 起始时间（秒）
    public var time: Double
    /// 时值（秒）
    public var duration: Double
    /// 原始基频（Hz），可能非整数音高
    public var pitchHz: Double
    /// 量化后的 MIDI 音符号（0-127），如 60 = 中央 C4
    public var midiNote: UInt8

    public init(time: Double, duration: Double, pitchHz: Double, midiNote: UInt8) {
        self.time = time
        self.duration = duration
        self.pitchHz = pitchHz
        self.midiNote = midiNote
    }

    /// 音名 + 八度，如 "C4"、"D#4"
    public var name: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(midiNote) / 12 - 1
        let pitchClass = Int(midiNote) % 12
        return "\(names[pitchClass])\(octave)"
    }
}

/// 一段旋律（哼唱识别结果）
public struct Melody: Codable {
    public var notes: [Note]
    /// 估算 BPM
    public var bpm: Double
    /// 拍号（分子, 分母）
    public var timeSignature: (Int, Int)

    public init(notes: [Note], bpm: Double, timeSignature: (Int, Int) = (4, 4)) {
        self.notes = notes
        self.bpm = bpm
        self.timeSignature = timeSignature
    }

    public enum CodingKeys: String, CodingKey {
        case notes, bpm, timeSignature
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notes = try c.decode([Note].self, forKey: .notes)
        bpm = try c.decode(Double.self, forKey: .bpm)
        let ts = try c.decode([Int].self, forKey: .timeSignature)
        timeSignature = (ts.count >= 2 ? ts[0] : 4, ts.count >= 2 ? ts[1] : 4)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(notes, forKey: .notes)
        try c.encode(bpm, forKey: .bpm)
        try c.encode([timeSignature.0, timeSignature.1], forKey: .timeSignature)
    }
}

/// 音高分析的一帧结果（原始 f0 轨迹的一帧）
public struct PitchFrame: Equatable {
    /// 帧起始时间（秒）
    public var time: Double
    /// 基频（Hz），无音/静音时为 0
    public var frequency: Double
    /// 置信度 0-1（YIN 的 CMND 值反推）
    public var confidence: Double
    /// 帧能量（RMS，0-1 归一化）——用于语音活动检测 VAD
    public var energy: Double

    public init(time: Double, frequency: Double, confidence: Double, energy: Double = 0) {
        self.time = time
        self.frequency = frequency
        self.confidence = confidence
        self.energy = energy
    }
}

/// 音高 → MIDI note 的换算工具
public enum PitchConverter {
    /// 频率 → 最近 MIDI note
    public static func midiNote(fromHz hz: Double) -> UInt8 {
        guard hz > 0 else { return 0 }
        let n = round(69 + 12 * log2(hz / 440.0))
        return UInt8(max(0, min(127, n)))
    }

    /// MIDI note → 频率
    public static func hz(fromMidi note: UInt8) -> Double {
        return 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }

    /// 频率 → 最近半音的频率（量化到十二平均律）
    public static func snappedHz(_ hz: Double) -> Double {
        let m = midiNote(fromHz: hz)
        return Self.hz(fromMidi: m)
    }

    /// 对音符序列整体移调（±半音）
    public static func transpose(_ notes: [Note], semitones: Int) -> [Note] {
        notes.map { n in
            var m = n
            let new = Int(n.midiNote) + semitones
            m.midiNote = UInt8(max(0, min(127, new)))
            m.pitchHz = hz(fromMidi: m.midiNote)
            return m
        }
    }
}