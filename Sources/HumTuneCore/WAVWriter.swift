import Foundation

/// WAV 音频导出器（16-bit PCM）
/// 让用户能「保存音频」，不只是 MIDI
public struct WAVWriter {

    public init() {}

    /// 把 float PCM 编码成 WAV 文件数据
    /// - Parameters:
    ///   - samples: 单声道 float PCM（-1~1）
    ///   - sampleRate: 采样率（默认 44100）
    /// - Returns: WAV 文件二进制数据
    public func write(samples: [Float], sampleRate: Double = 44100.0) -> Data {
        var data = Data()
        let sr = Int(sampleRate)
        let numChannels = 1
        let bitsPerSample = 16
        let byteRate = sr * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = samples.count * 2

        // RIFF header
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: uint32(UInt32(36 + dataSize)))
        data.append(contentsOf: Array("WAVE".utf8))

        // fmt chunk
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: uint32(16))  // PCM chunk size
        data.append(contentsOf: uint16(1))   // audio format = PCM
        data.append(contentsOf: uint16(UInt16(numChannels)))
        data.append(contentsOf: uint32(UInt32(sr)))
        data.append(contentsOf: uint32(UInt32(byteRate)))
        data.append(contentsOf: uint16(UInt16(blockAlign)))
        data.append(contentsOf: uint16(UInt16(bitsPerSample)))

        // data chunk
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: uint32(UInt32(dataSize)))
        for s in samples {
            let clamped = max(-1.0, min(1.0, Double(s)))
            let intVal = Int16(clamped * 32767.0)
            data.append(contentsOf: int16(intVal))
        }

        return data
    }

    private func uint32(_ v: UInt32) -> [UInt8] {
        return [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }

    private func uint16(_ v: UInt16) -> [UInt8] {
        return [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]
    }

    private func int16(_ v: Int16) -> [UInt8] {
        return [UInt8(UInt16(bitPattern: v) & 0xFF), UInt8((UInt16(bitPattern: v) >> 8) & 0xFF)]
    }
}