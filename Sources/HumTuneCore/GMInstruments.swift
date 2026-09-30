import Foundation

/// GM 乐器（单个音色定义）
public struct GMInstrument: Identifiable, Equatable {
    /// GM Program 号 0~127
    public let program: Int
    /// 英文名
    public let name: String
    /// 中文名
    public let zhName: String
    public var id: Int { program }

    public init(program: Int, name: String, zhName: String) {
        self.program = program
        self.name = name
        self.zhName = zhName
    }
}

/// GM 标准 128 音色表（General MIDI Level 1）
/// 用于「换乐器」选择界面与 MIDI Program Change 导出
public enum GMInstruments {

    public static let all: [GMInstrument] = [
        // 0-7 钢琴类
        GMInstrument(program: 0,  name: "Acoustic Grand Piano",   zhName: "大钢琴"),
        GMInstrument(program: 1,  name: "Bright Acoustic Piano",  zhName: "明亮的钢琴"),
        GMInstrument(program: 2,  name: "Electric Grand Piano",   zhName: "电大钢琴"),
        GMInstrument(program: 3,  name: "Honky-tonk Piano",       zhName: "酒吧钢琴"),
        GMInstrument(program: 4,  name: "Electric Piano 1",       zhName: "电钢琴1"),
        GMInstrument(program: 5,  name: "Electric Piano 2",       zhName: "电钢琴2"),
        GMInstrument(program: 6,  name: "Harpsichord",            zhName: "拨弦古钢琴"),
        GMInstrument(program: 7,  name: "Clavinet",               zhName: "击弦古钢琴"),
        // 8-15 色彩打击乐
        GMInstrument(program: 8,  name: "Celesta",                zhName: "钢片琴"),
        GMInstrument(program: 9,  name: "Glockenspiel",           zhName: "钟琴"),
        GMInstrument(program: 10, name: "Music Box",              zhName: "八音盒"),
        GMInstrument(program: 11, name: "Vibraphone",             zhName: "颤音琴"),
        GMInstrument(program: 12, name: "Marimba",                zhName: "马林巴"),
        GMInstrument(program: 13, name: "Xylophone",              zhName: "木琴"),
        GMInstrument(program: 14, name: "Tubular Bells",          zhName: "管钟"),
        GMInstrument(program: 15, name: "Dulcimer",               zhName: "扬琴"),
        // 16-23 风琴
        GMInstrument(program: 16, name: "Drawbar Organ",          zhName: "拉杆风琴"),
        GMInstrument(program: 17, name: "Percussive Organ",       zhName: "打击风琴"),
        GMInstrument(program: 18, name: "Rock Organ",             zhName: "摇滚风琴"),
        GMInstrument(program: 19, name: "Church Organ",           zhName: "教堂风琴"),
        GMInstrument(program: 20, name: "Reed Organ",             zhName: "簧风琴"),
        GMInstrument(program: 21, name: "Accordion",              zhName: "手风琴"),
        GMInstrument(program: 22, name: "Harmonica",              zhName: "口琴"),
        GMInstrument(program: 23, name: "Tango Accordion",        zhName: "探戈手风琴"),
        // 24-31 吉他
        GMInstrument(program: 24, name: "Acoustic Guitar (nylon)",  zhName: "尼龙弦吉他"),
        GMInstrument(program: 25, name: "Acoustic Guitar (steel)",  zhName: "钢弦吉他"),
        GMInstrument(program: 26, name: "Electric Guitar (jazz)",   zhName: "电吉他(爵士)"),
        GMInstrument(program: 27, name: "Electric Guitar (clean)",  zhName: "电吉他(清音)"),
        GMInstrument(program: 28, name: "Electric Guitar (muted)",  zhName: "电吉他(闷音)"),
        GMInstrument(program: 29, name: "Overdriven Guitar",        zhName: "过载吉他"),
        GMInstrument(program: 30, name: "Distortion Guitar",        zhName: "失真吉他"),
        GMInstrument(program: 31, name: "Guitar Harmonics",         zhName: "吉他泛音"),
        // 32-39 贝斯
        GMInstrument(program: 32, name: "Acoustic Bass",          zhName: "原声贝斯"),
        GMInstrument(program: 33, name: "Electric Bass (finger)", zhName: "指弹电贝斯"),
        GMInstrument(program: 34, name: "Electric Bass (pick)",   zhName: "拨片电贝斯"),
        GMInstrument(program: 35, name: "Fretless Bass",          zhName: "无品贝斯"),
        GMInstrument(program: 36, name: "Slap Bass 1",            zhName: "击弦贝斯1"),
        GMInstrument(program: 37, name: "Slap Bass 2",            zhName: "击弦贝斯2"),
        GMInstrument(program: 38, name: "Synth Bass 1",           zhName: "合成贝斯1"),
        GMInstrument(program: 39, name: "Synth Bass 2",           zhName: "合成贝斯2"),
        // 40-47 弦乐
        GMInstrument(program: 40, name: "Violin",                 zhName: "小提琴"),
        GMInstrument(program: 41, name: "Viola",                  zhName: "中提琴"),
        GMInstrument(program: 42, name: "Cello",                  zhName: "大提琴"),
        GMInstrument(program: 43, name: "Contrabass",             zhName: "低音提琴"),
        GMInstrument(program: 44, name: "Tremolo Strings",        zhName: "颤音弦乐"),
        GMInstrument(program: 45, name: "Pizzicato Strings",      zhName: "拨弦弦乐"),
        GMInstrument(program: 46, name: "Orchestral Harp",        zhName: "竖琴"),
        GMInstrument(program: 47, name: "Timpani",                zhName: "定音鼓"),
        // 48-55 合奏/人声
        GMInstrument(program: 48, name: "String Ensemble 1",      zhName: "弦乐合奏1"),
        GMInstrument(program: 49, name: "String Ensemble 2",      zhName: "弦乐合奏2"),
        GMInstrument(program: 50, name: "Synth Strings 1",        zhName: "合成弦乐1"),
        GMInstrument(program: 51, name: "Synth Strings 2",        zhName: "合成弦乐2"),
        GMInstrument(program: 52, name: "Choir Aahs",             zhName: "合唱啊"),
        GMInstrument(program: 53, name: "Voice Oohs",             zhName: "人声呜"),
        GMInstrument(program: 54, name: "Synth Voice",            zhName: "合成人声"),
        GMInstrument(program: 55, name: "Orchestra Hit",          zhName: "管弦乐重击"),
        // 56-63 铜管
        GMInstrument(program: 56, name: "Trumpet",                zhName: "小号"),
        GMInstrument(program: 57, name: "Trombone",               zhName: "长号"),
        GMInstrument(program: 58, name: "Tuba",                   zhName: "大号"),
        GMInstrument(program: 59, name: "Muted Trumpet",          zhName: "闷音小号"),
        GMInstrument(program: 60, name: "French Horn",            zhName: "法国号"),
        GMInstrument(program: 61, name: "Brass Section",          zhName: "铜管组"),
        GMInstrument(program: 62, name: "Synth Brass 1",          zhName: "合成铜管1"),
        GMInstrument(program: 63, name: "Synth Brass 2",          zhName: "合成铜管2"),
        // 64-71 簧片
        GMInstrument(program: 64, name: "Soprano Sax",            zhName: "高音萨克斯"),
        GMInstrument(program: 65, name: "Alto Sax",               zhName: "中音萨克斯"),
        GMInstrument(program: 66, name: "Tenor Sax",              zhName: "次中音萨克斯"),
        GMInstrument(program: 67, name: "Baritone Sax",           zhName: "上低音萨克斯"),
        GMInstrument(program: 68, name: "Oboe",                   zhName: "双簧管"),
        GMInstrument(program: 69, name: "English Horn",           zhName: "英国管"),
        GMInstrument(program: 70, name: "Bassoon",                zhName: "巴松管"),
        GMInstrument(program: 71, name: "Clarinet",               zhName: "单簧管"),
        // 72-79 管乐
        GMInstrument(program: 72, name: "Piccolo",                zhName: "短笛"),
        GMInstrument(program: 73, name: "Flute",                  zhName: "长笛"),
        GMInstrument(program: 74, name: "Recorder",               zhName: "竖笛"),
        GMInstrument(program: 75, name: "Pan Flute",              zhName: "排箫"),
        GMInstrument(program: 76, name: "Blown Bottle",           zhName: "吹瓶"),
        GMInstrument(program: 77, name: "Shakuhachi",             zhName: "尺八"),
        GMInstrument(program: 78, name: "Whistle",                zhName: "口哨"),
        GMInstrument(program: 79, name: "Ocarina",                zhName: "陶笛"),
        // 80-87 合成主音
        GMInstrument(program: 80, name: "Lead 1 (square)",        zhName: "主音1(方波)"),
        GMInstrument(program: 81, name: "Lead 2 (sawtooth)",      zhName: "主音2(锯齿)"),
        GMInstrument(program: 82, name: "Lead 3 (calliope)",      zhName: "主音3(汽笛风琴)"),
        GMInstrument(program: 83, name: "Lead 4 (chiff)",         zhName: "主音4(气声)"),
        GMInstrument(program: 84, name: "Lead 5 (charang)",       zhName: "主音5(恰朗)"),
        GMInstrument(program: 85, name: "Lead 6 (voice)",         zhName: "主音6(人声)"),
        GMInstrument(program: 86, name: "Lead 7 (fifths)",        zhName: "主音7(五度)"),
        GMInstrument(program: 87, name: "Lead 8 (bass+lead)",     zhName: "主音8(贝斯+主音)"),
        // 88-95 合成铺底
        GMInstrument(program: 88, name: "Pad 1 (new age)",        zhName: "铺底1(新世纪)"),
        GMInstrument(program: 89, name: "Pad 2 (warm)",           zhName: "铺底2(温暖)"),
        GMInstrument(program: 90, name: "Pad 3 (polysynth)",      zhName: "铺底3(复音合成)"),
        GMInstrument(program: 91, name: "Pad 4 (choir)",          zhName: "铺底4(合唱)"),
        GMInstrument(program: 92, name: "Pad 5 (bowed)",          zhName: "铺底5(弓弦)"),
        GMInstrument(program: 93, name: "Pad 6 (metallic)",       zhName: "铺底6(金属)"),
        GMInstrument(program: 94, name: "Pad 7 (halo)",           zhName: "铺底7(光环)"),
        GMInstrument(program: 95, name: "Pad 8 (sweep)",          zhName: "铺底8(扫频)"),
        // 96-103 合成效果
        GMInstrument(program: 96,  name: "FX 1 (rain)",            zhName: "效果1(雨)"),
        GMInstrument(program: 97,  name: "FX 2 (soundtrack)",      zhName: "效果2(音轨)"),
        GMInstrument(program: 98,  name: "FX 3 (crystal)",         zhName: "效果3(水晶)"),
        GMInstrument(program: 99,  name: "FX 4 (atmosphere)",      zhName: "效果4(大气)"),
        GMInstrument(program: 100, name: "FX 5 (brightness)",      zhName: "效果5(明亮)"),
        GMInstrument(program: 101, name: "FX 6 (goblins)",         zhName: "效果6(小妖)"),
        GMInstrument(program: 102, name: "FX 7 (echoes)",          zhName: "效果7(回声)"),
        GMInstrument(program: 103, name: "FX 8 (sci-fi)",          zhName: "效果8(科幻)"),
        // 104-111 民族
        GMInstrument(program: 104, name: "Sitar",                  zhName: "西塔琴"),
        GMInstrument(program: 105, name: "Banjo",                  zhName: "班卓琴"),
        GMInstrument(program: 106, name: "Shamisen",               zhName: "三味线"),
        GMInstrument(program: 107, name: "Koto",                   zhName: "日本筝"),
        GMInstrument(program: 108, name: "Kalimba",                zhName: "卡林巴"),
        GMInstrument(program: 109, name: "Bagpipe",                zhName: "风笛"),
        GMInstrument(program: 110, name: "Fiddle",                 zhName: "小提琴(民间)"),
        GMInstrument(program: 111, name: "Shanai",                 zhName: "唢呐"),
        // 112-119 打击乐
        GMInstrument(program: 112, name: "Tinkle Bell",            zhName: "叮当铃"),
        GMInstrument(program: 113, name: "Agogo",                  zhName: "阿哥哥铃"),
        GMInstrument(program: 114, name: "Steel Drums",            zhName: "钢鼓"),
        GMInstrument(program: 115, name: "Woodblock",              zhName: "木鱼"),
        GMInstrument(program: 116, name: "Taiko Drum",             zhName: "太鼓"),
        GMInstrument(program: 117, name: "Melodic Tom",            zhName: "旋律鼓"),
        GMInstrument(program: 118, name: "Synth Drum",             zhName: "合成鼓"),
        GMInstrument(program: 119, name: "Reverse Cymbal",         zhName: "反镲"),
        // 120-127 音效
        GMInstrument(program: 120, name: "Guitar Fret Noise",      zhName: "吉他品噪声"),
        GMInstrument(program: 121, name: "Breath Noise",           zhName: "呼吸噪声"),
        GMInstrument(program: 122, name: "Seashore",               zhName: "海浪"),
        GMInstrument(program: 123, name: "Bird Tweet",             zhName: "鸟鸣"),
        GMInstrument(program: 124, name: "Telephone Ring",         zhName: "电话铃"),
        GMInstrument(program: 125, name: "Helicopter",             zhName: "直升机"),
        GMInstrument(program: 126, name: "Applause",               zhName: "掌声"),
        GMInstrument(program: 127, name: "Gunshot",                zhName: "枪声")
    ]

    /// 常用乐器快捷列表（放选择器顶部）
    public static let favorites: [GMInstrument] = [
        all[0],   // 大钢琴
        all[4],   // 电钢琴1
        all[24],  // 尼龙弦吉他
        all[25],  // 钢弦吉他
        all[40],  // 小提琴
        all[42],  // 大提琴
        all[73],  // 长笛
        all[68],  // 双簧管
        all[71],  // 单簧管
        all[64],  // 高音萨克斯
        all[56],  // 小号
        all[60],  // 法国号
        all[32],  // 原声贝斯
        all[48],  // 弦乐合奏1
        all[52],  // 合唱
        all[46]   // 竖琴
    ]

    public static func byProgram(_ program: Int) -> GMInstrument {
        let p = max(0, min(127, program))
        return all[p]
    }

    public static func name(program: Int) -> String {
        return byProgram(program).zhName
    }
}