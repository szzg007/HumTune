import Foundation

/// MusicXML 导出器（新增模块）
/// 生成 part-wise MusicXML，交给 MuseScore/Sibelius 等专业排版引擎渲染
public struct MusicXMLExporter {

    public init() {}

    /// 导出 MusicXML 字符串
    public func export(
        notes: [Note],
        timeSignature: TimeSignature = TimeSignature(),
        key: KeySignature? = nil,
        bpm: Double = 120
    ) -> String {
        // divisions：每四分音符细分为 4（即 1 个 divisions unit = 十六分音符）
        let divisions = 4

        // 确定调号的 fifths 与显示
        let fifths = key?.fifths ?? 0

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <part-list>
            <score-part id="P1">
              <part-name>Melody</part-name>
            </score-part>
          </part-list>
          <part id="P1">

        """

        // 计算拍长（秒）
        let beatDuration = 60.0 / bpm
        // 每 divisions unit 秒数
        let unitDuration = beatDuration / Double(divisions)

        // 音符排序
        let sorted = notes.sorted { $0.startTime < $1.startTime }

        // 简单分节：按时间累加，超出 measure 时长就换小节
        var measures: [[Note]] = []
        var currentMeasure: [Note] = []

        // 用固定小节的时长（拍号 × 拍长）
        let measureDuration = Double(timeSignature.numerator) * beatDuration

        for note in sorted {
            // 判断 note 是否跨小节（暂简化：一个音符不跨小节）
            // 如果当前小节已满，换新小节
            if !currentMeasure.isEmpty {
                let measureStart = currentMeasure.first!.startTime
                if note.startTime - measureStart >= measureDuration {
                    measures.append(currentMeasure)
                    currentMeasure = [note]
                    continue
                }
            }
            currentMeasure.append(note)
        }
        if !currentMeasure.isEmpty {
            measures.append(currentMeasure)
        }

        // 逐小节写 XML
        for (mi, measure) in measures.enumerated() {
            let measureNumber = mi + 1

            xml += """
              <measure number="\(measureNumber)">

            """

            // 首小节写 attributes（调号/拍号/divisions）
            if mi == 0 {
                xml += """
                    <attributes>
                      <divisions>\(divisions)</divisions>
                      <key>
                        <fifths>\(fifths)</fifths>
                      </key>
                      <time>
                        <beats>\(timeSignature.numerator)</beats>
                        <beat-type>\(timeSignature.denominator)</beat-type>
                      </time>
                      <clef>
                        <sign>G</sign>
                        <line>2</line>
                      </clef>
                    </attributes>

                """
            }

            // 写音符
            for note in measure {
                let speller = NoteSpeller()
                let spelling = speller.spell(midi: note.midi, key: key)
                // duration 以 divisions unit 计
                let durUnits = max(1, Int(round(note.duration / unitDuration)))
                // 记谱时值类型（粗略映射）
                let noteType = Self.noteTypeForDivisions(durUnits, divisions: divisions)

                xml += """
                      <note>
                        <pitch>
                          <step>\(spelling.step)</step>
                  """

                if spelling.alter != 0 {
                    xml += """
                          <alter>\(spelling.alter)</alter>
                    """
                }
                xml += """
                          <octave>\(spelling.octave)</octave>
                        </pitch>
                        <duration>\(durUnits)</duration>
                        <voice>1</voice>
                        <type>\(noteType)</type>
                      </note>

                """
            }

            xml += """
              </measure>

            """
        }

        xml += """
          </part>
        </score-partwise>
        """

        return xml
    }

    /// 由 divisions unit 数映射到记谱时值类型
    static func noteTypeForDivisions(_ units: Int, divisions: Int) -> String {
        // 全音符 = 4*divisions unit
        let ratio = Double(units) / Double(divisions)
        switch ratio {
        case ..<0.375: return "sixteenth"
        case ..<0.75: return "eighth"
        case ..<1.5: return "quarter"
        case ..<3.0: return "half"
        default: return "whole"
        }
    }
}