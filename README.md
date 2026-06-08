# 微信启动器 WeChat Launcher

macOS 微信多开启动器 —— 双击图标启动微信，一键克隆实现多开。

## 为什么需要它？

macOS 上微信官方客户端只允许运行一个实例。一个微信号登录后，如果想同时登录工作号和生活号，只能反复切换。微信启动器通过**动态包名 + 应用副本**技术，让你的每个微信号都有独立运行空间。

## 核心功能

| 功能 | 说明 |
|------|------|
| 🔍 智能检测 | 启动时自动检查微信是否安装，未安装则引导下载 |
| 🚀 快速启动 | 主界面展示微信图标，双击即可启动 |
| ➕ 一键克隆 | 点击「+」按钮，自动完成复制→改名→签名，创建独立微信实例 |
| 📝 实例备注 | 为每个克隆实例添加备注（如"工作号""生活号"），方便区分 |
| 📊 进度展示 | 克隆过程三步进度条，状态透明可见 |

## 系统要求

- macOS 14.0 (Sonoma) 及以上
- 已安装微信客户端 (`/Applications/WeChat.app`)
- Xcode 16+（从源码构建时需要）

## 快速开始

### 直接下载

[![Release](https://img.shields.io/badge/release-v1.0.0-green?logo=github)](https://github.com/hanq/proj-wechat-launcher/releases/latest)

从 [Releases](https://github.com/hanq/proj-wechat-launcher/releases/latest) 下载 `微信启动器.zip`，解压拖入 `/Applications`，双击运行。

> 首次运行时如被 Gatekeeper 拦截，请前往「系统设置 → 隐私与安全性」中放行。

### 从源码构建

```bash
git clone git@github.com:hanq/proj-wechat-launcher.git
cd proj-wechat-launcher
xcodebuild -project wechat_launcher_macOS.xcodeproj \
           -scheme wechat_launcher_macOS \
           -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/wechat_launcher_macOS-*/Build/Products/Release/微信启动器.app /Applications/
```

然后用 Xcode 打开 `wechat_launcher_macOS.xcodeproj`，`⌘+R` 运行。

## 使用指南

### 启动微信
打开应用后，主界面显示微信图标，**双击图标**或点击「打开微信」按钮即可启动。

### 创建多开实例
1. 点击「创建微信副本」按钮
2. 系统弹出管理员权限确认，输入密码
3. 等待复制→改名→签名三步完成
4. 列表中新增一个微信实例，点击 ▶ 即可启动

### 添加备注
实例列表每行点击「点击添加备注…」即可录入文字（如"工作号 - 产品群"），回车保存，重启后依然保留。

## 工作原理

```
macOS 微信多开的原理：

1. cp -R /Applications/WeChat.app /Applications/WeChat_{timestamp}.app
   → 创建独立的应用副本

2. PlistBuddy 修改 CFBundleIdentifier 为 com.tencent.wechat_{timestamp}
   → macOS 认为这是"不同"的应用，允许同时运行

3. codesign --force --deep --sign - WeChat_{timestamp}.app
   → ad-hoc 重新签名，确保副本可运行
```

每次克隆的时间戳唯一（精确到秒），确保多个副本互不冲突。

## 项目结构

```
wechat_launcher_macOS/
├── App/
│   ├── WeChatLauncherApp.swift    # @main 应用入口
│   └── AppViewModel.swift         # 核心状态管理 + 数据模型
├── Services/
│   ├── WeChatDetector.swift       # 微信安装检测 + 启动
│   ├── WeChatCloner.swift         # 克隆引擎（cp/改名/签名）
│   └── NotesStore.swift           # 备注 JSON 持久化
├── Views/
│   ├── ContentView.swift          # 主界面
│   ├── WeChatIconView.swift       # 微信图标组件
│   ├── CloneProgressView.swift    # 克隆进度弹窗
│   └── InstanceListView.swift     # 实例列表 + 行内备注编辑
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/          # 应用图标
```

## 技术栈

- **语言**: Swift 5.9+
- **UI**: SwiftUI + AppKit 混合
- **提权**: AppleScript `with administrator privileges`
- **持久化**: 文件系统为主（`/Applications/WeChat_*.app`），JSON 仅存备注
- **最低系统**: macOS 14.0

## 注意事项

- 克隆操作需要管理员密码（修改 `/Applications/` 目录）
- 克隆副本使用 ad-hoc 签名，首次运行时如被 Gatekeeper 拦截，请在「系统设置 → 隐私与安全性」中放行
- 微信客户端更新后，已克隆的旧版本副本不会自动更新

## License

MIT
