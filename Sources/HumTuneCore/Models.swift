import Foundation

/// 单个音频帧的音高分析结果
public struct PitchFrame {
    /// 基频（Hz），0 表示无声/无音高
    public let frequency: Double
    /// YIN 置信度（0~1，越高越可靠）
    public let confidence: Double
    /// 该帧能量 RMS
    public let energy: Double
    /// 时间戳（秒）
    public let time: Double

    public init(frequency: Double, confidence: Double, energy: Double, time: Double) {
        self.frequency = frequency
        self.confidence = confidence
        self.energy = energy
        self.time = time
    }
}

/// 一个已切分、已量化的音符（最终真值）
public struct Note: Equatable {
    /// MIDI 音号（60 = C4，A4 = 69）
    public let midi: Int
    /// 起始时间（秒）
    public let startTime: Double
    /// 持续时长（秒）
    public let duration: Double
    /// 所属声部（暂用 0）
    public let voice: Int

    public init(midi: Int, startTime: Double, duration: Double, voice: Int = 0) {
        self.midi = midi
        self.startTime = startTime
        self.duration = duration
        self.voice = voice
    }

    /// 音名（不含升降号：C D E F G A B）
    public var pitchClassLetter: String {
        let letters = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
        return letters[midi % 12]
    }

    /// 八度（C4 为 4）
    public var octave: Int {
        return midi / 12 - 1
    }
}

/// 调性信息
public struct KeySignature {
    /// 升号为正（G大调=+1，D大调=+2...），降号为负（F大调=-1，Bb大调=-2...），C大调=0
    public let fifths: Int
    /// 主音 MIDI（如 C 大调 = 60）
    public let tonicMidi: Int
    /// 是否大调
    public let isMajor: Bool

    public init(fifths: Int, tonicMidi: Int, isMajor: Bool) {
        self.fifths = fifths
        self.tonicMidi = tonicMidi
        self.isMajor = isMajor
    }
}

/// 拍号信息
public struct TimeSignature {
    public let numerator: Int   // 每小节拍数
    public let denominator: Int // 拍单位（4 = 四分音符）

    public init(numerator: Int = 4, denominator: Int = 4) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

/// 转录结果（端到端输出）
public struct TranscriptionResult {
    public var notes: [Note]
    public var key: KeySignature?
    public var timeSignature: TimeSignature
    public var bpm: Double

    public init(notes: [Note], key: KeySignature? = nil, timeSignature: TimeSignature = TimeSignature(), bpm: Double = 120) {
        self.notes = notes
        self.key = key
        self.timeSignature = timeSignature
        self.bpm = bpm
    }
}