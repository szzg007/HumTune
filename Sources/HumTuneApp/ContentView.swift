// 主界面：录音 → 转谱 → 五线谱/卷帘 → 换乐器 → 导出
import SwiftUI
import AppKit
import HumTuneCore

struct ContentView: View {
    @StateObject private var recorder = RecordingEngine()
    @State private var melody: Melody? = nil
    @State private var selectedInstrument: UInt8 = 0
    @State private var synth = SynthEngine()
    @State private var viewMode = true   // true=五线谱, false=钢琴卷帘
    @State private var statusText = "点麦克风开始哼歌"

    var body: some View {
        HSplitView {
            // 左侧：录音 + 变换控制
            VStack(alignment: .leading, spacing: 16) {
                Text("🎤 哼歌创作")
                    .font(.largeTitle.bold())

                Text(statusText)
                    .foregroundColor(.secondary)

                // 波形/音量条
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 120)
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(recorder.isRecording ? Color.red.opacity(0.6) : Color.blue.opacity(0.4))
                            .frame(height: CGFloat(recorder.level) * 110)
                    }
                }
                .frame(height: 120)

                // 实时音高显示
                HStack {
                    Text("当前音:")
                    Text(recorder.currentNote)
                        .font(.title.bold())
                        .foregroundColor(.purple)
                    Spacer()
                    if recorder.currentFreq > 0 {
                        Text(String(format: "%.1f Hz", recorder.currentFreq))
                            .foregroundColor(.secondary)
                    }
                }

                // 录音按钮
                HStack(spacing: 12) {
                    Button(recorder.isRecording ? "⏹ 停止" : "🔴 开始哼歌") {
                        if recorder.isRecording {
                            recorder.stop()
                            melody = recorder.transcribe()
                            statusText = "识别完成，共 \(melody?.notes.count ?? 0) 个音符"
                            playMelody()
                        } else {
                            if recorder.requestPermission() {
                                recorder.start()
                                statusText = "录音中…哼出你的旋律"
                                melody = nil
                            } else {
                                statusText = "⚠️ 无麦克风权限，请在系统设置授权"
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(recorder.isRecording ? .red : .blue)
                    .font(.title3)

                    if melody != nil {
                        Button("🔊 重新播放") { playMelody() }
                            .buttonStyle(.bordered)
                    }
                }

                // 乐器选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎷 选择乐器")
                        .font(.headline)
                    Picker("", selection: $selectedInstrument) {
                        ForEach(GMInstruments.favorites, id: \.program) { fav in
                            Text(fav.name).tag(fav.program)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedInstrument) { newVal in
                        synth.setProgram(newVal)
                        playMelody()
                    }
                }

                // 变换控制
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎚 变换")
                        .font(.headline)
                    HStack {
                        Button("降半音 -") { transpose(-1) }
                        Button("升半音 +") { transpose(1) }
                        Button("减速 ⏪") { tempoScale(0.9) }
                        Button("加速 ⏩") { tempoScale(1.1) }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                // 导出按钮
                if melody != nil {
                    HStack {
                        Button("💾 导出 MIDI") { exportMIDI() }
                        Button("🤖 导出 AI 素材包") { exportAIBundle() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(minWidth: 380, idealWidth: 400, maxWidth: 460)

            Divider()

            // 右侧：五线谱 + 卷帘
            VStack(alignment: .leading) {
                if let mel = melody {
                    Picker("视图", selection: $viewMode) {
                        Text("五线谱").tag(true)
                        Text("钢琴卷帘").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    if viewMode {
                        ScoreView(melody: mel)
                    } else {
                        PianoRollView(melody: mel)
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("🎼 哼完会自动显示五线谱")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .frame(minWidth: 500)
        }
        .onAppear {
            do {
                try synth.loadSystemGM()
                synth.setProgram(0)
            } catch {
                statusText = "⚠️ 音色库加载失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - 动作
    private func playMelody() {
        guard let mel = melody, !mel.notes.isEmpty else { return }
        synth.playMelody(mel.notes)
    }

    private func transpose(_ semitones: Int) {
        guard var mel = melody else { return }
        mel.notes = PitchConverter.transpose(mel.notes, semitones: semitones)
        melody = mel
        playMelody()
    }

    private func tempoScale(_ factor: Double) {
        guard var mel = melody else { return }
        mel.notes = mel.notes.map { n in
            var m = n
            m.time /= factor
            m.duration /= factor
            return m
        }
        mel.bpm *= factor
        melody = mel
        playMelody()
    }

    private func exportMIDI() {
        guard let mel = melody else { return }
        do {
            let data = try MIDIWriter.write(notes: mel.notes, bpm: mel.bpm)
            saveData(data, ext: "mid")
        } catch {
            statusText = "导出失败: \(error.localizedDescription)"
        }
    }

    private func exportAIBundle() {
        guard let mel = melody else { return }
        let bundle = AIExportBundle.build(melody: mel, instrument: GMInstruments.names[Int(selectedInstrument)])
        if let json = try? JSONEncoder().encode(bundle) {
            saveData(json, ext: "json")
        }
    }

    private func saveData(_ data: Data, ext: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: ext) ?? .data]
        panel.nameFieldStringValue = "HumTune_\(Int(Date().timeIntervalSince1970)).\(ext)"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
            statusText = "✅ 已导出 \(url.lastPathComponent)"
        }
    }
}