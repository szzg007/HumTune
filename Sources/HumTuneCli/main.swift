// HumTune CLI 验证器：不依赖 Xcode/XCTest，用命令行跑通核心引擎
// 用法：swift run HumTuneCli [core|synth]
import Foundation
import HumTuneCore

// 参数分派
let args = CommandLine.arguments
if args.count > 1 && args[1] == "synth" {
    exit(runSynthTest())
}

// 简易断言
var failures = 0
func check(_ cond: Bool, _ label: String) {
    if cond {
        print("✅ \(label)")
    } else {
        print("❌ \(label)")
        failures += 1
    }
}

func sine(freq: Double, sampleRate: Double = 44100, duration: Double = 0.5) -> [Double] {
    let n = Int(sampleRate * duration)
    return (0..<n).map { i in sin(2 * .pi * freq * Double(i) / sampleRate) }
}

// MARK: 1. YIN 音高精度
print("=== 1. YIN 音高精度 ===")
let engine = YINPitchEngine(sampleRate: 44100, minFrequency: 60, maxFrequency: 1000)
let testFreqs: [Double] = [110, 220, 261.63, 330, 440, 523.25, 660, 880]
for f in testFreqs {
    let samples = sine(freq: f)
    let (est, conf) = engine.estimate(samples: samples)
    let errorCents = abs(1200 * log2(est / f))
    let ok = conf > 0.7 && errorCents < 30
    print(String(format: "  f=%.2fHz → est=%.2fHz conf=%.2f err=%.1f cents %@", f, est, conf, errorCents, ok ? "OK" : "FAIL"))
    if !ok { failures += 1 }
}

// MARK: 2. 音高换算
print("\n=== 2. 音高换算 ===")
check(PitchConverter.midiNote(fromHz: 440.0) == 69, "440Hz = A4(69)")
check(PitchConverter.midiNote(fromHz: 261.63) == 60, "261.63Hz = C4(60)")
check(abs(PitchConverter.hz(fromMidi: 69) - 440.0) < 0.01, "69 → 440Hz")

// MARK: 3. 移调
print("\n=== 3. 移调 ===")
let n0 = Note(time: 0, duration: 0.5, pitchHz: 440, midiNote: 69)
let up = PitchConverter.transpose([n0], semitones: 2)
let down = PitchConverter.transpose([n0], semitones: -2)
check(up[0].midiNote == 71, "+2 半音 → 71(B4)")
check(down[0].midiNote == 67, "-2 半音 → 67(G4)")

// MARK: 4. 音名
print("\n=== 4. 音名 ===")
check(Note(time: 0, duration: 1, pitchHz: 261.63, midiNote: 60).name == "C4", "60 = C4")
check(Note(time: 0, duration: 1, pitchHz: 466.16, midiNote: 70).name == "A#4", "70 = A#4")

// MARK: 5. MIDI 写入
print("\n=== 5. MIDI 写入 ===")
let midiNotes = [
    Note(time: 0, duration: 0.5, pitchHz: 261.63, midiNote: 60),
    Note(time: 0.5, duration: 0.5, pitchHz: 293.66, midiNote: 62),
    Note(time: 1.0, duration: 1.0, pitchHz: 329.63, midiNote: 64),
]
if let data = try? MIDIWriter.write(notes: midiNotes, bpm: 120) {
    let header = String(data: data.prefix(4), encoding: .ascii)
    check(header == "MThd", "MIDI 头 = MThd")
    check(data.count > 40, "MIDI 文件大小 > 40B")
    let out = "/tmp/humtune_test.mid"
    try? data.write(to: URL(fileURLWithPath: out))
    print("  已写出 \(out)")
} else {
    check(false, "MIDI 写成失败")
}

// MARK: 6. 端到端：正弦旋律 → 音高轨迹 → 音符
print("\n=== 6. 端到端旋律识别 ===")
let sr: Double = 44100
var melody: [Double] = []
let melodyFreqs: [(Double, Double)] = [(261.63, 0.4), (329.63, 0.4), (392.0, 0.4)]
for (f, d) in melodyFreqs {
    melody += sine(freq: f, sampleRate: sr, duration: d)
}
let splitter = FrameSplitter()
let tracker = PitchTracker(engine: engine, splitter: splitter)
let frames = tracker.track(samples: melody)
let segmenter = NoteSegmenter()
let notes = segmenter.segment(frames: frames)
print("  识别音符数: \(notes.count)")
for n in notes {
    print(String(format: "    %@ (midi %d) 起 %.2fs 时值 %.2fs", n.name, n.midiNote, n.time, n.duration))
}
check(notes.count >= 3, "识别 ≥3 个音符")
if notes.count >= 3 {
    check(notes[0].midiNote == 60, "第1音 = C4")
    check(notes[1].midiNote == 64, "第2音 = E4")
    check(notes[2].midiNote == 67, "第3音 = G4")
}

// MARK: 7. BPM 估算 + AI 导出包
print("\n=== 7. BPM + AI 导出包 ===")
let bpm = BPMEstimator.estimate(notes: notes)
print("  估算 BPM = \(Int(bpm))")
let mel = Melody(notes: notes, bpm: bpm)
let bundle = AIExportBundle.build(melody: mel)
check(bundle.notes.count == notes.count, "AI 素材包音符数一致")
if let json = try? JSONEncoder().encode(bundle) {
    let jsonStr = String(data: json, encoding: .utf8)!
    let out = "/tmp/humtune_ai_bundle.json"
    try? jsonStr.write(toFile: out, atomically: true, encoding: .utf8)
    print("  已写出 AI 素材包 \(out)")
    print("  预览: \(jsonStr.prefix(300))")
}

print("\n==========================")
if failures == 0 {
    print("🎉 全部验证通过")
} else {
    print("⚠️ 有 \(failures) 项失败")
    exit(1)
}