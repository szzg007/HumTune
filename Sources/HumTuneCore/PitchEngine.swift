// 音高提取引擎：YIN 算法（基于 CMND 差分函数）
// 目标：从一帧 PCM 采样中估计基频 f0，抗人声谐波（倍频误判）
import Foundation

public struct YINPitchEngine {
    /// 采样率
    public let sampleRate: Double
    /// 基频搜索下限（Hz），哼歌通常不低于 60
    public let minFrequency: Double
    /// 基频搜索上限（Hz），哼歌通常不高于 1000
    public let maxFrequency: Double
    /// YIN 阈值，越小越严格（典型 0.1-0.2）
    public let threshold: Double

    public init(sampleRate: Double = 44100,
                minFrequency: Double = 60,
                maxFrequency: Double = 1000,
                threshold: Double = 0.15) {
        self.sampleRate = sampleRate
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.threshold = threshold
    }

    /// 对一帧采样估计基频与置信度
    /// - Parameter samples: 单帧时域采样（建议帧长 2048，接近 46ms @44.1k）
    /// - Returns: (频率Hz, 置信度0-1)，无音返回 (0, 0)
    public func estimate(samples: [Double]) -> (frequency: Double, confidence: Double) {
        let n = samples.count
        guard n > 4 else { return (0, 0) }

        let minTau = Int(sampleRate / maxFrequency)   // 高音 → 小 tau
        let maxTau = Int(sampleRate / minFrequency)   // 低音 → 大 tau
        guard maxTau < n / 2 else { return (0, 0) }
        guard minTau < maxTau else { return (0, 0) }

        // 1) 计算 CMND 差分函数 d(tau)（YIN 核心）
        // d(tau) = Σ (x[j] - x[j+tau])^2
        var d = [Double](repeating: 0, count: maxTau + 1)
        for tau in 1...maxTau {
            var sum = 0.0
            // 累加窗口 W = n/2 个样本（YIN 典型窗口）
            let w = min(n / 2, n - tau)
            for j in 0..<w {
                let diff = samples[j] - samples[j + tau]
                sum += diff * diff
            }
            d[tau] = sum
        }

        // 2) 累积均值归一化 CMND
        var cmnd = [Double](repeating: 0, count: maxTau + 1)
        cmnd[0] = 1.0
        var runningSum = 0.0
        for tau in 1...maxTau {
            runningSum += d[tau]
            cmnd[tau] = runningSum == 0 ? 0 : (d[tau] * Double(tau) / runningSum)
        }

        // 3) 绝对阈值法找第一个 cmnd < threshold 的 tau
        var tauEstimate = -1
        var tau = minTau
        while tau <= maxTau {
            if cmnd[tau] < threshold {
                // 回调检查：确保不是局部极小值误判
                while tau + 1 <= maxTau && cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                tauEstimate = tau
                break
            }
            tau += 1
        }

        // 若未找到，退化为全局最小 cmnd 位置（对无声段会得到无意义值，但置信度低）
        if tauEstimate < 0 {
            var bestTau = minTau
            var bestVal = Double.greatestFiniteMagnitude
            for i in minTau...maxTau {
                if cmnd[i] < bestVal {
                    bestVal = cmnd[i]
                    bestTau = i
                }
            }
            tauEstimate = bestTau
        }

        // 4) 抛物线插值，亚采样精度
        let refinedTau = parabolicInterpolation(cmnd, tau: tauEstimate)
        let freq = sampleRate / refinedTau

        // 频率需落在合理区间内
        guard freq >= minFrequency * 0.8, freq <= maxFrequency * 1.2 else {
            return (0, 0)
        }

        // 置信度：cmnd 值越小越可信，映射到 0-1
        let c = cmnd[tauEstimate]
        let confidence = max(0.0, min(1.0, 1.0 - c))

        return (freq, confidence)
    }

    /// 抛物线插值细化 tau
    private func parabolicInterpolation(_ cmnd: [Double], tau: Int) -> Double {
        guard tau > 0, tau + 1 < cmnd.count else { return Double(tau) }
        let x0 = Double(tau - 1), x1 = Double(tau), x2 = Double(tau + 1)
        let y0 = cmnd[tau - 1], y1 = cmnd[tau], y2 = cmnd[tau + 1]
        let denom = (x0 - x1) * (x0 - x2) * (x1 - x2)
        guard denom != 0 else { return Double(tau) }
        let a = (x2 * (y1 - y0) + x1 * (y0 - y2) + x0 * (y2 - y1)) / denom
        let b = (x0 * x0 * (y1 - y2) + x1 * x1 * (y2 - y0) + x2 * x2 * (y0 - y1)) / denom
        _ = (x0 * x1 * (x0 - x1) * y2 + x1 * x2 * (x1 - x2) * y0 + x2 * x0 * (x2 - x0) * y1) / denom
        guard abs(a) > 1e-12 else { return Double(tau) }
        return -b / (2 * a)
    }
}

/// 帧切分器：把音频采样切成固定帧（可重叠）
public struct FrameSplitter {
    public let frameLength: Int
    public let hopLength: Int
    public let sampleRate: Double

    public init(frameLength: Int = 2048, hopLength: Int = 1024, sampleRate: Double = 44100) {
        self.frameLength = frameLength
        self.hopLength = hopLength
        self.sampleRate = sampleRate
    }

    /// 把采样序列切成帧，返回每帧的起始采样索引
    public func frames(in sampleCount: Int) -> [Int] {
        guard sampleCount >= frameLength else { return [] }
        var indices: [Int] = []
        var start = 0
        while start + frameLength <= sampleCount {
            indices.append(start)
            start += hopLength
        }
        return indices
    }

    /// 帧起始采样索引 → 时间（秒）
    public func time(forFrameIndex index: Int) -> Double {
        return Double(index) / sampleRate
    }
}

/// 音高轨迹：对整段哼唱做逐帧 f0 提取
public struct PitchTracker {
    public let engine: YINPitchEngine
    public let splitter: FrameSplitter

    public init(engine: YINPitchEngine = YINPitchEngine(),
                splitter: FrameSplitter = FrameSplitter()) {
        self.engine = engine
        self.splitter = splitter
    }

    /// 输入归一化到 [-1,1] 的采样，输出逐帧音高
    public func track(samples: [Double]) -> [PitchFrame] {
        var frames: [PitchFrame] = []
        let indices = splitter.frames(in: samples.count)
        for idx in indices {
            let frameSamples = Array(samples[idx..<(idx + splitter.frameLength)])
            let (freq, conf) = engine.estimate(samples: frameSamples)
            let t = splitter.time(forFrameIndex: idx)
            // 计算 RMS 能量（VAD 用）
            var sum = 0.0
            for s in frameSamples { sum += s * s }
            let rms = sqrt(sum / Double(frameSamples.count))
            frames.append(PitchFrame(time: t, frequency: freq, confidence: conf, energy: rms))
        }
        return frames
    }
}