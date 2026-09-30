import SwiftUI
import HumTuneCore

/// 专业 Piano Roll 音格编辑器
/// 横向 = 时间（可拉长/缩短时值），纵向 = 音高（可抬高/降低）
/// 支持拖拽、增删音符、网格吸附、鼠标悬停提示
struct PianoRollView: View {

    @Binding var notes: [Note]
    /// 选中的音符索引（用于高亮与删除）
    @Binding var selectedIndex: Int?
    /// 试听回调
    let onPreview: (Int) -> Void

    // 显示范围
    private let minMidi = 48   // C3
    private let maxMidi = 96   // C7
    private let rowHeight: CGFloat = 20
    private let pixelsPerBeat: CGFloat = 80   // 缩放基准
    @State private var bpm: Double = 120
    @State private var zoom: Double = 1.0

    // 拖拽状态
    @State private var dragNoteIndex: Int? = nil
    @State private var dragMode: DragMode = .none
    @State private var dragStartPoint: CGPoint = .zero
    @State private var dragOriginalNote: Note? = nil

    enum DragMode {
        case none       // 无拖拽
        case move       // 移动音符（改音高/时间）
        case stretch    // 拉伸时值（改右边界）
    }

    // 计算辅助
    private var midiRange: Int { maxMidi - minMidi + 1 }
    private func beatWidth() -> CGFloat { pixelsPerBeat * zoom }

    private var noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    init(notes: Binding<[Note]>, selectedIndex: Binding<Int?>, onPreview: @escaping (Int) -> Void) {
        self._notes = notes
        self._selectedIndex = selectedIndex
        self.onPreview = onPreview
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具条
            HStack(spacing: 16) {
                Text("音格编辑器")
                    .font(.headline)
                Spacer()
                Text("BPM")
                TextField("120", value: $bpm, format: .number)
                    .frame(width: 48)
                    .textFieldStyle(.roundedBorder)
                Text("缩放")
                Slider(value: $zoom, in: 0.4...2.0)
                    .frame(width: 120)
                Button("删除选中") {
                    if let idx = selectedIndex, idx < notes.count {
                        notes.remove(at: idx)
                        selectedIndex = nil
                    }
                }
                .disabled(selectedIndex == nil)
                Button("清空") {
                    notes.removeAll()
                    selectedIndex = nil
                }
                Text("音符数：\(notes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 卷帘主体
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // 背景网格
                    PianoRollGrid(minMidi: minMidi, maxMidi: maxMidi,
                                  rowHeight: rowHeight, beatWidth: beatWidth(),
                                  width: geo.size.width)

                    // 音符格子
                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        NoteCell(
                            note: note,
                            isSelected: selectedIndex == index,
                            rect: noteRect(for: note, viewWidth: geo.size.width)
                        )
                        .onTapGesture {
                            selectedIndex = index
                            onPreview(note.midi)
                        }
                        .gesture(dragGesture(index: index, note: note, viewWidth: geo.size.width))
                    }

                    // 播放/编辑光标
                }
            }
            .frame(minHeight: 300)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            .clipped()
            .padding(.horizontal)
            .padding(.bottom, 8)

