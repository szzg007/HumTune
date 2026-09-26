// 五线谱视图：CoreGraphics 自绘
import SwiftUI
import HumTuneCore

struct ScoreView: View {
    let melody: Melody

    var body: some View {
        Canvas { context, size in
            drawScore(context: context, size: size)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func drawScore(context: GraphicsContext, size: CGSize) {
        // 高音谱号区域坐标系统
        let lineSpacing: CGFloat = 12
        let topY: CGFloat = 60
        let leftX: CGFloat = 120
        let rightX = size.width - 30

        // 画五行谱线
        for i in 0..<5 {
            let y = topY + CGFloat(i) * lineSpacing
            var path = Path()
            path.move(to: CGPoint(x: leftX, y: y))
            path.addLine(to: CGPoint(x: rightX, y: y))
            context.stroke(path, with: .color(.black), lineWidth: 1)
        }

        // 高音谱号（简化，用文字）
        context.draw(Text("𝄞").font(.system(size: 60)),
                     at: CGPoint(x: leftX - 45, y: topY + 2.5 * lineSpacing))

        // 音符映射：midi → 谱线 Y 位置（高音谱号）
        // 高音谱号 bottom line = E4 (64), top line = F5 (77)
        // 每半音一个 step，step = lineSpacing/2
        let step = lineSpacing / 2
        // midi 72 (C5) 位于顶线下两格？简化：用 midi 计算相对位置
        // bottom line (第一线) = E4 = 64
        let bottomLineMidi = 64
        let bottomLineY = topY + 4 * lineSpacing

        for note in melody.notes {
            let midi = Int(note.midiNote)
            let diatonY = bottomLineY - CGFloat(midi - bottomLineMidi) * step

            // 符头
            let idx = melody.notes.firstIndex(where: { $0.time == note.time && $0.midiNote == note.midiNote }) ?? 0
            let orderX = leftX + 20 + CGFloat(idx) * ((rightX - leftX - 40) / CGFloat(max(1, melody.notes.count)))

            // 画符头（椭圆）
            let head = Path(ellipseIn: CGRect(x: orderX - 8, y: diatonY - step, width: 14, height: step * 1.7))
            context.fill(head, with: .color(.black))

            // 符干
            let isLow = midi < 67  // 低于中间线（B4=71 为中线偏上）
            var stem = Path()
            let stemX = orderX + 6
            if isLow {
                stem.move(to: CGPoint(x: stemX, y: diatonY - step))
                stem.addLine(to: CGPoint(x: stemX, y: diatonY - step * 3.5))
            } else {
                stem.move(to: CGPoint(x: stemX, y: diatonY + step * 0.7))
                stem.addLine(to: CGPoint(x: stemX, y: diatonY + step * 3.5))
            }
            context.stroke(stem, with: .color(.black), lineWidth: 1.5)
        }
    }
}

// 钢琴卷帘视图：音符条 + 键盘
struct PianoRollView: View {
    let melody: Melody

    var body: some View {
        GeometryReader { geo in
            let noteMin = melody.notes.map { Int($0.midiNote) }.min() ?? 55
            let noteMax = melody.notes.map { Int($0.midiNote) }.max() ?? 72
            let range = max(12, noteMax - noteMin + 8)
            let totalTime = (melody.notes.map { $0.time + $0.duration }.max() ?? 1.0).clamped

            ZStack(alignment: .topLeading) {
                // 音高网格背景
                VStack(spacing: 0) {
                    ForEach(0..<range, id: \.self) { i in
                        let midi = noteMax + 4 - i
                        HStack {
                            Text(noteLabel(midi))
                                .font(.caption2)
                                .frame(width: 28, alignment: .trailing)
                            Rectangle()
                                .fill(isBlackKey(midi) ? Color.black.opacity(0.08) : Color.gray.opacity(0.05))
                                .frame(height: max(8, geo.size.height / CGFloat(range) - 1))
                        }
                        .frame(height: geo.size.height / CGFloat(range))
                    }
                }

                // 音符条
                ForEach(melody.notes.indices, id: \.self) { i in
                    let n = melody.notes[i]
                    let midi = Int(n.midiNote)
                    let yTop = CGFloat(noteMax + 4 - midi) * (geo.size.height / CGFloat(range))
                    let yHeight = geo.size.height / CGFloat(range) * 0.85
                    let x = 32 + CGFloat(n.time / totalTime) * (geo.size.width - 40)
                    let w = max(6, CGFloat(n.duration / totalTime) * (geo.size.width - 40))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.75))
                        .frame(width: w, height: yHeight)
                        .position(x: x + w / 2, y: yTop + yHeight / 2)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func noteLabel(_ midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let oct = midi / 12 - 1
        return "\(names[midi % 12])\(oct)"
    }

    private func isBlackKey(_ midi: Int) -> Bool {
        let pc = midi % 12
        return [1, 3, 6, 8, 10].contains(pc)
    }
}

extension Double {
    var clamped: Double { max(0.3, self) }
}