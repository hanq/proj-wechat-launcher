import SwiftUI

/// 主界面
struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.weChatStatus {
            case .checking:
                checkingView
            case .installed:
                mainView
            case .notInstalled:
                notInstalledView
            }
        }
        .frame(minWidth: 480, minHeight: 540)
        .sheet(isPresented: $viewModel.showCloneSheet) {
            CloneProgressView()
                .environmentObject(viewModel)
        }
        .alert("未安装微信", isPresented: $viewModel.showInstallPrompt) {
            Button("前往下载") {
                viewModel.openWeChatDownloadPage()
            }
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            Button("重新检查", role: .cancel) {
                viewModel.checkWeChatInstallation()
            }
        } message: {
            Text("未检测到微信客户端，请先安装微信后再使用本工具。")
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - 检测中

    private var checkingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 10)

            Text("正在检测微信客户端…")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 未安装

    private var notInstalledView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.yellow)

            Text("未检测到微信客户端")
                .font(.title2)
                .fontWeight(.semibold)

            Text("请先安装微信后再使用本工具")
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("前往下载") {
                    viewModel.openWeChatDownloadPage()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("重新检查") {
                    viewModel.checkWeChatInstallation()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 主界面（微信已安装）

    private var mainView: some View {
        VStack(spacing: 0) {
            // 顶部：微信启动区域
            weChatLaunchSection
                .padding(.top, 30)

            Divider()
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

            // 底部：已克隆实例列表
            instanceListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 微信启动区域

    private var weChatLaunchSection: some View {
        VStack(spacing: 20) {
            Text("微信启动器")
                .font(.title)
                .fontWeight(.bold)

            // 微信图标
            WeChatIconView(icon: viewModel.weChatIcon, isEnabled: !viewModel.isCloning)
                .onTapGesture(count: 2) {
                    viewModel.launchWeChat()
                }

            // 提示文案
            Text("双击图标启动微信")
                .font(.caption)
                .foregroundColor(.secondary)

            // 操作按钮组
            HStack(spacing: 12) {
                Button("打开微信") {
                    viewModel.launchWeChat()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    viewModel.startClone()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("创建微信副本")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(viewModel.isCloning)
            }
        }
    }

    // MARK: - 实例列表区域

    private var instanceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已克隆的微信实例")
                    .font(.headline)

                Spacer()

                if viewModel.isScanningInstances {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }

                Button {
                    viewModel.scanClonedInstances()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("刷新实例列表")
            }
            .padding(.horizontal, 24)

            if viewModel.clonedInstances.isEmpty {
                emptyInstanceView
            } else {
                InstanceListView(
                    instances: viewModel.clonedInstances,
                    onLaunch: { instance in
                        viewModel.launchWeChat(at: instance.path)
                    },
                    onUpdateNote: { instance, note in
                        viewModel.updateNote(for: instance, note: note)
                    }
                )
            }
        }
        .padding(.bottom, 20)
    }

    private var emptyInstanceView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("暂无克隆实例")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("点击上方「创建微信副本」按钮开始")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
