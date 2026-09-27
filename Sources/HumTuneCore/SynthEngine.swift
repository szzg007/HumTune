import Foundation

/// 合成引擎：把音符序列渲染成 PCM 音频
/// 提供多种波形（模拟不同乐器质感），带 ADSR 包络避免爆音
public struct SynthEngine {

    public enum Waveform: String, CaseIterable, Identifiable {
        case sine = "正弦（柔）"
        case triangle = "三角（暖）"
        case square = "方波（穿透）"
        case sawtooth = "锯齿（亮）"
        public var id: String { rawValue }
    }

    public init() {}

    /// 渲染完整旋律为 PCM
    /// - Parameter notes: 音符（startTime/duration 已为秒）
    /// - Returns: 单声道 float PCM（-1~1）
    public func render(notes: [Note], waveform: Waveform = .sine, sampleRate: Double = 44100.0, gain: Double = 0.5) -> [Float] {
        guard !notes.isEmpty else { return [] }
        let totalDuration = (notes.last!.startTime + notes.last!.duration) + 0.3
        let total = Int(totalDuration * sampleRate)
        var out = [Float](repeating: 0, count: total)

        for note in notes {
            renderNote(midi: note.midi, start: note.startTime, duration: note.duration,
                       waveform: waveform, sampleRate: sampleRate, gain: gain, into: &out)
        }
        return out
    }

    /// 渲染单音符（试听用）
    public func renderNote(midi: Int, duration: Double = 0.5, waveform: Waveform = .sine, sampleRate: Double = 44100.0, gain: Double = 0.5) -> [Float] {
        let total = Int((duration + 0.1) * sampleRate)
        var out = [Float](repeating: 0, count: total)
        renderNote(midi: midi, start: 0, duration: duration, waveform: waveform, sampleRate: sampleRate, gain: gain, into: &out)
        return out
    }

    // MARK: - Private

    private func freq(_ midi: Int) -> Double {
        return 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    private func renderNote(midi: Int, start: Double, duration: Double, waveform: Waveform, sampleRate: Double, gain: Double, into out: inout [Float]) {
        let f = freq(midi)
        let startIdx = Int(start * sampleRate)
        let durIdx = Int(duration * sampleRate)

        for i in 0..<durIdx {
            let idx = startIdx + i
            guard idx < out.count else { break }
            let t = Double(i) / sampleRate
            let env = envelope(t: t, duration: duration)
            let phase = f * t
            let sample = oscillator(waveform: waveform, phase: phase) * env * gain
            out[idx] += Float(max(-1.0, min(1.0, sample)))
        }
    }

    private func oscillator(waveform: Waveform, phase: Double) -> Double {
        let p = phase.truncatingRemainder(dividingBy: 1.0)
        switch waveform {
        case .sine:
            return sin(2 * .pi * p)
        case .triangle:
            return 2 * abs(2 * p - 1) - 1
        case .square:
            return p < 0.5 ? 1 : -1
        case .sawtooth:
            return 2 * p - 1
        }
    }

    /// ADSR 简化：attack + release（避免起止爆音）
    private func envelope(t: Double, duration: Double) -> Double {
        let attack = min(1.0, t / 0.02)
        let release = min(1.0, (duration - t) / 0.06)
        return max(0.0, min(attack, release))
    }
}