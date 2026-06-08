import SwiftUI

/// 微信启动器 macOS 应用入口
@main
struct WeChatLauncherApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 480, minHeight: 540)
                .onAppear {
                    viewModel.checkWeChatInstallation()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 500, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
