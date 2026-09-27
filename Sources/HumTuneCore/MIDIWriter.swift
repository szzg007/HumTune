import Foundation

/// MIDI 文件写入器（SMF 格式 0/1）
/// 遵循标准 MIDI 文件规范（MThd + MTrk，VLQ 变长编码）
public struct MIDIWriter {

    public enum Format {
        case singleTrack  // 格式 0（所有事件在单轨）
    }

    public init() {}

    /// 导出 MIDI 文件数据
    /// - Parameters:
    ///   - notes: 量化后的音符（绝对时间秒）
    ///   - bpm: 拍速
    ///   - timeSignature: 拍号
    ///   - key: 调性
    ///   - instrument: GM 音色号（0~127）
    /// - Returns: MIDI 文件二进制数据
    public func write(
        notes: [Note],
        bpm: Double,
        timeSignature: TimeSignature = TimeSignature(),
        key: KeySignature? = nil,
        instrument: Int = 0
    ) -> Data {
        let ppqn = 480  // 每四分音符 tick 数
        let tempoMicrosecondsPerQuarter = Int(round(60_000_000.0 / bpm))

        var trackEvents = Data()

        // 1. 轨道名
        let name = "HumTune Melody"
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xFF, 0x03, UInt8(name.count)])
        trackEvents.append(contentsOf: name.utf8)

        // 2. 拍号 meta（0x58 04 nn dd cc bb）
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xFF, 0x58, 0x04])
        trackEvents.append(UInt8(timeSignature.numerator))
        trackEvents.append(UInt8(log2(Double(timeSignature.denominator))))
        trackEvents.append(0x18) // 每 MIDI 时钟 24 个 tick
        trackEvents.append(0x08) // 每四分音符 8 个 32 分音符

        // 3. 速度 meta（0x51 03 tttttt）
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xFF, 0x51, 0x03])
        trackEvents.append(UInt8((tempoMicrosecondsPerQuarter >> 16) & 0xFF))
        trackEvents.append(UInt8((tempoMicrosecondsPerQuarter >> 8) & 0xFF))
        trackEvents.append(UInt8(tempoMicrosecondsPerQuarter & 0xFF))

        // 4. 调号 meta（0x59 02 sf mi）
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xFF, 0x59, 0x02])
        let fifths = Int8(key?.fifths ?? 0)
        trackEvents.append(UInt8(bitPattern: fifths))
        trackEvents.append(key?.isMajor ?? true ? 0x00 : 0x01)

        // 5. Program Change（音色）
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xC0, UInt8(instrument)])

        // 6. 音符事件（按时间排序）
        var events: [(tick: Int, data: [UInt8])] = []

        for note in notes {
            let startTick = Int(round(note.startTime * Double(ppqn) * (Double(timeSignature.denominator) / 4.0)))
            let endTick = Int(round((note.startTime + note.duration) * Double(ppqn) * (Double(timeSignature.denominator) / 4.0)))

            let midiVal = UInt8(max(0, min(127, note.midi)))
            let velocity: UInt8 = 100

            // Note On
            events.append((tick: startTick, data: [0x90, midiVal, velocity]))
            // Note Off（用 Note On + velocity 0 或 Note Off）
            events.append((tick: endTick, data: [0x80, midiVal, 0]))
        }

        // 按 tick 排序
        events.sort { $0.tick < $1.tick }

        var lastTick = 0
        for event in events {
            let delta = event.tick - lastTick
            trackEvents.append(contentsOf: Self.vlq(delta))
            trackEvents.append(contentsOf: event.data)
            lastTick = event.tick
        }

        // 7. 曲目结束 meta（0xFF 0x2F 0x00）
        trackEvents.append(contentsOf: Self.vlq(0))
        trackEvents.append(contentsOf: [0xFF, 0x2F, 0x00])

        // 组装 SMF
        var data = Data()
        // Header Chunk
        data.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])  // MThd
        data.append(contentsOf: Self.uint32(6))
        data.append(contentsOf: Self.uint16(0))   // 格式 0
        data.append(contentsOf: Self.uint16(1))   // 1 轨
        data.append(contentsOf: Self.uint16(UInt16(ppqn)))
        // Track Chunk
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])  // MTrk
        data.append(contentsOf: Self.uint32(UInt32(trackEvents.count)))
        data.append(trackEvents)

        return data
    }

    /// 可变长数值编码（VLQ）
    static func vlq(_ value: Int) -> [UInt8] {
        var v = value
        var bytes: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }
        return bytes
    }

    static func uint32(_ v: UInt32) -> [UInt8] {
        return [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    static func uint16(_ v: UInt16) -> [UInt8] {
        return [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }
}