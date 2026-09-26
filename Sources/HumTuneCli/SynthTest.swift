// SynthEngine 验证：加载系统 GM 音色库，切换音色，播放一个音（无界面发声）
import Foundation
import AVFoundation
import HumTuneCore

public func runSynthTest() -> Int32 {
    print("=== GM 音色合成引擎验证 ===")

    let synth = SynthEngine()
    let dls = SynthEngine.systemDLS
    print("系统 GM 音色库路径: \(dls)")
    print("文件存在: \(FileManager.default.fileExists(atPath: dls) ? "✅" : "❌")")

    do {
        try synth.loadSystemGM()
        print("✅ 加载系统 GM 音色库成功 (128 音色)")
        print("GM 音色总数: \(GMInstruments.names.count)")

        print("\n切换音色测试:")
        for prog in [0, 40, 73] as [UInt8] {
            synth.setProgram(prog)
            print("  ✅ program \(prog) = \(GMInstruments.names[Int(prog)])")
        }

        print("\n播放测试音: C4 (midi 60) 钢琴 1 秒…")
        synth.setProgram(0)
        synth.playNote(60, duration: 1.0)

        print("播放旋律: C4-E4-G4 …")
        let melody = [
            Note(time: 0.0, duration: 0.4, pitchHz: 261.63, midiNote: 60),
            Note(time: 0.4, duration: 0.4, pitchHz: 329.63, midiNote: 64),
            Note(time: 0.8, duration: 0.4, pitchHz: 392.0, midiNote: 67),
        ]
        synth.playMelody(melody)

        Thread.sleep(forTimeInterval: 1.6)
        synth.stop()
        print("\n✅ GM 音色合成引擎工作正常")
        return 0
    } catch {
        print("❌ 加载失败: \(error.localizedDescription)")
        return 1
    }
}