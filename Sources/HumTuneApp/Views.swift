import SwiftUI
import AVFoundation
import HumTuneCore

/// 实时波形视图（跟真实声压强绑定，非装饰动画）
struct WaveformView: View {
    let samples: [Float]
    let liveAmplitude: Float
    let isRecording: Bool

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let mid = size.height / 2
                let ampScale = size.height / 2 - 4

                // 中线
                var line = Path()
                line.move(to: CGPoint(x: 0, y: mid))
                line.addLine(to: CGPoint(x: size.width, y: mid))
                context.stroke(line, with: .color(Color.accentColor.opacity(0.2)), lineWidth: 1)

                if !samples.isEmpty {
                    // 完整波形
                    var path = Path()
                    let step = max(1, samples.count / max(1, Int(size.width)))
                    var x: CGFloat = 0
                    var i = 0
                    while i < samples.count {
                        let amp = Float(min(1.0, abs(samples[i]) * 4.0))
                        let y = mid - CGFloat(amp) * ampScale
                        if x == 0 {
                            path.move(to: CGPoint(x: 0, y: mid))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        x += 1
                        i += step
                    }
                    context.stroke(path, with: .color(Color.accentColor), lineWidth: 2)
                } else if isRecording {
                    // 实时对称振幅条
                    let amp = CGFloat(min(1.0, liveAmplitude))
                    let bar = amp * ampScale
                    var path = Path()
                    path.move(to: CGPoint(x: size.width / 2 - 6, y: mid - bar))
                    path.addLine(to: CGPoint(x: size.width / 2 - 6, y: mid + bar))
                    path.move(to: CGPoint(x: size.width / 2 + 6, y: mid - bar * 0.6))
                    path.addLine(to: CGPoint(x: size.width / 2 + 6, y: mid + bar * 0.6))
                    context.stroke(path, with: .color(Color.red), lineWidth: 4)
                }
            }
        }
    }
}

/// 大录音键
struct RecordButton: View {
    let state: RecordingEngine.State
    let action: () -> Void
    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(state == .recording ? Color.red : Color.red.opacity(0.85))
                    .frame(width: 96, height: 96)
                    .shadow(color: state == .recording ? .red.opacity(0.6) : .clear, radius: 20)

                if state == .recording {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulsing ? 1.1 : 0.95)
                        .opacity(pulsing ? 0 : 0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsing)
                        .onAppear { pulsing = true }
                }

                if state == .recording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 简谱视图
struct JianpuView: View {
    let notes: [Note]
    let key: KeySignature?

    var body: some View {
        let formatter = JianpuFormatter()
        let text = formatter.format(notes, key: key)
        ScrollView {
            Text(text)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 五线谱视图（简化为音名+位置示意）
struct ScoreView: View {
    let notes: [Note]
    let key: KeySignature?

    var body: some View {
        VStack {
            Spacer()
            let speller = NoteSpeller()
            HStack(spacing: 12) {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    let spelling = speller.spell(midi: note.midi, key: key)
                    VStack(spacing: 2) {
                        Text(spelling.step)
                            .font(.system(size: 28, weight: .bold))
                        Text("\(spelling.alter > 0 ? "#" : spelling.alter < 0 ? "b" : "")\(spelling.octave)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 48, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Text("五线谱版式（MusicXML 导出后由 MuseScore 精排）")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }
}