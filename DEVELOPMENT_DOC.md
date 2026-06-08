# WeChat Launcher macOS — 开发文档

## 1. 项目概述

### 1.1 项目名称
**wechat_launcher_macOS** — 微信多开启动器 (macOS)

### 1.2 项目定位
面向 macOS 用户的微信客户端管理工具，提供微信快速启动与一键多开（应用复制）功能，解决 macOS 上同时登录多个微信账号的痛点。

### 1.3 目标平台
- **操作系统**：macOS 14.0 (Sonoma) 及以上
- **开发语言**：Swift 5.9+
- **UI 框架**：SwiftUI + AppKit 混合
- **构建工具**：Xcode 16+

---

## 2. 功能需求

### 2.1 功能清单

| 编号 | 功能模块 | 功能描述 | 优先级 |
|------|----------|----------|--------|
| F01 | 微信检测 | 启动时自动检测 `/Applications/WeChat.app` 是否存在 | P0 |
| F02 | 安装引导 | 未检测到微信时，弹窗提示用户前往官网下载安装 | P0 |
| F03 | 微信启动 | 双击微信图标，通过 `open -n /Applications/WeChat.app` 启动微信 | P0 |
| F04 | 多开克隆 | 点击「+」按钮，通过管理员权限复制微信客户端 | P1 |
| F05 | 进度展示 | 克隆过程中实时展示进度条和执行状态 | P1 |
| F06 | 动态包名 | 依据复制时间动态生成 Bundle Identifier 和应用名称 | P1 |
| F07 | 实例列表 | 展示所有已克隆的微信实例，支持点击启动 | P2 |

### 2.2 功能详细说明

#### F01 — 微信安装检测
- **触发时机**：应用启动 (`AppDelegate.applicationDidFinishLaunching`)
- **检测逻辑**：调用 `FileManager.default.fileExists(atPath:)` 检查 `/Applications/WeChat.app`
- **结果处理**：
  - 已安装 → 进入主界面
  - 未安装 → 弹出 Alert 提示安装

#### F02 — 安装引导
- 弹出模态对话框，包含：
  - 提示文案：「未检测到微信客户端，请先安装微信」
  - 「前往下载」按钮 → 调用 `NSWorkspace.shared.open(URL)` 打开微信官网
  - 「退出」按钮 → 退出应用

#### F03 — 微信启动
- 主界面显示微信应用图标（从 WeChat.app 中提取）
- 用户双击图标或点击「打开微信」按钮
- 执行命令：`open -n /Applications/WeChat.app`
- `-n` 参数确保以新实例启动（即使已有微信在运行）

#### F04 — 多开克隆
- 界面中微信图标后方显示「+」按钮
- 点击「+」触发克隆流程，依次执行：

```bash
# Step 1: 复制应用包
sudo cp -R /Applications/WeChat.app /Applications/WeChat_<timestamp>.app

# Step 2: 修改 Bundle Identifier（动态包名）
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.tencent.wechat_<timestamp>" \
  /Applications/WeChat_<timestamp>.app/Contents/Info.plist

# Step 3: 重新签名
sudo codesign --force --deep --sign - /Applications/WeChat_<timestamp>.app
```

- `<timestamp>` 格式：`yyyyMMddHHmmss`（如 `20260608143022`）

#### F05 — 进度展示
- 点击「+」后弹出 Sheet/弹窗
- 显示 `ProgressView` 进度条，分为3个阶段：
  1. 复制应用包 (0% → 50%)
  2. 修改包名 (50% → 75%)
  3. 重新签名 (75% → 100%)
- 每阶段完成后更新状态文案

#### F06 — 动态包名
- 使用当前时间戳生成唯一标识符
- 应用名称：`WeChat_yyyyMMddHHmmss.app`
- Bundle ID：`com.tencent.wechat_yyyyMMddHHmmss`
- 确保每次复制的实例互不冲突，可同时运行

#### F07 — 实例列表
- 扫描 `/Applications/` 目录下所有 `WeChat_*.app`
- 以列表形式展示在主界面下方
- 点击列表项启动对应的微信实例

---

## 3. 技术架构

### 3.1 架构图

