import Foundation

/// 调性识别 + 音名拼写引擎（新增模块）
/// 用 Krumhansl-Schmuckler 调性识别（24 调模板 Pearson 相关）
public struct KeyEstimator {

    /// Krumhansl-Kessler 大调 profile（音级 0~11 = C C# D ... B）
    private static let majorProfile: [Double] = [
        6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
        2.52, 5.19, 2.39, 3.66, 2.29, 2.88
    ]
    /// 小调 profile
    private static let minorProfile: [Double] = [
        6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
        2.54, 4.75, 3.98, 2.69, 3.34, 3.17
    ]

    public init() {}

    /// 估计调性
    /// - Parameter notes: 音符（用 pitch class 计数，时长加权）
    /// - Returns: KeySignature
    public func estimateKey(_ notes: [Note]) -> KeySignature? {
        guard !notes.isEmpty else { return nil }

        // 音级分布（PCP），按时长加权
        var pcp = [Double](repeating: 0, count: 12)
        var totalDuration: Double = 0
        for note in notes {
            let pc = note.midi % 12
            pcp[pc] += note.duration
            totalDuration += note.duration
        }
        guard totalDuration > 0 else { return nil }
        for i in 0..<12 { pcp[i] /= totalDuration }

        // 对 24 个调算 Pearson 相关
        var bestKey: KeySignature? = nil
        var bestCorr = -Double.greatestFiniteMagnitude

        for tonic in 0..<12 {
            // 大调
            let majorCorr = pearson(x: pcp, y: Self.majorProfile, shift: tonic)
            if majorCorr > bestCorr {
                bestCorr = majorCorr
                bestKey = KeySignature(fifths: Self.fifthsForTonic(tonic, isMajor: true), tonicMidi: tonic + 60, isMajor: true)
            }
            // 小调
            let minorCorr = pearson(x: pcp, y: Self.minorProfile, shift: tonic)
            if minorCorr > bestCorr {
                bestCorr = minorCorr
                bestKey = KeySignature(fifths: Self.fifthsForTonic(tonic, isMajor: false), tonicMidi: tonic + 60, isMajor: false)
            }
        }

        return bestKey
    }

    /// 计算 PCC（把 profile 按主音 shift）
    private func pearson(x: [Double], y: [Double], shift: Int) -> Double {
        var shifted = [Double](repeating: 0, count: 12)
        for i in 0..<12 {
            shifted[(i + shift) % 12] = y[i]
        }
        return Self.correlation(x, shifted)
    }

    private static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        let n = a.count
        let meanA = a.reduce(0, +) / Double(n)
        let meanB = b.reduce(0, +) / Double(n)
        var num: Double = 0, denA: Double = 0, denB: Double = 0
        for i in 0..<n {
            let da = a[i] - meanA
            let db = b[i] - meanB
            num += da * db
            denA += da * da
            denB += db * db
        }
        let den = sqrt(denA * denB)
        return den == 0 ? 0 : num / den
    }

    /// 由主音+大小调推导五度圈位置（fifths）
    /// 升号方向：C=0 G=1 D=2 A=3 E=4 B=5 F#=6 C#=7
    /// 降号方向（用负表示）：F=-1 Bb=-2 Eb=-3 Ab=-4 Db=-5 Gb=-6 Cb=-7
    private static func fifthsForTonic(_ tonic: Int, isMajor: Bool) -> Int {
        // 大调五度圈位置（C=0）
        let majorFifths: [Int: Int] = [
            0: 0,   // C
            7: 1,   // G
            2: 2,   // D
            9: 3,   // A
            4: 4,   // E
            11: 5,  // B
            6: 6,   // F#
            1: 7,   // C#
            5: -1,  // F → 实际由 -7 补全，这里用降号等价
            10: -2, // Bb
            3: -3,  // Eb
            8: -4   // Ab
        ]
        // 降号调（Db Gb Cb 等用 >7 或等价，这里简化处理）
        let base = majorFifths[tonic] ?? 0

        if isMajor {
            return normalizeFifths(base)
        } else {
            // 小调主音 = 关系大调主音 - 3 个半音（下小三度）
            let relMajor = (tonic + 3) % 12
            return normalizeFifths(majorFifths[relMajor] ?? 0)
        }
    }

    private static func normalizeFifths(_ f: Int) -> Int {
        // 把 >7 的升号等价转为降号，<-7 转为升号（理论上不会超）
        if f > 7 { return f - 12 }
        if f < -7 { return f + 12 }
        return f
    }
}

/// 音名拼写：根据调性把 MIDI 音高转成记谱音名（step + alter）
public struct NoteSpeller {

    /// 升号调主音到五线谱音高的映射
    private static let sharpLetters = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    private static let flatLetters  = ["C", "D", "D", "E", "E", "F", "G", "G", "A", "A", "B", "B"]

    public init() {}

    public struct Spelling {
        public let step: String    // C D E F G A B
        public let alter: Int      // -1 降 +1 升 0 还原
        public let octave: Int
    }

    /// 给定调性，拼写一个 MIDI 音
    public func spell(midi: Int, key: KeySignature?) -> Spelling {
        let pc = midi % 12
        let octave = midi / 12 - 1

        guard let key = key else {
            // 无调性：默认升降号约定（升号记法）
            return Spelling(step: Self.sharpLetters[pc], alter: Self.sharpAlter(pc), octave: octave)
        }

        // 有调性：降号调用降号记法，升号/还原调 用升号记法
        if key.fifths < 0 {
            return Spelling(step: Self.flatLetters[pc], alter: Self.flatAlter(pc), octave: octave)
        } else {
            return Spelling(step: Self.sharpLetters[pc], alter: Self.sharpAlter(pc), octave: octave)
        }
    }

    /// 升号记法下每个 pitch class 的 alter
    static func sharpAlter(_ pc: Int) -> Int {
        switch pc {
        case 1, 3, 6, 8, 10: return 1   // C# D# F# G# A#
        default: return 0
        }
    }

    /// 降号记法下每个 pitch class 的 alter
    static func flatAlter(_ pc: Int) -> Int {
        switch pc {
        case 1, 3, 6, 8, 10: return -1  // Db Eb Gb Ab Bb
        default: return 0
        }
    }
}