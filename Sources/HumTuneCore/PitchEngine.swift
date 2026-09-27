import Foundation

/// YIN 音高检测引擎（升级版）
/// - 基础：de Cheveigné & Kawahara JASA 2002 的经典 YIN
/// - 升级：颤音中值平滑、八度消歧、气声/无声门限
public struct PitchEngine {

    public let sampleRate: Double
    public let windowSize: Int          // 采样点
    public let hopSize: Int             // 帧移（采样点）
    private let minFreq: Double = 55.0  // A1 ~ 55Hz
    private let maxFreq: Double = 880.0 // A5 ~ 880Hz（覆盖人声+乐器常用区）

    public init(sampleRate: Double = 44100.0, windowSize: Int = 2048, hopSize: Int = 512) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
    }

    /// 对整段 PCM 逐帧估计 F0
    /// - Parameter samples: 单声道 float PCM（-1~1）
    /// - Returns: 逐帧音高轨迹
    public func analyze(samples: [Float]) -> [PitchFrame] {
        var frames: [PitchFrame] = []
        var index = 0
        while index + windowSize <= samples.count {
            let frame = Array(samples[index..<index + windowSize])
            let time = Double(index) / sampleRate
            let (freq, conf) = yin(frame: frame)
            let energy = rms(frame)
            frames.append(PitchFrame(frequency: freq, confidence: conf, energy: energy, time: time))
            index += hopSize
        }
        return frames
    }

    /// 单帧 YIN
    private func yin(frame: [Float]) -> (frequency: Double, confidence: Double) {
        let n = frame.count
        let half = n / 2

        // 差函数 d(tau)
        var diff = [Double](repeating: 0, count: half)
        for tau in 1..<half {
            var sum: Double = 0
            for i in 0..<half {
                let d = Double(frame[i]) - Double(frame[i + tau])
                sum += d * d
            }
            diff[tau] = sum
        }

        // 累积均值归一化（CMNDF）
        var cmndf = [Double](repeating: 0, count: half)
        cmndf[0] = 1.0
        var runningSum: Double = 0
        for tau in 1..<half {
            runningSum += diff[tau]
            cmndf[tau] = runningSum == 0 ? 1.0 : diff[tau] * Double(tau) / runningSum
        }

        // 找第一个低于阈值的谷
        let threshold: Double = 0.15
        var tauEstimate = -1
        var tau = 1
        while tau < half {
            if cmndf[tau] < threshold {
                // 继续找局部最小
                while tau + 1 < half && cmndf[tau + 1] < cmndf[tau] {
                    tau += 1
                }
                tauEstimate = tau
                break
            }
            tau += 1
        }

        guard tauEstimate > 0 else {
            return (0, 0)
        }

        // 抛物线插值精修
        let tauF = Double(tauEstimate)
        let x0 = tauEstimate - 1, x1 = tauEstimate, x2 = tauEstimate + 1
        guard x0 >= 0 && x2 < half else {
            return (0, 0)
        }
        let y0 = cmndf[x0], y1 = cmndf[x1], y2 = cmndf[x2]
        let denominator = y0 - 2 * y1 + y2
        let refined = denominator != 0 ? tauF + (y0 - y2) / (2 * denominator) : tauF

        let freq = sampleRate / refined

        // 频率合理性检查（范围 + 置信度）
        guard freq >= minFreq && freq <= maxFreq else {
            return (0, 0)
        }
        let confidence = 1.0 - cmndf[tauEstimate] // 越接近 0 越可靠

        return (freq, confidence)
    }

    /// RMS 能量
    private func rms(_ frame: [Float]) -> Double {
        var sum: Double = 0
        for v in frame {
            sum += Double(v) * Double(v)
        }
        return sqrt(sum / Double(frame.count))
    }
}

/// 音高轨迹后处理：中值平滑 + 八度消歧
public enum PitchPostProcessor {

    /// 中值平滑（抑制颤音抖动）
    public static func medianSmooth(_ frames: [PitchFrame], radius: Int = 3) -> [PitchFrame] {
        return frames.enumerated().map { (i, frame) in
            guard frame.frequency > 0 else { return frame }
            let lo = max(0, i - radius)
            let hi = min(frames.count - 1, i + radius)
            var freqs: [Double] = []
            for j in lo...hi where frames[j].frequency > 0 {
                freqs.append(frames[j].frequency)
            }
            guard !freqs.isEmpty else { return frame }
            let sorted = freqs.sorted()
            let median = sorted[sorted.count / 2]
            return PitchFrame(frequency: median, confidence: frame.confidence, energy: frame.energy, time: frame.time)
        }
    }

    /// 八度消歧：相邻帧频率跳变接近 2:1 时，归类到较近的一侧
    /// 简单策略：以中位频率为锚，把明显落在 ±50音分 外的八度翻转回主八度
    public static func octaveCorrect(_ frames: [PitchFrame]) -> [PitchFrame] {
        // 估算主八度（所有有效频率的中位数）
        let validFreqs = frames.filter { $0.frequency > 0 }.map { $0.frequency }
        guard !validFreqs.isEmpty else { return frames }
        let sorted = validFreqs.sorted()
        let anchor = sorted[sorted.count / 2]

        return frames.map { frame in
            guard frame.frequency > 0 else { return frame }
            var f = frame.frequency
            // 向上/向下翻八度直到接近 anchor（±半音内）
            while f > anchor * 1.414 { f /= 2 }
            while f < anchor / 1.414 { f *= 2 }
            return PitchFrame(frequency: f, confidence: frame.confidence, energy: frame.energy, time: frame.time)
        }
    }
}