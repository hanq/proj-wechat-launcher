import SwiftUI
import AppKit

// MARK: - 数据模型

/// 微信安装状态
enum WeChatStatus: Equatable {
    case checking
    case installed
    case notInstalled
}

/// 克隆操作步骤
enum CloneStep: Equatable {
    case idle
    case copying              // 正在复制应用包
    case modifyingPlist       // 正在修改 Bundle Identifier
    case codeSigning          // 正在重新签名
    case completed            // 克隆完成
    case failed(String)       // 克隆失败，附带错误信息

    var displayName: String {
        switch self {
        case .idle:            return "准备就绪"
        case .copying:         return "正在复制微信客户端…"
        case .modifyingPlist:  return "正在修改包名…"
        case .codeSigning:     return "正在重新签名…"
        case .completed:       return "克隆完成 ✓"
        case .failed:          return "克隆失败"
        }
    }
}

/// 已克隆的微信实例
struct ClonedInstance: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let bundleIdentifier: String
    let cloneDate: Date
    let timestamp: String
    var note: String = ""

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: cloneDate)
    }
}

// MARK: - ViewModel

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: 微信状态
    @Published var weChatStatus: WeChatStatus = .checking
    @Published var weChatIcon: NSImage? = nil

    // MARK: 克隆状态
    @Published var isCloning: Bool = false
    @Published var showCloneSheet: Bool = false
    @Published var cloneProgress: Double = 0.0
    @Published var cloneStep: CloneStep = .idle
    @Published var cloneStatusMessage: String = ""

    // MARK: 实例列表
    @Published var clonedInstances: [ClonedInstance] = []
    @Published var isScanningInstances: Bool = false

    // MARK: 错误处理
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showInstallPrompt: Bool = false

    // MARK: - 微信安装检测

    func checkWeChatInstallation() {
        weChatStatus = .checking

        if WeChatDetector.isWeChatInstalled() {
            weChatStatus = .installed
            weChatIcon = WeChatDetector.getWeChatIcon()
            scanClonedInstances()
        } else {
            weChatStatus = .notInstalled
            showInstallPrompt = true
        }
    }

    // MARK: - 启动微信

    func launchWeChat(at path: String = WeChatDetector.weChatDefaultPath) {
        WeChatDetector.launchWeChat(at: path)
    }

    // MARK: - 克隆微信

    func startClone() {
        guard !isCloning else { return }

        isCloning = true
        showCloneSheet = true
        cloneProgress = 0.0
        cloneStep = .idle
        cloneStatusMessage = "准备克隆微信客户端…"

        let timestamp = WeChatCloner.generateTimestamp()
        let clonedAppName = "WeChat_\(timestamp).app"
        let clonedPath = "/Applications/\(clonedAppName)"
        let newBundleID = "com.tencent.wechat_\(timestamp)"

        Task {
            do {
                // Step 1: 复制应用包 (0% → 50%)
                updateCloneProgress(step: .copying, progress: 0.05, message: "正在复制微信客户端到 \(clonedAppName)…")

                try await WeChatCloner.copyWeChatApp(to: clonedPath) { [weak self] progress in
                    Task { @MainActor in
                        self?.updateCloneProgress(
                            step: .copying,
                            progress: 0.05 + progress * 0.45,
                            message: "正在复制微信客户端… (\(Int(progress * 100))%)"
                        )
                    }
                }

                updateCloneProgress(step: .copying, progress: 0.50, message: "复制完成")

                // Step 2: 修改包名 (50% → 75%)
                updateCloneProgress(step: .modifyingPlist, progress: 0.52, message: "正在修改 Bundle Identifier…")

                try await WeChatCloner.modifyBundleIdentifier(at: clonedPath, newIdentifier: newBundleID)

                updateCloneProgress(step: .modifyingPlist, progress: 0.75, message: "包名修改完成: \(newBundleID)")

                // Step 3: 重新签名 (75% → 100%)
                updateCloneProgress(step: .codeSigning, progress: 0.77, message: "正在对副本进行代码签名…")

                try await WeChatCloner.codeSignApp(at: clonedPath)

                updateCloneProgress(step: .codeSigning, progress: 1.0, message: "签名完成")

                // 完成
                cloneStep = .completed
                cloneStatusMessage = "微信副本创建成功！\(clonedAppName)"

                // 等待一小段时间让用户看到完成状态
                try? await Task.sleep(nanoseconds: 1_500_000_000)

                // 刷新实例列表
                scanClonedInstances()

                // 关闭弹窗
                showCloneSheet = false
                isCloning = false
                cloneStep = .idle

            } catch {
                cloneStep = .failed(error.localizedDescription)
                cloneStatusMessage = "克隆失败: \(error.localizedDescription)"
                isCloning = false
            }
        }
    }

    private func updateCloneProgress(step: CloneStep, progress: Double, message: String) {
        cloneStep = step
        cloneProgress = progress
        cloneStatusMessage = message
    }

    // MARK: - 扫描已克隆实例

    func scanClonedInstances() {
        isScanningInstances = true
        var instances = WeChatCloner.scanClonedInstances()

        // 合并备注：timestamp 匹配
        let notes = NotesStore.loadAllNotes()
        for i in instances.indices {
            if let note = notes[instances[i].timestamp] {
                instances[i].note = note
            }
        }

        clonedInstances = instances
        isScanningInstances = false
    }

    // MARK: - 备注管理

    func updateNote(for instance: ClonedInstance, note: String) {
        NotesStore.saveNote(note, for: instance.timestamp)
        if let index = clonedInstances.firstIndex(where: { $0.id == instance.id }) {
            clonedInstances[index].note = note
        }
    }

    // MARK: - 打开微信下载页

    func openWeChatDownloadPage() {
        if let url = URL(string: "https://mac.weixin.qq.com/") {
            NSWorkspace.shared.open(url)
        }
    }
}
