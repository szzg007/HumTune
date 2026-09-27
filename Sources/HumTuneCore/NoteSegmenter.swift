import Foundation

/// 音符切分器（升级版）
/// 关键修复：用"组合 VAD"（置信度 OR 能量）判有无音，
/// 而不是单一置信度阈值——避免真哼歌被判静音导致 0 音符。
public struct NoteSegmenter {

    /// 置信度阈值（低于此但能量足够仍算有音）
    public var confidenceThreshold: Double = 0.12
    /// 能量阈值倍数（相对底噪）
    public var energyMultiplier: Double = 2.5
    /// 底噪能量（无音帧的平均能量，自动估算）
    public var noiseFloor: Double = 0.002
    /// 最短音符时长（秒），干掉滑音/倚音假音符
    public var minNoteDuration: Double = 0.08
    /// 频率→MIDI 号换算
    private let a4Freq: Double = 440.0

    public init() {}

    /// 从音高轨迹切分出音符（未量化，绝对时间）
    public func segment(_ frames: [PitchFrame]) -> [(midi: Int, start: Double, end: Double)] {
        guard !frames.isEmpty else { return [] }

        // 自动估算底噪：取能量最低 20% 帧的平均
        var floor = noiseFloor
        let energies = frames.map { $0.energy }.sorted()
        if energies.count >= 5 {
            let lowCount = max(1, energies.count / 5)
            floor = energies.prefix(lowCount).reduce(0, +) / Double(lowCount)
        }

        var notes: [(midi: Int, start: Double, end: Double)] = []
        var currentMidi: Int? = nil
        var currentStart: Double = 0
        var lastTime: Double = frames.first!.time

        func isVoiced(_ f: PitchFrame) -> Bool {
            return f.frequency > 0 &&
                   (f.confidence > confidenceThreshold || f.energy > energyMultiplier * floor)
        }

        for frame in frames {
            if isVoiced(frame) {
                let midi = freqToMidi(frame.frequency)
                if currentMidi == nil {
                    // 新音符开始
                    currentMidi = midi
                    currentStart = frame.time
                } else if midi != currentMidi {
                    // 音高变化 → 结束上一个，开始新的
                    if let m = currentMidi {
                        notes.append((midi: m, start: currentStart, end: frame.time))
                    }
                    currentMidi = midi
                    currentStart = frame.time
                }
            } else {
                // 无声/静音帧 → 结束当前音符
                if let m = currentMidi {
                    notes.append((midi: m, start: currentStart, end: frame.time))
                    currentMidi = nil
                }
            }
            lastTime = frame.time
        }

        // 收尾：最后一个音符
        if let m = currentMidi {
            notes.append((midi: m, start: currentStart, end: lastTime))
        }

        // 过滤：最短时长 + 合并同音相邻
        return filterAndMerge(notes)
    }

    private func freqToMidi(_ freq: Double) -> Int {
        // MIDI = 69 + 12*log2(f/440)
        let midi = 69 + 12 * (log(freq / a4Freq) / log(2.0))
        return Int(round(midi))
    }

    /// 最短音符过滤 + 同音相邻合并（隔静音 < 30ms 合并）
    private func filterAndMerge(_ notes: [(midi: Int, start: Double, end: Double)]) -> [(midi: Int, start: Double, end: Double)] {
        var result: [(midi: Int, start: Double, end: Double)] = []
        let gapMergeThreshold = 0.03

        for note in notes {
            let duration = note.end - note.start
            guard duration >= minNoteDuration else { continue }

            if let last = result.last, last.midi == note.midi, note.start - last.end < gapMergeThreshold {
                // 合并
                let merged = (midi: last.midi, start: last.start, end: note.end)
                result[result.count - 1] = merged
            } else {
                result.append(note)
            }
        }
        return result
    }
}