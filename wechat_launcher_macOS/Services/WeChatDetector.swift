import AppKit

/// 微信客户端检测服务
struct WeChatDetector {

    /// 微信默认安装路径
    static let weChatDefaultPath = "/Applications/WeChat.app"

    /// 检查微信是否已安装
    /// - Returns: true 表示已安装
    static func isWeChatInstalled() -> Bool {
        let exists = FileManager.default.fileExists(atPath: weChatDefaultPath)
        guard exists else { return false }

        // 进一步验证 Info.plist 存在，确保是有效的应用包
        let infoPlistPath = "\(weChatDefaultPath)/Contents/Info.plist"
        let isValidBundle = FileManager.default.fileExists(atPath: infoPlistPath)
        return isValidBundle
    }

    /// 获取微信应用图标
    /// - Returns: NSImage 图标，若无法获取返回 nil
    static func getWeChatIcon() -> NSImage? {
        return NSWorkspace.shared.icon(forFile: weChatDefaultPath)
    }

    /// 启动微信客户端
    /// - Parameter path: 微信应用路径，默认为 /Applications/WeChat.app
    static func launchWeChat(at path: String = weChatDefaultPath) {
        let process = Process()
        process.launchPath = "/usr/bin/open"
        // -n 参数：以新实例启动应用（即使已有实例在运行）
        process.arguments = ["-n", "-a", path]
        do {
            try process.run()
        } catch {
            // 降级：尝试通过 NSWorkspace 启动
            let url = URL(fileURLWithPath: path)
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error = error {
                    print("启动微信失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 检查指定路径的应用是否有效
    /// - Parameter path: 应用路径
    /// - Returns: 是否有效
    static func isValidAppBundle(at path: String) -> Bool {
        let infoPlistPath = "\(path)/Contents/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPlistPath) else {
            return false
        }
        return path.hasSuffix(".app")
    }
}
