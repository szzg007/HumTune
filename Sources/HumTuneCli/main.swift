import Foundation
import HumTuneCore

extension Array where Element == Double {
    func median() -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        } else {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }
    }
}

// HumTune CLI 验证器
// 替代 XCTest（CommandLineTools 环境可跑）

var passCount = 0
var failCount = 0

func check(_ name: String, _ condition: Bool) {
    if condition {
        passCount += 1
        print("✅ \(name)")
    } else {
        failCount += 1
        print("❌ \(name)")
    }
}

print("=== HumTune v2 核心引擎验证 ===\n")

// --- 测试 1：YIN 音高检测精度 ---
print("--- 测试 1：YIN 音高检测 ---")
let engine = PitchEngine(sampleRate: 44100.0, windowSize: 2048, hopSize: 512)
let sr = 44100.0

func sine(_ freq: Double, _ duration: Double) -> [Float] {
    let n = Int(sr * duration)
    var samples = [Float](repeating: 0, count: n)
    for i in 0..<n {
        samples[i] = Float(sin(2 * .pi * freq * Double(i) / sr))
    }
    return samples
}

// 220Hz（A3）
var samples = sine(220, 1.0)
var frames = engine.analyze(samples: samples)
var voiced = frames.filter { $0.frequency > 0 }
if let mid = voiced.map({ $0.frequency }).sorted().median() {
    let cents = 1200 * log2(mid / 220.0)
    check("220Hz 检测误差 \(String(format: "%.1f", abs(cents))) 音分 (<30)", abs(cents) < 30)
} else {
    check("220Hz 检测（无有效帧）", false)
}

// 440Hz（A4）
samples = sine(440, 1.0)
frames = engine.analyze(samples: samples)
voiced = frames.filter { $0.frequency > 0 }
if let mid = voiced.map({ $0.frequency }).sorted().median() {
    let cents = 1200 * log2(mid / 440.0)
    check("440Hz 检测误差 \(String(format: "%.1f", abs(cents))) 音分 (<30)", abs(cents) < 30)
} else {
    check("440Hz 检测（无有效帧）", false)
}

// --- 测试 2：端到端正弦旋律 C4-E4-G4 ---
print("\n--- 测试 2：端到端旋律识别 C4-E4-G4 ---")
func melodySine(freqs: [Double], noteDur: Double) -> [Float] {
    var out: [Float] = []
    for f in freqs {
        out += sine(f, noteDur)
        // 静音间隙
        out += [Float](repeating: 0, count: Int(sr * 0.05))
    }
    return out
}
let c4 = 261.63, e4 = 329.63, g4 = 392.0
let melody = melodySine(freqs: [c4, e4, g4], noteDur: 0.4)
let transcriber = Transcriber()
let result = transcriber.transcribe(samples: melody)
check("识别出 3 个音符（实际 \(result.notes.count)）", result.notes.count == 3)
let expectedMidi = [60, 64, 67]  // C4 E4 G4
let actualMidi = result.notes.map { $0.midi }
check("音符正确 C4-E4-G4（实际 \(actualMidi)）", actualMidi == expectedMidi)

// --- 测试 3：人声仿真（谐波+包络+颤音+静音） ---
print("\n--- 测试 3：人声仿真旋律 ---")
func humLike(freq: Double, duration: Double) -> [Float] {
    let n = Int(sr * duration)
    var samples = [Float](repeating: 0, count: n)
    for i in 0..<n {
        let t = Double(i) / sr
        // 颤音
        let vibrato = 1.0 + 0.005 * sin(2 * .pi * 5.0 * t)
        // 振幅包络（起音+衰减）
        let attack = min(1.0, t / 0.05)
        let decay = exp(-t * 1.5)
        let env = attack * decay
        // 基频 + 谐波
        var v = sin(2 * .pi * freq * vibrato * t)
        v += 0.4 * sin(2 * .pi * freq * 2 * t)
        v += 0.2 * sin(2 * .pi * freq * 3 * t)
        samples[i] = Float(v * env * 0.5)
    }
    return samples
}
var hum: [Float] = []
for f in [c4, e4, g4] {
    hum += humLike(freq: f, duration: 0.4)
    hum += [Float](repeating: 0, count: Int(sr * 0.08))
}
let humResult = transcriber.transcribe(samples: hum)
check("人声仿真识别 3 音符（实际 \(humResult.notes.count)）", humResult.notes.count == 3)
check("人声仿真音符正确（实际 \(humResult.notes.map { $0.midi })）", humResult.notes.map { $0.midi } == [60, 64, 67])

