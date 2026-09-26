// 音符切分：把逐帧音高轨迹切成离散音符（起音检测 + 稳定段取均值）
// 目标：保节奏——还原每个音的长短与停顿
import Foundation

/// 起音检测器：基于频谱通量（spectral flux）的简化版
/// 对哼歌场景，用"音高轨迹突变 + 能量上升"判断新音开始
public struct OnsetDetector {
    /// 起音判定阈值（相邻帧音高跳变，单位：半音）
    public let pitchJumpSemitones: Double
    /// 静音 → 有音 的能量阈值
    public let silenceConfidence: Double

    public init(pitchJumpSemitones: Double = 1.5, silenceConfidence: Double = 0.25) {
        self.pitchJumpSemitones = pitchJumpSemitones
        self.silenceConfidence = silenceConfidence
    }
}

/// 音符切分器：输入 PitchFrame 序列，输出 Note 序列
public struct NoteSegmenter {
    /// 最小音符时长（秒），低于此的短音当作噪声
    public let minNoteDuration: Double
    /// 音符间视为停顿的最小间隔（秒）
    public let minGapDuration: Double

    public init(minNoteDuration: Double = 0.08, minGapDuration: Double = 0.05) {
        self.minNoteDuration = minNoteDuration
        self.minGapDuration = minGapDuration
    }

    /// 切分音高轨迹为音符
    /// 算法：组合 VAD（置信度为主 + 能量为辅）判断有无音；
    ///       相邻帧 f0 跳变超阈值 → 新音起音（核心切分机制）
    public func segment(frames: [PitchFrame]) -> [Note] {
        guard !frames.isEmpty else { return [] }

        // 自适应静音阈值：取能量 10% 分位作为底噪，阈值为其 2.5 倍
        let energies = frames.map { $0.energy }.sorted()
        let noiseFloor = energies[energies.count / 10]
        let energyThreshold = noiseFloor * 2.5
        // 置信度阈值：哼歌 YIN 置信度普遍偏低，放宽到 0.12
        let confThreshold = 0.12

        var notes: [Note] = []
        var segStartTime: Double? = nil
        var segFreqs: [Double] = []
        var lastFreq: Double = 0
        var lastTime = frames[0].time

        for frame in frames {
            // 组合判定：f0>0 且（置信度够 或 能量够）
            // 连续正弦波：conf≈1 → 有音；真哼歌：conf低但 energy 高 → 有音；纯静音：两者都低 → 无音
            let voiced = frame.frequency > 0
                && (frame.confidence > confThreshold || frame.energy > energyThreshold)

            if voiced {
                if segStartTime == nil {
                    segStartTime = frame.time
                    segFreqs = [frame.frequency]
                } else {
                    let jump = abs(semitoneDiff(frame.frequency, lastFreq))
                    if jump > 1.5 && lastFreq > 0 {
                        let note = finishNote(start: segStartTime!,
                                              end: lastTime,
                                              freqs: segFreqs)
                        if note != nil { notes.append(note!) }
                        segStartTime = frame.time
                        segFreqs = [frame.frequency]
                    } else {
                        segFreqs.append(frame.frequency)
                    }
                }
                lastFreq = frame.frequency
            } else {
                // 无音帧：若有正在累积的音，结束它
                if segStartTime != nil {
                    let gap = frame.time - lastTime
                    if gap >= minGapDuration && lastFreq > 0 {
                        let note = finishNote(start: segStartTime!,
                                              end: lastTime,
                                              freqs: segFreqs)
                        if note != nil { notes.append(note!) }
                        segStartTime = nil
                        segFreqs = []
                        lastFreq = 0
                    }
                }
            }
            lastTime = frame.time
        }

        // 收尾：最后一个未结束的音
        if let start = segStartTime, lastFreq > 0 {
            let note = finishNote(start: start, end: lastTime, freqs: segFreqs)
            if note != nil { notes.append(note!) }
        }

        return notes
    }

    /// 用一段频率序列生成单个音符：取中位数作音高
    private func finishNote(start: Double, end: Double, freqs: [Double]) -> Note? {
        let duration = end - start
        guard duration >= minNoteDuration, !freqs.isEmpty else { return nil }

        // 中位数抗离群（比均值稳）
        let sorted = freqs.sorted()
        let median = sorted[sorted.count / 2]
        // 去掉明显偏离的音高帧（颤音），求稳定性
        var stable: [Double] = []
        for f in freqs {
            if abs(semitoneDiff(f, median)) < 0.6 {
                stable.append(f)
            }
        }
        let pitch = stable.isEmpty ? median : (stable.reduce(0, +) / Double(stable.count))

        let midi = PitchConverter.midiNote(fromHz: pitch)
        return Note(time: start, duration: duration, pitchHz: pitch, midiNote: midi)
    }

    /// 两频率的半音差
    private func semitoneDiff(_ f1: Double, _ f2: Double) -> Double {
        guard f1 > 0, f2 > 0 else { return 0 }
        return 12 * log2(f1 / f2)
    }
}

/// BPM 估算：用音符起始间隔的分布估算
public enum BPMEstimator {
    /// 估算 BPM（用相邻音符 onset 间隔的中位数 → 假设为四分音符/八分音符）
    public static func estimate(notes: [Note]) -> Double {
        guard notes.count >= 2 else { return 120 }
        var intervals: [Double] = []
        for i in 1..<notes.count {
            let dt = notes[i].time - notes[i - 1].time
            if dt > 0.05 && dt < 2.0 {
                intervals.append(dt)
            }
        }
        guard let median = median(intervals), median > 0 else { return 120 }

        // 假设中位间隔对应八分音符或四分音符，取最接近 60-180 BPM 的
        var candidates: [Double] = []
        for subdiv in [1.0, 2.0, 0.5, 3.0] {
            let bpm = 60.0 / (median * subdiv)
            candidates.append(bpm)
        }
        return candidates.min(by: { abs($0 - 120) < abs($1 - 120) }) ?? 120
    }

    private static func median(_ arr: [Double]) -> Double? {
        guard !arr.isEmpty else { return nil }
        let s = arr.sorted()
        let mid = s.count / 2
        if s.count % 2 == 0 {
            return (s[mid - 1] + s[mid]) / 2
        } else {
            return s[mid]
        }
    }
}

/// 音符量化：把秒为单位的时值/位置量化到节拍网格（16 分音符精度）
public struct Quantizer {
    /// 按时值比例量化到最小网格长度（保持相对节奏比例）
    public static func quantize(notes: [Note], bpm: Double, subdivision: Int = 16) -> [Note] {
        guard !notes.isEmpty else { return [] }
        let beatDuration = 60.0 / bpm
        let grid = beatDuration / Double(subdivision)

        var result: [Note] = []
        for n in notes {
            let start = (n.time / grid).rounded() * grid
            var dur = (n.duration / grid).rounded() * grid
            if dur < grid { dur = grid }
            var m = n
            m.time = start
            m.duration = dur
            result.append(m)
        }
        return result
    }
}