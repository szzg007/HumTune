import Foundation

/// 节奏量化器（新增模块）
/// 组件：BPM 估计 + 时值量化（网格吸附，带可调量化强度）
public struct Quantizer {

    /// 量化强度 0~1：1=完全拉平到网格，0.5=只拉一半距离（保留律动）
    public var quantizationStrength: Double = 0.7
    /// 量化细度：每拍细分数（4=十六分音符）
    public var gridSubdivision: Int = 4

    public init() {}

    /// 从音符 onset 序列估计 BPM（onset 间隔自相关 + 聚类）
    public func estimateBPM(noteStarts: [Double], minBPM: Double = 60, maxBPM: Double = 200) -> Double {
        guard noteStarts.count >= 3 else { return 120 }

        let sorted = noteStarts.sorted()
        var intervals: [Double] = []
        for i in 1..<sorted.count {
            let iv = sorted[i] - sorted[i - 1]
            if iv > 0.05 && iv < 2.0 {  // 过滤噪声与长停顿
                intervals.append(iv)
            }
        }
        guard !intervals.isEmpty else { return 120 }

        // 间隔聚类：取中位数间隔，换算 BPM
        let sortedIv = intervals.sorted()
        let medianInterval = sortedIv[sortedIv.count / 2]

        // 中位间隔可能是一个拍，也可能是半拍或两拍 → 试几种假设取落在范围内的
        let candidates: [Double] = [
            60.0 / medianInterval,      // 1 拍 = median
            60.0 / (medianInterval / 2), // 1 拍 = median/2
            60.0 / (medianInterval * 2)  // 1 拍 = median*2
        ]

        var best = 120.0
        var bestDist = Double.greatestFiniteMagnitude
        for c in candidates where c >= minBPM && c <= maxBPM {
            // 选离 120 最近（默认最自然）
            let dist = abs(c - 120)
            if dist < bestDist {
                bestDist = dist
                best = c
            }
        }
        return max(minBPM, min(maxBPM, best))
    }

    /// 把绝对时间音符量化到拍网格上
    /// - Parameters:
    ///   - notes: 输入 (midi, start, end)
    ///   - bpm: 拍速
    ///   - timeSignature: 拍号（决定每拍时值基准）
    /// - Returns: 量化后的 Note（时间对齐到网格）
    public func quantize(
        _ segments: [(midi: Int, start: Double, end: Double)],
        bpm: Double,
        timeSignature: TimeSignature = TimeSignature()
    ) -> [Note] {
        // 每拍秒数
        let beatDuration = 60.0 / bpm
        // 网格最小单位（每拍 / 细分数）
        let gridUnit = beatDuration / Double(gridSubdivision)

        var result: [Note] = []

        for seg in segments {
            let startGrid = seg.start / gridUnit
            let endGrid = seg.end / gridUnit

            // 吸附到最近网格点，带量化强度
            let startSnap = (round(startGrid) - startGrid) * quantizationStrength
            let endSnap = (round(endGrid) - endGrid) * quantizationStrength

            let qStart = (startGrid + startSnap) * gridUnit
            var qEnd = (endGrid + endSnap) * gridUnit

            // 保证最短一个网格单位
            if qEnd - qStart < gridUnit {
                qEnd = qStart + gridUnit
            }

            result.append(Note(midi: seg.midi, startTime: qStart, duration: qEnd - qStart))
        }

        return result
    }
}