// --- 测试 4：调性识别 ---
print("\n--- 测试 4：调性识别 ---")
let cMajorNotes = [Note(midi: 60, startTime: 0, duration: 0.5),
                   Note(midi: 64, startTime: 0.5, duration: 0.5),
                   Note(midi: 67, startTime: 1.0, duration: 0.5),
                   Note(midi: 62, startTime: 1.5, duration: 0.5),
                   Note(midi: 65, startTime: 2.0, duration: 0.5)]
let keyEst = KeyEstimator()
if let key = keyEst.estimateKey(cMajorNotes) {
    check("C 大调识别（fifths=\(key.fifths) major=\(key.isMajor)）", key.fifths == 0 && key.isMajor)
} else {
    check("C 大调识别（无结果）", false)
}

// --- 测试 5：MIDI 写入 ---
print("\n--- 测试 5：MIDI 写入 ---")
let writer = MIDIWriter()
let midiData = writer.write(notes: cMajorNotes, bpm: 120, key: KeySignature(fifths: 0, tonicMidi: 60, isMajor: true))
// 检查头部 MThd
let header = [UInt8](midiData.prefix(4))
check("MIDI 头部 MThd（实际 \(header.map { String(format: "%02X", $0) }.joined())）", header == [0x4D, 0x54, 0x68, 0x64])
check("MIDI 数据非空（\(midiData.count) bytes）", midiData.count > 14)

// --- 测试 6：MusicXML 导出 ---
print("\n--- 测试 6：MusicXML 导出 ---")
let exporter = MusicXMLExporter()
let xml = exporter.export(notes: cMajorNotes, key: KeySignature(fifths: 0, tonicMidi: 60, isMajor: true))
check("MusicXML 包含 score-partwise", xml.contains("score-partwise"))
check("MusicXML 包含 note 标签", xml.contains("<note>"))

// --- 测试 7：简谱格式化 ---
print("\n--- 测试 7：简谱格式化 ---")
let jianpu = JianpuFormatter()
let jp = jianpu.format(cMajorNotes, key: KeySignature(fifths: 0, tonicMidi: 60, isMajor: true))
check("简谱输出（\(jp)）", !jp.isEmpty)

// --- 测试 8：合成引擎 + WAV 导出 ---
print("\n--- 测试 8：合成引擎 + WAV 导出 ---")
let synth = SynthEngine()
let synthSamples = synth.render(notes: cMajorNotes, waveform: .sine)
check("合成 PCM 非空（\(synthSamples.count) 采样）", synthSamples.count > 1000)
let wavWriter = WAVWriter()
let wavData = wavWriter.write(samples: synthSamples)
let riffStr = String(data: wavData.prefix(4), encoding: .ascii) ?? "?"
let waveStr = String(data: wavData.subdata(in: 8..<12), encoding: .ascii) ?? "?"
check("WAV 头 RIFF/WAVE（实际 \(riffStr)/\(waveStr)）", riffStr == "RIFF" && waveStr == "WAVE")
check("WAV 数据大小合理（\(wavData.count) bytes > 44）", wavData.count > 44)
// 写入实际文件供人工试听
let wavPath = "/tmp/humtune_test.wav"
try? wavData.write(to: URL(fileURLWithPath: wavPath))
print("  试听文件：\(wavPath)")

// --- 汇总 ---
print("\n=== 验证结果：\(passCount) 通过 / \(failCount) 失败 ===")
if failCount > 0 {
    exit(1)
} else {
    print("🎉 全部测试通过！")
    exit(0)
}