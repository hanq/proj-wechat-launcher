# wechat_launcher_macOS — 微信多开启动器

macOS SwiftUI + AppKit 项目，为 macOS 用户提供微信快速启动和一键多开（应用克隆）。

## 项目结构

```
wechat_launcher_macOS/
├── App/
│   ├── WeChatLauncherApp.swift    # @main 应用入口，WindowGroup
│   └── AppViewModel.swift         # 核心 ViewModel + 数据模型 (ClonedInstance, CloneStep, WeChatStatus)
├── Services/
│   ├── WeChatDetector.swift       # 微信安装检测 + 图标提取 + open -n 启动
│   ├── WeChatCloner.swift         # 克隆引擎：cp + PlistBuddy 改名 + codesign 签名 + 文件扫描
│   └── NotesStore.swift           # 实例备注 JSON 持久化（keyed by timestamp）
├── Views/
│   ├── ContentView.swift          # 主界面三态：检测中 / 未安装 / 已安装
│   ├── WeChatIconView.swift       # 微信图标组件（双击启动 + 悬停动效）
│   ├── CloneProgressView.swift    # 克隆进度弹窗（三步骤指示器）
│   └── InstanceListView.swift     # 已克隆实例列表 + 行内备注编辑
├── Resources/
│   ├── Info.plist                 # CFBundleDisplayName = "微信启动器"
│   └── Assets.xcassets/          # 应用图标资源
└── wechat_launcher_macOS.entitlements  # 沙盒关闭
```

## 构建

```bash
xcodebuild -project wechat_launcher_macOS.xcodeproj -scheme wechat_launcher_macOS -configuration Debug build
```

最低系统要求 macOS 14.0，SDK macosx，Swift 5.0。

## 关键设计决策

### 文件系统即数据库
克隆实例的权威来源是 `/Applications/WeChat_*.app`。每次启动/刷新扫描目录，正则匹配 `WeChat_(\d{14})\.app`。JSON 文件仅存备注等文件系统无法承载的元数据。删除 .app 文件即删除实例，天然同步无需额外维护。

### 克隆流程
1. `sudo cp -R /Applications/WeChat.app /Applications/WeChat_{timestamp}.app`
2. `sudo PlistBuddy -c "Set :CFBundleIdentifier com.tencent.wechat_{timestamp}" .../Info.plist`
3. `sudo codesign --force --deep --sign - /Applications/WeChat_{timestamp}.app`

通过 AppleScript `do shell script ... with administrator privileges` 提权（弹出系统鉴权对话框）。

### 动态包名
- timestamp 格式：`yyyyMMddHHmmss`
- 应用名：`WeChat_{timestamp}.app`
- Bundle ID 前缀：`com.tencent.wechat_`

## 代码规范

- ViewModel 用 `@MainActor` 标注
- 异步操作用 `async/await` + `Task`
- 错误用 `enum CloneError: LocalizedError`
- 新文件需在 pbxproj 注册：PBXBuildFile / PBXFileReference / Group children / SourcesBuildPhase
- UI 组件优先用 SwiftUI，需 AppKit 能力时混用（如 NSCursor、NSWorkspace、NSAppleScript）

## 已尝试并否决的方案

- **NSWorkspace.setIcon 自定义图标**：在当前环境下不生效，已完整回退
- **本地数据库持久化实例列表**：用户更倾向文件系统扫描方案，不额外维护数据库

## 功能清单

| 功能 | 实现方式 |
|------|----------|
| 微信安装检测 | FileManager + Info.plist 双重校验 |
| 启动微信 | `open -n -a` 或 NSWorkspace.open 降级 |
| 双击图标启动 | `.onTapGesture(count: 2)` |
| 一键克隆 | AppleScript 提权三步命令 |
| 进度展示 | 三阶段 ProgressView + 步骤指示器 |
| 实例扫描 | 正则匹配 + Plist 解析 |
| 备注功能 | JSON 文件持久化，行内点击编辑 |
| 安装引导 | Alert 弹窗 → 微信官网 |
