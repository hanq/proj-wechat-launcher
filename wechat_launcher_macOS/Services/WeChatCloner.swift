import AppKit

/// 微信克隆引擎 — 负责复制微信客户端、修改包名、重新签名
struct WeChatCloner {

    /// 自定义克隆错误
    enum CloneError: LocalizedError, @unchecked Sendable {
        case weChatNotInstalled
        case alreadyExists(String)
        case copyFailed(String)
        case plistModificationFailed(String)
        case codeSignFailed(String)
        case scriptError(String)
        case userCancelled
        case invalidPath

        var errorDescription: String? {
            switch self {
            case .weChatNotInstalled:
                return "未找到微信客户端，请先安装微信"
            case .alreadyExists(let name):
                return "实例「\(name)」已存在"
            case .copyFailed(let detail):
                return "复制失败: \(detail)"
            case .plistModificationFailed(let detail):
                return "包名修改失败: \(detail)"
            case .codeSignFailed(let detail):
                return "代码签名失败: \(detail)"
            case .scriptError(let detail):
                return "执行脚本出错: \(detail)"
            case .userCancelled:
                return "用户取消了授权操作"
            case .invalidPath:
                return "无效的应用路径"
            }
        }
    }

    // MARK: - 公开方法

    /// 生成基于当前时间的时间戳
    /// - Returns: 格式为 yyyyMMddHHmmss 的时间戳字符串
    static func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    /// 复制微信客户端到新路径
    /// - Parameters:
    ///   - destinationPath: 目标路径（如 /Applications/WeChat_20260608143022.app）
    ///   - progressHandler: 进度回调（0.0 ~ 1.0，模拟进度）
    static func copyWeChatApp(
        to destinationPath: String,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        let sourcePath = "/Applications/WeChat.app"

        // 前置检查
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw CloneError.weChatNotInstalled
        }

        guard !FileManager.default.fileExists(atPath: destinationPath) else {
            let name = URL(fileURLWithPath: destinationPath).lastPathComponent
            throw CloneError.alreadyExists(name)
        }

        // 构建 AppleScript 执行复制命令
        let command = "cp -R '\(sourcePath)' '\(destinationPath)'"
        let script = """
        do shell script "\(command)" with administrator privileges
        """

