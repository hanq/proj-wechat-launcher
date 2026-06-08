import SwiftUI

/// 已克隆微信实例列表
struct InstanceListView: View {
    let instances: [ClonedInstance]
    let onLaunch: (ClonedInstance) -> Void
    let onUpdateNote: (ClonedInstance, String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(instances) { instance in
                    InstanceRowView(instance: instance) {
                        onLaunch(instance)
                    } onUpdateNote: { newNote in
                        onUpdateNote(instance, newNote)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 220)
    }
}

// MARK: - 单行实例视图

struct InstanceRowView: View {
    let instance: ClonedInstance
    let onLaunch: () -> Void
    let onUpdateNote: (String) -> Void

    @State private var isHovering: Bool = false
    @State private var isEditingNote: Bool = false
    @State private var editingNote: String = ""
    @FocusState private var isNoteFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 微信图标
            Image(nsImage: NSWorkspace.shared.icon(forFile: instance.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)

            // 实例信息
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // 备注行：可点击编辑
                noteRow

                Text("创建于 \(instance.formattedDate)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            // 启动按钮
            Button {
                onLaunch()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1.0 : 0.4)
            .help("启动此微信实例")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(isHovering ? 0.2 : 0.08), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            onLaunch()
        }
        .onChange(of: isNoteFieldFocused) { _, focused in
            if !focused && isEditingNote {
                commitNote()
            }
        }
    }

    // MARK: - 备注行

    @ViewBuilder
    private var noteRow: some View {
        if isEditingNote {
            TextField("备注（回车保存）", text: $editingNote)
                .textFieldStyle(.plain)
                .font(.caption)
                .focused($isNoteFieldFocused)
                .onSubmit {
                    commitNote()
                }
                .onAppear {
                    isNoteFieldFocused = true
                }
        } else {
            HStack(spacing: 4) {
                if instance.note.isEmpty {
                    Text("点击添加备注…")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.4))
                        .italic()
                } else {
                    Text(instance.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "pencil.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(isHovering ? 0.6 : 0))
            }
            .onTapGesture {
                editingNote = instance.note
                isEditingNote = true
            }
        }
    }

    private func commitNote() {
        let trimmed = editingNote.trimmingCharacters(in: .whitespaces)
        onUpdateNote(trimmed)
        isEditingNote = false
    }
}

#Preview {
    InstanceListView(
        instances: [
            ClonedInstance(
                path: "/Applications/WeChat_20260608143022.app",
                name: "WeChat_20260608143022.app",
                bundleIdentifier: "com.tencent.wechat_20260608143022",
                cloneDate: Date(),
                timestamp: "20260608143022",
                note: "工作号"
            ),
            ClonedInstance(
                path: "/Applications/WeChat_20260601120000.app",
                name: "WeChat_20260601120000.app",
                bundleIdentifier: "com.tencent.wechat_20260601120000",
                cloneDate: Date().addingTimeInterval(-86400 * 7),
                timestamp: "20260601120000"
            )
        ],
        onLaunch: { _ in },
        onUpdateNote: { _, _ in }
    )
    .frame(width: 460, height: 200)
}
