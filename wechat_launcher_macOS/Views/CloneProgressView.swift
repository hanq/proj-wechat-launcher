import SwiftUI

/// 克隆进度弹窗
struct CloneProgressView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("正在创建微信副本")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 20)

            // 图标动画
            statusIcon
                .padding(.vertical, 8)

            // 进度条
            VStack(spacing: 8) {
                ProgressView(value: viewModel.cloneProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .frame(width: 320)

                Text("\(Int(viewModel.cloneProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // 状态文案
            Text(viewModel.cloneStatusMessage)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .animation(.easeInOut(duration: 0.3), value: viewModel.cloneStatusMessage)

            // 步骤指示器
            stepIndicator
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()

            // 底部按钮
            bottomButton
                .padding(.bottom, 20)
        }
        .frame(width: 420, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 状态图标

    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.cloneStep {
        case .idle:
            ProgressView()
                .scaleEffect(1.5)
        case .copying:
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
        case .modifyingPlist:
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
        case .codeSigning:
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
                .symbolEffect(.pulse)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
        }
    }

    // MARK: - 步骤指示器

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepDot(step: .copying, label: "复制", icon: "doc.on.doc")
            stepLine(after: .copying)
            stepDot(step: .modifyingPlist, label: "改名", icon: "pencil")
            stepLine(after: .modifyingPlist)
            stepDot(step: .codeSigning, label: "签名", icon: "signature")
        }
    }

    private func stepDot(step: CloneStep, label: String, icon: String) -> some View {
        let isActive = stepStatus(for: step)
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive == .completed ? Color.green :
                          isActive == .active ? Color.accentColor :
                          Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)

                if isActive == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive == .active {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(isActive != .pending ? .primary : .secondary)
        }
    }

    private func stepLine(after step: CloneStep) -> some View {
        let isCompleted = stepStatus(for: step) == .completed
        return Rectangle()
            .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 40)
            .animation(.easeInOut(duration: 0.5), value: isCompleted)
    }

    private enum StepStatus { case pending, active, completed }

    private func stepStatus(for step: CloneStep) -> StepStatus {
        switch viewModel.cloneStep {
        case .idle:
            return .pending
        case .copying:
            return step == .copying ? .active : .pending
        case .modifyingPlist:
            if step == .copying { return .completed }
            return step == .modifyingPlist ? .active : .pending
        case .codeSigning:
            if step == .copying || step == .modifyingPlist { return .completed }
            return step == .codeSigning ? .active : .pending
        case .completed:
            return .completed
        case .failed:
            // 显示失败前完成的步骤
            return .pending
        }
    }

    // MARK: - 进度条颜色

    private var progressTint: Color {
        if case .failed = viewModel.cloneStep {
            return .red
        }
        if case .completed = viewModel.cloneStep {
            return .green
        }
        return .accentColor
    }

    // MARK: - 底部按钮

    @ViewBuilder
    private var bottomButton: some View {
        if case .completed = viewModel.cloneStep {
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if case .failed = viewModel.cloneStep {
            HStack(spacing: 12) {
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("重试") {
                    viewModel.startClone()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else {
            Button("取消") {
                // 注意：已启动的命令无法取消
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.cloneProgress > 0.05 && viewModel.cloneProgress < 0.95)
        }
    }
}

#Preview {
    CloneProgressView()
        .environmentObject(AppViewModel())
}