```
┌─────────────────────────────────────────────┐
│                  SwiftUI Layer               │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ Content  │  │ Clone    │  │ Instance  │  │
│  │ View     │  │ Progress │  │ List      │  │
│  │          │  │ View     │  │ View      │  │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  │
├───────┼─────────────┼──────────────┼────────┤
│       │       ViewModel Layer       │         │
│  ┌────┴─────────────┴──────────────┴──────┐  │
│  │           AppViewModel                  │  │
│  │  - weChatStatus: WeChatStatus           │  │
│  │  - clonedInstances: [ClonedInstance]    │  │
│  │  - isCloning: Bool                      │  │
│  │  - cloneProgress: Double                │  │
│  │  - currentStep: String                  │  │
│  └────┬──────────────────┬────────────────┘  │
├───────┼──────────────────┼───────────────────┤
│       │     Service Layer │                   │
│  ┌────┴──────┐  ┌────────┴──────┐            │
│  │ WeChat    │  │ WeChat        │            │
│  │ Detector  │  │ Cloner        │            │
│  │           │  │               │            │
│  │ - check() │  │ - clone()     │            │
│  │ - icon()  │  │ - scanInst()  │            │
│  └───────────┘  └───────────────┘            │
├─────────────────────────────────────────────┤
│                System Layer                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ NSWork   │  │ Process  │  │ NSApple   │  │
│  │ space    │  │ (Shell)  │  │ Script    │  │
│  └──────────┘  └──────────┘  └───────────┘  │
└─────────────────────────────────────────────┘
```

### 3.2 技术选型

| 层次 | 技术 | 说明 |
|------|------|------|
| UI 框架 | SwiftUI | 声明式 UI，支持 macOS 14+ |
| 窗口管理 | AppKit (NSWindow) | 自定义窗口样式 |
| 文件操作 | FileManager | 文件存在性检查、目录扫描 |
| 进程执行 | Process (NSTask) + AppleScript | 执行 shell 命令和提权操作 |
| 图标提取 | NSWorkspace.shared.icon(forFile:) | 从 WeChat.app 提取应用图标 |
| 异步处理 | async/await + Task | Swift 并发模型 |

### 3.3 数据模型

```swift
/// 微信安装状态
enum WeChatStatus {
    case checking          // 检测中
    case installed         // 已安装
    case notInstalled      // 未安装
}

/// 克隆进度状态
enum CloneStep: String {
    case idle              // 空闲
    case copying           // 正在复制 (0-50%)
    case modifying         // 修改包名 (50-75%)
    case codeSigning       // 重新签名 (75-100%)
    case completed         // 完成
    case failed(String)    // 失败
}

/// 已克隆的微信实例
struct ClonedInstance: Identifiable, Hashable {
    let id = UUID()
    let path: String              // 完整路径
    let name: String              // 应用名
    let bundleIdentifier: String  // Bundle ID
    let cloneDate: Date           // 克隆时间
    let timestamp: String         // 时间戳标识
}
```

---

## 4. 实现方案

### 4.1 项目结构

```
wechat_launcher_macOS/
├── App/
│   ├── WeChatLauncherApp.swift      # @main 入口
│   └── ContentView.swift            # 主界面
├── Services/
│   ├── WeChatDetector.swift         # 微信安装检测
│   └── WeChatCloner.swift           # 微信克隆引擎
├── Views/
│   ├── WeChatIconView.swift         # 微信图标组件（双击启动）
│   ├── CloneProgressView.swift      # 克隆进度弹窗
│   └── InstanceListView.swift       # 已克隆实例列表
├── Resources/
│   ├── Info.plist                   # 应用配置
│   └── Assets.xcassets/            # 资源目录
└── wechat_launcher_macOS.entitlements # 沙盒权限
```

### 4.2 关键实现细节

#### 4.2.1 微信检测 (WeChatDetector)

```swift
struct WeChatDetector {
    static let weChatPath = "/Applications/WeChat.app"
    
    /// 检查微信是否已安装
    static func isWeChatInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: weChatPath)
    }
    
    /// 获取微信应用图标
    static func getWeChatIcon() -> NSImage? {
        return NSWorkspace.shared.icon(forFile: weChatPath)
    }
    
    /// 扫描所有已克隆的微信实例
    static func scanClonedInstances() -> [ClonedInstance] {
        // 扫描 /Applications/ 下所有 WeChat_*.app
    }
}
```