        // 启动模拟进度更新
        let progressTask = Task { @MainActor in
            var simulatedProgress: Double = 0.0
            while simulatedProgress < 0.95 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                simulatedProgress = min(simulatedProgress + 0.03, 0.95)
                progressHandler?(simulatedProgress)
            }
        }

        do {
            _ = try await executeAppleScript(script)
            progressTask.cancel()
            progressHandler?(1.0)
        } catch {
            progressTask.cancel()
            throw CloneError.copyFailed(error.localizedDescription)
        }

        // 验证复制结果
        guard FileManager.default.fileExists(atPath: destinationPath) else {
            throw CloneError.copyFailed("目标路径未生成: \(destinationPath)")
        }
    }

    /// 修改应用包的 Bundle Identifier
    /// - Parameters:
    ///   - appPath: 应用路径
    ///   - newIdentifier: 新的 Bundle Identifier
    static func modifyBundleIdentifier(at appPath: String, newIdentifier: String) async throws {
        let plistPath = "\(appPath)/Contents/Info.plist"

        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw CloneError.plistModificationFailed("未找到 Info.plist: \(plistPath)")
        }

        let command = "/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier \(newIdentifier)' '\(plistPath)'"
        let script = """
        do shell script "\(command)" with administrator privileges
        """

        do {
            _ = try await executeAppleScript(script)
        } catch {
            throw CloneError.plistModificationFailed(error.localizedDescription)
        }

        // 验证修改结果
        let verifyProcess = Process()
        verifyProcess.launchPath = "/usr/libexec/PlistBuddy"
        verifyProcess.arguments = ["-c", "Print :CFBundleIdentifier", plistPath]

        let pipe = Pipe()
        verifyProcess.standardOutput = pipe
        do {
            try verifyProcess.run()
            verifyProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if result != newIdentifier {
                throw CloneError.plistModificationFailed("期望: \(newIdentifier), 实际: \(result)")
            }
        } catch {
            throw CloneError.plistModificationFailed(error.localizedDescription)
        }
    }

    /// 对应用包进行 ad-hoc 代码签名
    /// - Parameter appPath: 应用路径
    static func codeSignApp(at appPath: String) async throws {
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw CloneError.codeSignFailed("应用包不存在: \(appPath)")
        }

        let command = "codesign --force --deep --sign - '\(appPath)'"
        let script = """
        do shell script "\(command)" with administrator privileges
        """

        do {
            _ = try await executeAppleScript(script)
        } catch {
            throw CloneError.codeSignFailed(error.localizedDescription)
        }
    }

    /// 一键克隆微信客户端
    /// - Returns: 克隆后的实例信息
    static func cloneWeChat(
        progressHandler: (@Sendable (CloneStep, Double, String) -> Void)?
    ) async throws -> ClonedInstance {
        let timestamp = generateTimestamp()
        let appName = "WeChat_\(timestamp).app"
        let appPath = "/Applications/\(appName)"
        let bundleID = "com.tencent.wechat_\(timestamp)"

        // Step 1: 复制
        progressHandler?(.copying, 0.0, "正在复制微信客户端…")
        try await copyWeChatApp(to: appPath) { fileProgress in
            progressHandler?(.copying, fileProgress * 0.5, "复制中: \(Int(fileProgress * 100))%")
        }
        progressHandler?(.copying, 0.5, "复制完成")

        // Step 2: 修改包名
        progressHandler?(.modifyingPlist, 0.5, "正在修改 Bundle Identifier…")
        try await modifyBundleIdentifier(at: appPath, newIdentifier: bundleID)
        progressHandler?(.modifyingPlist, 0.75, "包名修改完成")

        // Step 3: 签名
        progressHandler?(.codeSigning, 0.75, "正在重新签名…")
        try await codeSignApp(at: appPath)
        progressHandler?(.codeSigning, 1.0, "签名完成")

        let instance = ClonedInstance(
            path: appPath,
            name: appName,
            bundleIdentifier: bundleID,
            cloneDate: Date(),
            timestamp: timestamp
        )

        return instance
    }

    /// 扫描 /Applications 目录下所有已克隆的微信实例
    /// - Returns: 克隆实例列表
    static func scanClonedInstances() -> [ClonedInstance] {
        let applicationsPath = "/Applications"
        var instances: [ClonedInstance] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: applicationsPath) else {
            return instances
        }

        // 匹配 WeChat_<timestamp>.app 模式
        let pattern = try? NSRegularExpression(pattern: "^WeChat_(\\d{14})\\.app$")

        for item in contents {
            let fullPath = "\(applicationsPath)/\(item)"
            let nsItem = item as NSString

            guard let match = pattern?.firstMatch(in: item, range: NSRange(location: 0, length: item.count)) else {
                continue
            }

            // 验证是有效的应用包
            guard WeChatDetector.isValidAppBundle(at: fullPath) else { continue }

            // 提取时间戳
            let timestampRange = match.range(at: 1)
            let timestamp = nsItem.substring(with: timestampRange)

            // 读取 Bundle ID
            let plistPath = "\(fullPath)/Contents/Info.plist"
            var bundleID = "com.tencent.wechat_\(timestamp)"
            if let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
               let cfBundleID = plist["CFBundleIdentifier"] as? String {
                bundleID = cfBundleID
            }

            // 获取修改日期作为克隆时间
            let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let cloneDate = attributes?[.modificationDate] as? Date ?? Date()

            let instance = ClonedInstance(
                path: fullPath,
                name: item,
                bundleIdentifier: bundleID,
                cloneDate: cloneDate,
                timestamp: timestamp
            )

            instances.append(instance)
        }

        // 按克隆时间倒序排列
        return instances.sorted { $0.cloneDate > $1.cloneDate }
    }

    // MARK: - 内部方法

    /// 通过 AppleScript 执行需要管理员权限的命令
    /// - Parameter script: AppleScript 脚本字符串
    /// - Returns: 脚本执行输出
    private static func executeAppleScript(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?

                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "未知错误"

                    // -128 表示用户取消了授权对话框
                    if errorNumber == -128 {
                        continuation.resume(throwing: CloneError.userCancelled)
                    } else {
                        continuation.resume(throwing: CloneError.scriptError("[\(errorNumber)] \(errorMessage)"))
                    }
                    return
                }

                let output = result?.stringValue ?? ""
                continuation.resume(returning: output)
            }
        }
    }
}
