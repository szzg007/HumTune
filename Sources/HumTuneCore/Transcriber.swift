import Foundation

/// 转录协调器（端到端流水线入口）
/// 哼唱 PCM → 音高轨迹 → 切分 → 量化 → 调性 → 完整转录结果
public struct Transcriber {

    public var pitchEngine: PitchEngine
    public var segmenter: NoteSegmenter
    public var quantizer: Quantizer
    public var keyEstimator: KeyEstimator

    public init(
        pitchEngine: PitchEngine = PitchEngine(),
        segmenter: NoteSegmenter = NoteSegmenter(),
        quantizer: Quantizer = Quantizer(),
        keyEstimator: KeyEstimator = KeyEstimator()
    ) {
        self.pitchEngine = pitchEngine
        self.segmenter = segmenter
        self.quantizer = quantizer
        self.keyEstimator = keyEstimator
    }

    /// 完整流水线
    /// - Parameter samples: 单声道 float PCM
    /// - Returns: 转录结果
    public func transcribe(samples: [Float], bpm: Double? = nil) -> TranscriptionResult {
        // 1. 音高检测
        var frames = pitchEngine.analyze(samples: samples)

        // 2. 后处理：中值平滑 + 八度消歧
        frames = PitchPostProcessor.medianSmooth(frames)
        frames = PitchPostProcessor.octaveCorrect(frames)

        // 3. 音符切分（绝对时间）
        let segments = segmenter.segment(frames)

        // 4. BPM 估计（或用外部给定）
        let noteStarts = segments.map { $0.start }
        let estimatedBPM = bpm ?? quantizer.estimateBPM(noteStarts: noteStarts)

        // 5. 量化
        let notes = quantizer.quantize(segments, bpm: estimatedBPM)

        // 6. 调性识别
        let key = keyEstimator.estimateKey(notes)

        return TranscriptionResult(notes: notes, key: key, timeSignature: TimeSignature(), bpm: estimatedBPM)
    }
}

/// 简谱（数字谱）格式化（新增）
/// 1234567 记谱，加升降号、高低音点、时值下划线
public struct JianpuFormatter {

    public init() {}

    /// 生成简谱文本
    /// 约定：C=1 D=2 E=3 F=4 G=5 A=6 B=7
    public func format(_ notes: [Note], key: KeySignature?) -> String {
        // 以主音为基准：找到调性主音，映射到 1
        let tonicMidi = key?.tonicMidi ?? 60  // 默认 C=1

        var lines: [String] = []

        for note in notes {
            let scaleDegree = ((note.midi - tonicMidi) % 12 + 12) % 12
            let (base, alter) = Self.jianpuToken(scaleDegree)
            let octaveOffset = ((note.midi - tonicMidi) / 12)

            var token = base
            // 高低音点
            if octaveOffset > 0 {
                token += String(repeating: "'", count: octaveOffset)  // 高音
            } else if octaveOffset < 0 {
                token = String(repeating: ",", count: -octaveOffset) + token  // 低音
            }
            // 升降号
            if alter != 0 {
                token = (alter > 0 ? "#" : "b") + token
            }
            lines.append(token)
        }

        return lines.joined(separator: " ")
    }

    /// 音级→简谱数字 + 升降
    static func jianpuToken(_ scaleDegree: Int) -> (String, Int) {
        switch scaleDegree {
        case 0: return ("1", 0)
        case 1: return ("1", 1)   // #1
        case 2: return ("2", 0)
        case 3: return ("2", 1)   // #2（实际应为 b3 在调性内，简化）
        case 4: return ("3", 0)
        case 5: return ("4", 0)
        case 6: return ("4", 1)   // #4
        case 7: return ("5", 0)
        case 8: return ("5", 1)   // #5
        case 9: return ("6", 0)
        case 10: return ("6", 1)  // #6
        case 11: return ("7", 0)
        default: return ("1", 0)
        }
    }
}