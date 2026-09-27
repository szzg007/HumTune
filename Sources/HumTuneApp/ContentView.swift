import SwiftUI
import AppKit
import HumTuneCore

/// 主内容视图
struct ContentView: View {
    @StateObject private var engine = RecordingEngine()
    @StateObject private var player = AudioPlayer()
    @State private var notes: [Note] = []
    @State private var key: KeySignature? = nil
    @State private var bpm: Double = 120
    @State private var hasResult = false
    @State private var viewMode: ViewMode = .jianpu
    @State private var waveform: SynthEngine.Waveform = .sine
    @State private var playingIndex: Int = 0

    enum ViewMode: String, CaseIterable, Identifiable {
        case jianpu = "简谱"
        case score = "五线谱"
        case notes = "音符编辑"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 标题栏
            HStack {
                Text("哼曲 HumTune")
                    .font(.title2.bold())
                Spacer()
                Menu {
                    Picker("音色", selection: $waveform) {
                        ForEach(SynthEngine.Waveform.allCases) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    Divider()
                    Button("导出 MIDI") { exportMIDI() }
                    Button("导出 MusicXML") { exportMusicXML() }
                    Button("导出简谱文本") { exportJianpu() }
                    Button("导出音频 WAV") { exportWAV() }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
            }
            .padding(.horizontal)

            // 波形区（主视觉）
            WaveformView(
                samples: engine.samples,
                liveAmplitude: engine.liveAmplitude,
                isRecording: engine.state == .recording
            )
            .frame(height: 140)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal)

            // 录音计时
            if engine.state == .recording {
                Text(String(format: "%.1f 秒", engine.elapsedTime))
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.red)
            }

            // 大录音键
            RecordButton(state: engine.state) {
                toggleRecording()
            }

            // 结果区
            if hasResult && engine.state == .stopped {
                Divider()

                // tab 切换
                Picker("视图", selection: $viewMode) {
                    Text("简谱").tag(ViewMode.jianpu)
                    Text("五线谱").tag(ViewMode.score)
                    Text("音符编辑").tag(ViewMode.notes)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                // 调性信息
                if let k = key {
                    Text("调性：\(keyName(k)) · BPM：\(Int(bpm)) · \(notes.count) 个音符")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 内容区
                Group {
                    switch viewMode {
                    case .jianpu:
                        JianpuView(notes: notes, key: key)
                            .frame(height: 100)
                    case .score:
                        ScoreView(notes: notes, key: key)
                            .frame(height: 100)
                    case .notes:
                        NoteEditList(
                            notes: $notes,
                            playingIndex: playingIndex,
                            onPreview: { midi in player.previewNote(midi: midi, waveform: waveform) }
                        )
                        .frame(height: 180)
                    }
                }
                .padding(.horizontal)

                // 播放/导出操作栏
                HStack(spacing: 16) {
                    Button(player.isPlaying ? "停止" : "▶ 播放") {
                        togglePlay()
                    }
                    .buttonStyle(.borderedProminent)

                    Menu("导出") {
                        Button("MIDI") { exportMIDI() }
                        Button("MusicXML") { exportMusicXML() }
                        Button("音频 WAV") { exportWAV() }
                        Button("简谱文本") { exportJianpu() }
                    }
                    .buttonStyle(.bordered)

                    Picker("", selection: $waveform) {
                        ForEach(SynthEngine.Waveform.allCases) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .frame(width: 140)
                }
            }

            Spacer()
        }
        .padding(.vertical)
        .frame(minWidth: 520, minHeight: 640)
        .onReceive(player.$isPlaying) { playing in
            if !playing { playingIndex = 0 }
        }
    }

    // MARK: - 录音

    private func toggleRecording() {
        switch engine.state {
        case .idle, .stopped:
            hasResult = false
            player.stop()
            do {
                try engine.start()
            } catch {
                print("录音失败：\(error)")
            }
        case .recording:
            engine.stop()
            engine.transcribe { r in
                self.notes = r.notes
                self.key = r.key
                self.bpm = r.bpm
                self.hasResult = true
            }
        }
    }

    // MARK: - 播放

    private func togglePlay() {
        if player.isPlaying {
            player.stop()
            playingIndex = 0
        } else {
            player.play(notes: notes, waveform: waveform)
        }
    }

    // MARK: - 导出

    private func exportMIDI() {
        let writer = MIDIWriter()
        let data = writer.write(notes: notes, bpm: bpm, key: key)
        saveData(data, ext: "mid", name: "HumTune旋律")
    }

    private func exportMusicXML() {
        let exporter = MusicXMLExporter()
        let xml = exporter.export(notes: notes, key: key, bpm: bpm)
        saveData(Data(xml.utf8), ext: "musicxml", name: "HumTune旋律")
    }

    private func exportJianpu() {
        let formatter = JianpuFormatter()
        let text = formatter.format(notes, key: key)
        saveData(Data(text.utf8), ext: "txt", name: "HumTune简谱")
    }

    private func exportWAV() {
        let synth = SynthEngine()
        let samples = synth.render(notes: notes, waveform: waveform)
        let writer = WAVWriter()
        let data = writer.write(samples: samples)
        saveData(data, ext: "wav", name: "HumTune旋律")
    }

    private func saveData(_ data: Data, ext: String, name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(name).\(ext)"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    private func keyName(_ key: KeySignature) -> String {
        let tonicNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let tonic = tonicNames[key.tonicMidi % 12]
        return "\(tonic) \(key.isMajor ? "大调" : "小调")"
    }
}

/// 音符编辑列表：可逐音试听 + 微调音高/时值
struct NoteEditList: View {
    @Binding var notes: [Note]
    let playingIndex: Int
    let onPreview: (Int) -> Void

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    HStack(spacing: 8) {
                        Text("#\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .trailing)

                        Button(action: { onPreview(note.midi) }) {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.borderless)

                        Text("\(noteNames[note.midi % 12])\(note.octave)")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 56, alignment: .leading)

                        Button(action: { changePitch(index, -1) }) {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(note.midi <= 21)

                        Button(action: { changePitch(index, +1) }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(note.midi >= 108)

                        Text(String(format: "%.2fs", note.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 52)

                        Button(action: { changeDuration(index, -0.05) }) {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(note.duration <= 0.05)

                        Button(action: { changeDuration(index, +0.05) }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)

                        Button(action: { notes.remove(at: index) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        if playingIndex == index {
                            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .cornerRadius(6)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func changePitch(_ index: Int, _ delta: Int) {
        guard index < notes.count else { return }
        let n = notes[index]
        notes[index] = Note(midi: n.midi + delta, startTime: n.startTime, duration: n.duration)
    }

    private func changeDuration(_ index: Int, _ delta: Double) {
        guard index < notes.count else { return }
        let n = notes[index]
        let newDur = max(0.05, n.duration + delta)
        notes[index] = Note(midi: n.midi, startTime: n.startTime, duration: newDur)
    }
}

@main
struct HumTuneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
    }
}