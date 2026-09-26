// HumTune 主入口
import SwiftUI

@main
struct HumTuneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}