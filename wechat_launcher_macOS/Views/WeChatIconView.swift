import SwiftUI
import AppKit

/// 微信图标组件 — 支持双击启动
struct WeChatIconView: View {
    let icon: NSImage?
    let isEnabled: Bool

    @State private var isHovering: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(isPressed ? 0.1 : (isHovering ? 0.2 : 0.12)),
                            radius: isPressed ? 4 : (isHovering ? 10 : 6),
                            y: isPressed ? 2 : (isHovering ? 5 : 3))
                    .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.03 : 1.0))
                    .opacity(isEnabled ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
                    .animation(.easeInOut(duration: 0.10), value: isPressed)
            } else {
                // 占位图标
                Image(systemName: "app.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                    .frame(width: 100, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.green.opacity(0.12))
                    )
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .help("双击打开微信")
    }
}

#Preview {
    WeChatIconView(
        icon: NSWorkspace.shared.icon(forFile: "/Applications/WeChat.app"),
        isEnabled: true
    )
    .frame(width: 200, height: 200)
}