#### 4.2.2 微信启动

```swift
func launchWeChat(at path: String = "/Applications/WeChat.app") {
    let process = Process()
    process.launchPath = "/usr/bin/open"
    process.arguments = ["-n", path]  // -n 开启新实例
    try? process.run()
}
```

#### 4.2.3 克隆流程 (WeChatCloner)

通过 AppleScript 提权执行 shell 命令（弹出系统密码框）：

```swift
func executePrivilegedCommand(_ command: String) async throws -> String {
    let script = """
    do shell script "\(command)" with administrator privileges
    """
    let appleScript = NSAppleScript(source: script)
    var error: NSDictionary?
    let result = appleScript?.executeAndReturnError(&error)
    if let error = error {
        throw CloneError.scriptError(error)
    }
    return result?.stringValue ?? ""
}
```

#### 4.2.4 动态包名生成

```swift
func generateTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMddHHmmss"
    return formatter.string(from: Date())
}

// 生成结果示例:
// 应用名: WeChat_20260608143022.app
// Bundle ID: com.tencent.wechat_20260608143022
```

### 4.3 窗口配置

- 窗口大小：480 × 520 (可调整)
- 最小尺寸：400 × 400
- 窗口标题：「微信启动器」
- 窗口层级：`.floating`（始终在前）
- 关闭行为：退到托盘（可选）

### 4.4 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| 微信未安装 | Alert 提示 + 引导下载 |
| 用户取消授权 | 提示需管理员权限才能克隆 |
| 复制失败（磁盘空间不足） | 提示清理磁盘空间 |
| 签名失败 | 提示错误详情，建议手动重试 |
| 同名实例已存在 | 跳过复制，提示已存在 |

---

## 5. 核心价值点

### 5.1 解决真实痛点
macOS 上微信官方客户端仅支持单实例运行，用户无法同时登录多个微信账号（如工作号与生活号）。本工具通过应用复制 + 动态包名技术，实现真正的微信多开，每个实例独立运行、互不干扰。

### 5.2 一键操作，零门槛
- 双击图标即可启动微信
- 点击「+」一键完成复制、改名、签名全流程
- 无需终端命令，无需技术背景

### 5.3 安全可控
- 使用 AppleScript `with administrator privileges` 提权，走系统原生鉴权
- 不存储用户密码，每次授权独立
- 仅修改复制副本的 Bundle ID，不触碰原始微信客户端
- 签名使用 `codesign --force --deep --sign -` 进行 ad-hoc 签名，确保副本可运行

### 5.4 动态包名 — 无限多开
- 基于时间戳的命名策略，每次克隆生成唯一标识
- 天然支持无限多个实例并存
- 避免 Bundle ID 冲突导致的启动失败

### 5.5 原生 macOS 体验
- SwiftUI 原生界面，与 macOS 系统风格一致
- 直接提取微信原始图标展示
- 双击交互符合 macOS 用户习惯

### 5.6 架构清晰，易于扩展
- MVVM 分层架构，Service 层可复用
- 后续可扩展：实例管理（删除/重命名）、快捷登录、启动代理、菜单栏驻留等

---

## 6. 开发计划

| 阶段 | 内容 | 预计产出 |
|------|------|----------|
| Phase 1 | 项目骨架搭建 | Xcode 项目、基础目录结构 |
| Phase 2 | 微信检测 + 启动 | 核心功能可用 |
| Phase 3 | 克隆引擎 + 进度展示 | 多开功能可用 |
| Phase 4 | 实例列表 + UI 打磨 | 完整功能可用 |
| Phase 5 | 测试 + 打包 | 可分发 .app |

---

## 7. 注意事项

1. **签名限制**：使用 ad-hoc 签名 (`sign -`) 的副本在部分 macOS 安全策略下可能被 Gatekeeper 拦截，用户需在「系统设置 → 隐私与安全性」中放行。
2. **SIP 限制**：修改 `/Applications/` 目录需要管理员权限，这是系统行为，无法绕过。
3. **微信版本兼容性**：微信客户端更新后，已克隆的旧版本副本不会自动更新，需手动重新克隆。
4. **AppleScript 权限**：首次使用时系统会请求辅助功能权限，属于正常行为。
