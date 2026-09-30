import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers

/// 参照音频播放器：导入 MP3/m4a/wav 等外部音乐文件，用于与自己的旋律 A/B 比对
@MainActor
final class ReferencePlayer: ObservableObject {

    @Published var isPlaying = false
    @Published var fileName: String? = nil
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String? = nil

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    /// 加载音频文件
    func load(url: URL) {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            self.player = player
            self.fileName = url.lastPathComponent
            self.duration = player.duration
            self.currentTime = 0
            self.errorMessage = nil
        } catch {
            self.errorMessage = "无法打开该音频文件：\(error.localizedDescription)"
            print("⚠️ 参照音频加载失败：\(error)")
        }
    }

    /// 弹出文件选择器并加载
    func importAndLoad() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .audio, .aiff]
        panel.allowsMultipleSelection = false
        panel.message = "选择要对比参照的音乐文件（MP3 / M4A / WAV）"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.load(url: url)
            }
        }
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    /// 跳转到指定位置（秒）
    func seek(to seconds: Double) {
        guard let player = player else { return }
        player.currentTime = max(0, min(player.duration, seconds))
        currentTime = player.currentTime
    }

    private func startTimer() {
        stopTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let p = self.player else { return }
                self.currentTime = p.currentTime
                if !p.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}