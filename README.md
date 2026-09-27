# 哼曲 HumTune v2.0 — 使用说明

> 重生版：结合 2026-09-26 音乐知识库深度学习成果，从"工程师 MIDI 工具"升级为"谁都哼得动的创作入口"。

---

## 一、这是什么

哼一句旋律 → 自动转谱（简谱 + 五线谱）→ 导出 MIDI/MusicXML/简谱文本。

**核心差异化**：哼歌搜歌（SoundHound/Google）不出谱，音频转 MIDI（Basic Pitch）出 MIDI 不出易读谱——HumTune 补上"哼唱 → 简谱 + 五线谱 + 可编辑 MIDI 三合一"这个空白。

---

## 二、怎么用

1. 双击 `HumTune.app` 打开
2. 系统弹窗授权**麦克风**（必需，否则录不到声音）
3. 点中间**大红圆键**开始哼唱，再点一下停止
4. 录完自动出谱（默认**简谱**，123 秒懂）
5. **点「▶ 播放」听转出来的旋律**，验证跟你设计的接近不接近
6. 切到「音符编辑」tab，逐音**试听 + 微调音高/时值/删除**
7. 顶部 ⚙️ 或底部「导出」菜单：**导出 MIDI / MusicXML / 音频 WAV / 简谱文本**

## 二点五、播放与保存（本次新增）

- **播放**：转谱结果可直接试听，四种音色可选（正弦/三角/方波/锯齿）
- **逐音微调**：音符编辑页里每个音可独立 +/− 半音、+/− 时值、删除、单音试听
- **保存**：支持导出 **WAV 音频**（16bit/44.1kHz，直接可播可发）＋ MIDI ＋ MusicXML ＋ 简谱文本
- **对比验证**：录完先播放，听转换后的旋律是否接近原哼唱，再进音符编辑微调偏差的音

---

## 三、v2.0 相比旧版提升

| 维度 | v1（已删除） | v2.0 |
|------|-------------|------|
| 打开看到 | MIDI 卷帘（要懂才懂） | 大录音键 + 波形（谁都会点） |
| 哼完发生 | 出 MIDI，可能空白 | 自动出简谱 + 五线谱 |
| 不懂乐理 | ❌ 拿到 MIDI 傻眼 | ✅ 简谱秒懂 + 调性自动识别 |
| 识别准确 | YIN 单一阈值，真哼歌被判静音 | VAD 组合 + 八度消歧 + 颤音平滑 |
| 乐谱精准 | 无量化/无调性 | BPM 量化 + 调性识别 + 音名拼写 |
| 能带走 | 只有 MIDI | 简谱/五线谱/MIDI/MusicXML |

---

## 四、技术栈

- **语言**：Swift 6.4 / SwiftUI（macOS 14+）
- **音高检测**：YIN（经典算法）+ 中值平滑 + 八度消歧
- **音符切分**：组合 VAD（置信度 OR 能量）
- **量化**：BPM 自相关估计 + 可调量化强度
- **调性**：Krumhansl-Schmuckler 24 调模板
- **输出**：SMF MIDI / MusicXML / 简谱文本

---

## 五、二次开发

```bash
cd ~/Desktop/HumTune
swift build              # 编译
swift run HumTuneCli     # 跑核心引擎验证器（12 项测试）
./make_app.sh            # 重新打包 .app
./make_dmg.sh            # 重新打包 DMG
```

**工程结构**：
```
Sources/
├── HumTuneCore/    # 核心引擎（无 UI 依赖）
│   ├── Models.swift          # 数据模型
│   ├── PitchEngine.swift     # YIN 音高检测
│   ├── NoteSegmenter.swift   # 音符切分
│   ├── Quantizer.swift       # 节奏量化
│   ├── KeyEstimator.swift    # 调性+音名拼写
│   ├── MIDIWriter.swift      # MIDI 写出
│   ├── MusicXMLExporter.swift# MusicXML 导出
│   └── Transcriber.swift     # 流水线协调 + 简谱
├── HumTuneCli/      # 命令行验证器
└── HumTuneApp/      # SwiftUI 界面
```

---

## 六、已知待办（阶段二）

- 智能编曲补全（自动配和声/鼓/贝斯）——差异化杀招
- 五线谱真实排版渲染（当前简化版，MusicXML 交给 MuseScore 精排）
- 音频导出（wav/m4a）
- 谱图 PNG 导出
- sf2 音色库导入
- 分发需 Developer ID 证书（当前 ad-hoc 签名仅本机可跑）

---

## 七、知识库来源

本工具基于 `~/Documents/knowledge/admin/music-production/` 音乐知识库开发（10 文件，含 6+3 专题深度学习成果）。