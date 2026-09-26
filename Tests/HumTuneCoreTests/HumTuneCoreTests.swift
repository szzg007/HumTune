import XCTest
@testable import HumTuneCore

final class HumTuneCoreTests: XCTestCase {

    private func sine(freq: Double, sampleRate: Double = 44100, duration: Double = 0.5) -> [Double] {
        let n = Int(sampleRate * duration)
        return (0..<n).map { i in sin(2 * .pi * freq * Double(i) / sampleRate) }
    }

    func testYINSineAccuracy() {
        let engine = YINPitchEngine(sampleRate: 44100, minFrequency: 60, maxFrequency: 1000)
        let testFreqs: [Double] = [110, 220, 261.63, 330, 440, 523.25, 660, 880]
        for f in testFreqs {
            let (est, conf) = engine.estimate(samples: sine(freq: f))
            let errorCents = abs(1200 * log2(est / f))
            XCTAssertGreaterThan(conf, 0.7, "正弦波应高置信，f=\(f)")
            XCTAssertLessThan(errorCents, 30, "音高误差应 <30 音分，f=\(f) 误差 \(errorCents)")
        }
    }

    func testPitchConverter() {
        XCTAssertEqual(PitchConverter.midiNote(fromHz: 440.0), 69)
        XCTAssertEqual(PitchConverter.midiNote(fromHz: 261.63), 60)
        XCTAssertEqual(PitchConverter.midiNote(fromHz: 523.25), 72)
        XCTAssertEqual(PitchConverter.hz(fromMidi: 69), 440.0, accuracy: 0.01)
    }

    func testTranspose() {
        let n = Note(time: 0, duration: 0.5, pitchHz: 440, midiNote: 69)
        XCTAssertEqual(PitchConverter.transpose([n], semitones: 2)[0].midiNote, 71)
        XCTAssertEqual(PitchConverter.transpose([n], semitones: -2)[0].midiNote, 67)
    }

    func testMIDIWriter() throws {
        let notes = [
            Note(time: 0, duration: 0.5, pitchHz: 261.63, midiNote: 60),
            Note(time: 0.5, duration: 0.5, pitchHz: 293.66, midiNote: 62),
            Note(time: 1.0, duration: 1.0, pitchHz: 329.63, midiNote: 64),
        ]
        let data = try MIDIWriter.write(notes: notes, bpm: 120)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "MThd")
        XCTAssertGreaterThan(data.count, 40)
    }

    func testNoteName() {
        XCTAssertEqual(Note(time: 0, duration: 1, pitchHz: 261.63, midiNote: 60).name, "C4")
        XCTAssertEqual(Note(time: 0, duration: 1, pitchHz: 466.16, midiNote: 70).name, "A#4")
    }

    func testAIExportBundle() {
        let melody = Melody(notes: [
            Note(time: 0, duration: 0.5, pitchHz: 261.63, midiNote: 60),
            Note(time: 0.5, duration: 0.5, pitchHz: 293.66, midiNote: 62),
        ], bpm: 120)
        let bundle = AIExportBundle.build(melody: melody)
        XCTAssertEqual(bundle.notes.count, 2)
        XCTAssertEqual(bundle.notes[0].note, "C4")
        XCTAssertEqual(bundle.meta.bpm, 120)
    }

    func testEndToEndSineMelody() {
        let engine = YINPitchEngine()
        let tracker = PitchTracker(engine: engine, splitter: FrameSplitter())
        var samples: [Double] = []
        for (f, d) in [(261.63, 0.4), (329.63, 0.4), (392.0, 0.4)] {
            samples += sine(freq: f, sampleRate: 44100, duration: d)
        }
        let frames = tracker.track(samples: samples)
        let notes = NoteSegmenter().segment(frames: frames)
        XCTAssertGreaterThanOrEqual(notes.count, 3, "应识别 ≥3 音，实际 \(notes.count)")
        if notes.count >= 3 {
            XCTAssertEqual(notes[0].midiNote, 60)
            XCTAssertEqual(notes[1].midiNote, 64)
            XCTAssertEqual(notes[2].midiNote, 67)
        }
    }

    /// 人声化哼唱仿真：谐波 + 振幅包络 + 轻颤音 + 音间静音间隙
    private func humLike(freq: Double, duration: Double, sampleRate: Double = 44100) -> [Double] {
        let n = Int(sampleRate * duration)
        var out: [Double] = []
        for i in 0..<n {
            let t = Double(i) / sampleRate
            // 振幅包络：起音快、衰减慢（模拟哼唱）
            let attack = min(1.0, t / 0.05)
            let release = min(1.0, (duration - t) / 0.08)
            let env = max(0.0, min(attack, release))
            // 轻颤音（5Hz，±0.3% 频率调制）
            let vibrato = 1.0 + 0.003 * sin(2 * .pi * 5 * t)
            // 基频 + 2 个谐波（模拟人声频谱）
            let f1 = freq * vibrato
            let fundamental = sin(2 * .pi * f1 * t)
            let h2 = 0.5 * sin(2 * .pi * f1 * 2 * t)
            let h3 = 0.25 * sin(2 * .pi * f1 * 3 * t)
            out.append(env * (fundamental + h2 + h3) / 1.75)
        }
        return out
    }

    /// 真实哼唱仿真：C4-E4-G4 各 0.35s，音间 0.08s 静音
    func testHumLikeMelody() {
        let tracker = PitchTracker(engine: YINPitchEngine(), splitter: FrameSplitter())
        var samples: [Double] = []
        let zeros = [Double](repeating: 0, count: Int(44100 * 0.08))
        for f in [261.63, 329.63, 392.0] {
            samples += humLike(freq: f, duration: 0.35)
            samples += zeros
        }
        let frames = tracker.track(samples: samples)
        let notes = NoteSegmenter().segment(frames: frames)
        XCTAssertGreaterThanOrEqual(notes.count, 3, "哼唱仿真应识别 ≥3 音，实际 \(notes.count)")
        if notes.count >= 3 {
            XCTAssertEqual(notes[0].midiNote, 60)
            XCTAssertEqual(notes[1].midiNote, 64)
            XCTAssertEqual(notes[2].midiNote, 67)
        }
    }
}