// 标准 MIDI 文件（SMF Format 0）写入器
// 纯 Swift 实现，无需第三方依赖
import Foundation

public enum MIDIWriterError: Error {
    case invalidNote
}

public final class MIDIWriter {
    /// 把音符序列写成标准 MIDI 文件（Format 0，单轨道）
    public static func write(notes: [Note], bpm: Double, timeSignature: (Int, Int) = (4, 4)) throws -> Data {
        var data = Data()

        // MIDI 头块 MThd
        data.append("MThd".data(using: .ascii)!)
        data.append(bigEndian(UInt32(6)))          // 头块长度固定 6
        data.append(bigEndian(UInt16(0)))          // Format 0
        data.append(bigEndian(UInt16(1)))          // 1 条轨道
        let ticksPerBeat: UInt16 = 480             // 分辨率 480 PPQ
        data.append(bigEndian(ticksPerBeat))

        // 轨道块 MTrk
        var track = Data()

        // 1) 速度（tempo meta 事件）
        let usPerBeat = UInt32(60_000_000 / bpm)
        track.append(variableLength(0))            // delta-time 0
        track.append(0xFF)                         // meta
        track.append(0x51)                         // tempo
        track.append(0x03)                         // 长度 3
        track.append(UInt8((usPerBeat >> 16) & 0xFF))
        track.append(UInt8((usPerBeat >> 8) & 0xFF))
        track.append(UInt8(usPerBeat & 0xFF))

        // 2) 拍号 meta
        track.append(variableLength(0))
        track.append(0xFF); track.append(0x58); track.append(0x04)
        track.append(UInt8(timeSignature.0))
        track.append(UInt8(log2(Double(timeSignature.1))))  // 分母以 2 的幂存储
        track.append(0x18)                         // MIDI 时钟每四分音符
        track.append(0x08)                         // 每小节 32 分音符数

        // 3) 乐器 program change（默认 Acoustic Grand Piano = 0）
        track.append(variableLength(0))
        track.append(0xC0); track.append(0x00)

        // 4) 逐个音符（先按时间排序）
        let sorted = notes.sorted { $0.time < $1.time }
        var lastTick = 0
        for n in sorted {
            let startTick = Int((n.time / (60.0 / bpm)) * Double(ticksPerBeat))
            let durTick = max(Int((n.duration / (60.0 / bpm)) * Double(ticksPerBeat)), 30)
            let delta = max(0, startTick - lastTick)
            lastTick = startTick

            // Note On（0x90）
            track.append(variableLength(delta))
            track.append(0x90)
            track.append(n.midiNote)
            track.append(0x64)                     // velocity 100

            // Note Off（0x80）
            track.append(variableLength(durTick))
            track.append(0x80)
            track.append(n.midiNote)
            track.append(0x40)
        }

        // 5) 轨道结束 meta
        track.append(variableLength(0))
        track.append(0xFF); track.append(0x2F); track.append(0x00)

        data.append("MTrk".data(using: .ascii)!)
        data.append(bigEndian(UInt32(track.count)))
        data.append(track)

        return data
    }

    // MARK: - 编码辅助
    private static func variableLength(_ value: Int) -> Data {
        var v = value
        var bytes: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }
        return Data(bytes)
    }

    private static func bigEndian(_ v: UInt16) -> Data {
        var d = Data()
        d.append(UInt8((v >> 8) & 0xFF))
        d.append(UInt8(v & 0xFF))
        return d
    }

    private static func bigEndian(_ v: UInt32) -> Data {
        var d = Data()
        d.append(UInt8((v >> 24) & 0xFF))
        d.append(UInt8((v >> 16) & 0xFF))
        d.append(UInt8((v >> 8) & 0xFF))
        d.append(UInt8(v & 0xFF))
        return d
    }
}

/// AI 素材包导出：结构化 JSON，喂给大模型（音乐生成类）
public struct AIExportBundle: Codable {
    public var meta: Meta
    public var notes: [AINote]

    public struct Meta: Codable {
        public var bpm: Double
        public var timeSignature: [Int]
        public var keyGuess: String?
        public var instrument: String
        public var source: String
    }

    public struct AINote: Codable {
        public var note: String      // 音名如 "C4"
        public var midi: Int
        public var startSeconds: Double
        public var durationSeconds: Double
        public var beats: Double     // 以四分音符为单位的时值
    }

    public static func build(melody: Melody, instrument: String = "piano") -> AIExportBundle {
        let beatDur = 60.0 / melody.bpm
        let ns = melody.notes.map { n -> AINote in
            AINote(note: n.name,
                   midi: Int(n.midiNote),
                   startSeconds: n.time,
                   durationSeconds: n.duration,
                   beats: n.duration / beatDur)
        }
        return AIExportBundle(
            meta: Meta(bpm: melody.bpm,
                       timeSignature: [melody.timeSignature.0, melody.timeSignature.1],
                       keyGuess: KeyEstimator.guess(notes: melody.notes),
                       instrument: instrument,
                       source: "HumTune hum-transcription"),
            notes: ns
        )
    }
}

/// 调性（音阶）简单猜测：用音符集合匹配大调/小调
public enum KeyEstimator {
    public static func guess(notes: [Note]) -> String? {
        guard !notes.isEmpty else { return nil }
        let pitchClasses = Set(notes.map { Int($0.midiNote) % 12 })

        // Krumhansl 大调/小调权重（简化版）
        let majorProfile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        var bestKey: String? = nil
        var bestScore = -Double.greatestFiniteMagnitude

        for root in 0..<12 {
            // 大调：0=大调 tonic
            for (isMajor, profile) in [(true, majorProfile), (false, minorProfile)] {
                var score = 0.0
                for (pc, w) in profile.enumerated() {
                    if pitchClasses.contains(pc) {
                        score += w
                    }
                }
                // 旋转到 root
                // 简化：直接用未旋转的 pc 集合匹配（已含所有出现音）
                let keyName = noteNames[root] + (isMajor ? " major" : " minor")
                if score > bestScore {
                    bestScore = score
                    bestKey = keyName
                }
            }
        }
        return bestKey
    }
}