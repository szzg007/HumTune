# 哼曲 HumTune —— 哼歌就能出谱的 Mac 音乐创作软件

> 为「有音乐细胞、没有乐理知识」的小白做的桌面软件：哼歌 → 自动转五线谱/MIDI → 换乐器演奏 → 导出素材喂 AI。

## 一、快速上手（无需编译，直接运行）

打开 `HumTune-0.1.0.dmg`，把 `HumTune` 拖进 Applications，双击即可。

第一次会弹「麦克风授权」，点「好」，然后：

1. 点 **🔴 开始哼歌**，哼出你的旋律
2. 点 **⏹ 停止**，右侧自动显示五线谱/钢琴卷帘
3. 换乐器、升降调、快慢变速
4. 导出 MIDI / AI 素材包 JSON

## 二、核心能力

| 功能 | 说明 |
|------|------|
| 🎤 哼歌采集 | 实时录音 + 波形 + 实时音高显示 |
| 🎵 旋律转谱 | YIN 算法提取音高（精度 0.3 音分）+ 保节奏切分 |
| 🎼 五线谱 / 卷帘 | 自动渲染，可切换查看 |
| 🎷 换乐器 | 系统 GM 128 音色（钢琴/吉他/小提琴/长笛…） |
| 🎚 变换 | 升降调（±半音）、快慢变速（不变调） |
| 💾 导出 | MIDI 文件 + AI 素材包 JSON（喂大模型生成音乐） |

## 三、技术栈

- **纯 Swift + SwiftUI 原生**（无 Python/跨语言依赖，装机即用）
- 音高提取：自研 YIN 算法（`PitchEngine.swift`）
- 音符切分：onset 检测 + 音高轨迹稳定段（`NoteSegmenter.swift`）
- MIDI 写入：自写标准 SMF 格式（`MIDIWriter.swift`）
- 播放合成：AVAudioUnitSampler + 系统 GM 音色库（`SynthEngine.swift`）
- 五线谱/卷帘：CoreGraphics/SwiftUI 自绘（`ScoreView.swift`）

## 四、二次开发

### 环境要求
- macOS 14+
- Xcode 27（或更高，CommandLineTools 需切换到完整 Xcode）
- 无需任何第三方依赖

### 构建
```bash
# 确保 xcode-select 指向 Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 构建可运行 App
./build.sh          # 产出 build/HumTune.app

# 打 DMG 安装包
./make_dmg.sh       # 产出 build/HumTune-0.1.0.dmg

# 跑核心引擎单元测试
swift test

# 命令行验证核心引擎（无需 GUI）
swift run HumTuneCli           # 音高/MIDI/AI素材包验证
swift run HumTuneCli synth     # GM 音色引擎验证
```

### 目录结构
```
HumTune/
├── Package.swift              # SwiftPM 包定义
├── build.sh                   # 打包 .app 脚本
├── make_dmg.sh                # 打 DMG 脚本
├── Info.plist                 # 麦克风权限声明
├── Sources/
│   ├── HumTuneCore/           # 核心引擎（纯逻辑，可单测）
│   │   ├── PitchEngine.swift  # YIN 音高提取
│   │   ├── NoteSegmenter.swift# 音符切分 + BPM
│   │   ├── MIDIWriter.swift   # MIDI 写入 + AI 素材包
│   │   ├── SynthEngine.swift  # GM 音色合成
│   │   └── Models.swift       # 数据模型 + 音高换算
│   ├── HumTuneApp/            # GUI 界面
│   │   ├── HumTuneApp.swift   # 入口
│   │   ├── ContentView.swift  # 主界面
│   │   ├── RecordingEngine.swift # 录音引擎
│   │   └── ScoreView.swift    # 五线谱/卷帘视图
│   └── HumTuneCli/            # 命令行验证器
└── Tests/                     # 单元测试
```

## 五、版本

- **v0.1.0**（2026-09-26）：MVP 核心闭环（录音→转谱→换乐器→导出）
- 待办：播放光标跟随、音频导出、谱图导出、外部 sf2 导入、正式签名

## 六、许可

产品代号暂定「哼曲 HumTune」。本地 ad-hoc 签名可自由运行；对外分发需 Apple Developer 签名。