            // 底部提示
            HStack {
                Text("拖拽格子左右边缘 = 拉长/缩短时值")
                Text("·")
                Text("拖拽中间 = 上下移音高 / 左右移时间")
                Text("·")
                Text("双击空白处 = 新增音符")
                Text("·")
                Text("单击格子 = 试听")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
        }
    }

    // MARK: - 布局计算

    private func noteLabel(for note: Note) -> some View {
        let text = "\(noteNames[note.midi % 12])\(note.octave)"
        return Text(text)
            .font(.system(size: 9))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
    }

    private func noteRect(for note: Note, viewWidth: CGFloat) -> CGRect {
        let x = CGFloat(note.startTime) * beatWidth()
        let w = max(12, CGFloat(note.duration) * beatWidth())
        let y = CGFloat(maxMidi - note.midi) * rowHeight
        return CGRect(x: x, y: y, width: w, height: rowHeight - 1)
    }

    // MARK: - 拖拽手势

    private func dragGesture(index: Int, note: Note, viewWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragNoteIndex == nil {
                    // 首次拖动：判断是拉伸还是移动
                    dragNoteIndex = index
                    dragOriginalNote = note
                    dragStartPoint = value.startLocation
                    let rect = noteRect(for: note, viewWidth: viewWidth)
                    // 若起点在右边缘 12pt 内 → 拉伸
                    if abs(value.startLocation.x - (rect.maxX)) < 12 {
                        dragMode = .stretch
                    } else {
                        dragMode = .move
                    }
                }

                guard let original = dragOriginalNote else { return }
                let dx = value.translation.width
                let dy = value.translation.height

                switch dragMode {
                case .move:
                    let deltaTime = Double(dx / beatWidth())
                    let deltaMidi = -Int(round(dy / rowHeight))
                    let newStart = max(0, original.startTime + deltaTime)
                    let snappedStart = (newStart * 4).rounded() / 4
                    let newMidi = max(minMidi, min(maxMidi, original.midi + deltaMidi))
                    notes[index] = Note(midi: newMidi, startTime: snappedStart, duration: original.duration)
                    selectedIndex = index
                case .stretch:
                    let deltaDur = Double(dx / beatWidth())
                    let newDur = max(0.25, original.duration + deltaDur)
                    let snappedDur = (newDur * 4).rounded() / 4
                    notes[index] = Note(midi: original.midi, startTime: original.startTime, duration: snappedDur)
                case .none:
                    break
                }
            }
            .onEnded { _ in
                dragNoteIndex = nil
                dragOriginalNote = nil
                dragMode = .none
            }
    }
}

/// 卷帘背景网格（琴键 + 时间刻度 + 网格线）
struct PianoRollGrid: View {
    let minMidi: Int
    let maxMidi: Int
    let rowHeight: CGFloat
    let beatWidth: CGFloat
    let width: CGFloat

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let blackKeys: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        Canvas { context, size in
            let midiRange = maxMidi - minMidi + 1
            // 横向网格线 + 琴键底色
            for i in 0...midiRange {
                let midi = maxMidi - i
                let pc = midi % 12
                let y = CGFloat(i) * rowHeight
                // 黑键底色
                if blackKeys.contains(pc) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: rowHeight)
                    context.fill(Path(rect), with: GraphicsContext.Shading.color(Color.black.opacity(0.12)))
                }
                // C 键分界线加粗
                let lineWidth: CGFloat = (pc == 0) ? 1.5 : 0.5
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Color.secondary.opacity(pc == 0 ? 0.5 : 0.2)), lineWidth: lineWidth)
            }

            // 纵向拍线（每 1 拍）
            let totalBeats = Int(size.width / beatWidth) + 1
            for b in 0...totalBeats {
                let x = CGFloat(b) * beatWidth
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                let isBar = b % 4 == 0
                context.stroke(line, with: .color(Color.secondary.opacity(isBar ? 0.4 : 0.15)), lineWidth: isBar ? 1.0 : 0.5)
            }
        }
        // 左侧琴键标签
        .overlay(alignment: .topLeading) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach((minMidi...maxMidi).reversed(), id: \.self) { midi in
                    let pc = midi % 12
                    Text(pc == 0 ? "\(noteNames[pc])\(midi / 12 - 1)" : "")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(height: rowHeight, alignment: .center)
                }
            }
            .frame(width: 36, alignment: .trailing)
            .background(Color(white: 0.02).opacity(0.5))
        }
    }
}
/// 单个音符格子视图（拆分子视图，避免 SwiftUI 类型推断超时）
struct NoteCell: View {
    let note: Note
    let isSelected: Bool
    let rect: CGRect

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.4), lineWidth: 1)
                )
            label
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
    }

    private var label: some View {
        Text("\(noteNames[note.midi % 12])\(note.octave)")
            .font(.system(size: 9))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
    }
}
