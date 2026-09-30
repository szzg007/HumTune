import SwiftUI
import AppKit
import HumTuneCore

/// 编辑工作台：从主界面点开的全新界面
/// 功能：换乐器试听 / 专业音格编辑 / 导出 MIDI&WAV / 导入参照音频 A/B 比对
struct StudioView: View {

    @Binding var notes: [Note]
    let bpm: Double
    let key: KeySignature?

    @StateObject private var player = GMSynthPlayer()
    @StateObject private var refPlayer = ReferencePlayer()
    @State private var selectedIndex: Int? = nil
    @State private var selectedInstrument: Int = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // 顶部：标题 + 返回
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)

                Spacer()
                Text("编辑工作台 · 换乐器 & 音格编辑")
                    .font(.title3.bold())
                Spacer()

                // 导出
                Menu {
                    Button("导出 MIDI") { exportMIDI() }
                    Button("导出音频 WAV") { exportWAV() }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            Divider()

            // 乐器选择区
            instrumentPicker

            Divider()

            // 主内容：音格编辑器
            PianoRollView(notes: $notes, selectedIndex: $selectedIndex, onPreview: { midi in
                player.previewNote(midi: midi)
            })
            .frame(minHeight: 360)

            Divider()

            // 底部操作栏：播放 + 参照音频
            bottomBar
        }
        .padding(.vertical)
        .frame(minWidth: 760, minHeight: 680)
        .onAppear {
            player.selectInstrument(selectedInstrument)
        }
        .onChange(of: selectedInstrument) { _, newValue in
            player.selectInstrument(newValue)
        }
    }

    // MARK: - 乐器选择器

    private var instrumentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("乐器音色")
                    .font(.headline)
                Spacer()
                Text("当前：\(GMInstruments.byProgram(selectedInstrument).zhName)")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal)

            // 常用乐器快捷按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GMInstruments.favorites) { inst in
                        Button {
                            selectedInstrument = inst.program
                            player.previewNote(midi: 72)  // 试弹一个中音 C5
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: iconFor(inst.program))
                                    .font(.title3)
                                Text(inst.zhName)
                                    .font(.caption)
                            }
                            .frame(width: 72, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedInstrument == inst.program ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedInstrument == inst.program ? Color.accentColor : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // 全部 128 音色下拉
            HStack {
                Text("全部音色")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $selectedInstrument) {
                    ForEach(GMInstruments.all) { inst in
                        Text("\(inst.zhName) (\(inst.name))").tag(inst.program)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Button {
                    if player.isPlaying { player.stop() } else { player.play(notes: notes, instrument: selectedInstrument) }
                } label: {
                    Label(player.isPlaying ? "停止" : "▶ 试听(整曲)", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(notes.isEmpty)

                Text("\(notes.count) 个音符")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // 参照音频对比
            HStack(spacing: 12) {
                Label("参照对比", systemImage: "waveform.and.mic")
                    .font(.subheadline)
                    .bold()

                if refPlayer.fileName != nil {
                    Label(refPlayer.fileName!, systemImage: "music.note")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button {
                    refPlayer.importAndLoad()
                } label: {
                    Label("导入音频(MP3/M4A/WAV)", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                if refPlayer.fileName != nil {
                    Button {
                        refPlayer.togglePlay()
                    } label: {
                        Label(refPlayer.isPlaying ? "暂停" : "播放参照", systemImage: refPlayer.isPlaying ? "pause.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)

                    // 进度条
                    if refPlayer.duration > 0 {
                        Slider(value: Binding(
                            get: { refPlayer.currentTime },
                            set: { refPlayer.seek(to: $0) }
                        ), in: 0...refPlayer.duration)
                        .frame(width: 160)
                        Text(timeStr(refPlayer.currentTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Button {
                        refPlayer.stop()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("移除参照音频")
                }

                Spacer()

                if let err = refPlayer.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - 导出

    private func exportMIDI() {
        let writer = MIDIWriter()
        let data = writer.write(notes: notes, bpm: bpm, key: key, instrument: selectedInstrument)
        saveData(data, ext: "mid", name: "HumTune-\(GMInstruments.byProgram(selectedInstrument).zhName)")
    }

    private func exportWAV() {
        let synth = SynthEngine()
        // 用波形合成渲染（音色近似；真正的 GM 采样渲染音频需离线渲染，后续版本补）
        let samples = synth.render(notes: notes, waveform: .sine)
        let writer = WAVWriter()
        let data = writer.write(samples: samples)
        saveData(data, ext: "wav", name: "HumTune-\(GMInstruments.byProgram(selectedInstrument).zhName)")
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

    // MARK: - 工具

    private func iconFor(_ program: Int) -> String {
        switch program {
        case 0...7: return "pianokeys"
        case 24...31: return "guitars"
        case 32...39: return "guitars.fill"
        case 40...47, 48...55: return "music.quarternote.3"
        case 56...63: return "trumpet.fill"
        case 64...71, 72...79: return "flute"
        default: return "music.note"
        }
    }

    private func timeStr(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}