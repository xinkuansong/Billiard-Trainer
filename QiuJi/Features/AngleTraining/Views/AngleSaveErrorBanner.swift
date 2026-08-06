import SwiftUI

/// 「练」分区答题成绩落库失败时的可见错误态（问题集合 v29 W1）。
/// 4 个答题页原先用 `try?` 吞掉保存错误 —— 用户无从得知这题没进历史。
/// 现在失败时把成绩留在 ViewModel 的 `unsavedResults` 里并置错误文案，
/// 由本横幅展示 + 提供重试入口。
enum AngleResultSaveFailure {

    static func message(_ error: Error) -> String {
        "成绩未能保存到历史（\(error.localizedDescription)）。本题答案已保留，可点「重试」。"
    }
}

struct AngleSaveErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.btFootnote)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack {
                Spacer()
                Button("重试", action: retry)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
            }
        }
        .foregroundStyle(.white)
        .padding(Spacing.md)
        .background(Color.btDestructive.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: BTRadius.md))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("成绩保存失败")
    }
}

private struct AngleSaveErrorBannerModifier: ViewModifier {
    let message: String?
    let retry: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                AngleSaveErrorBanner(message: message, retry: retry)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(BTMotion.easeChrome, value: message)
    }
}

extension View {
    /// 常驻（非自动消失）保存失败横幅：错误态必须可见到用户重试成功为止。
    func angleSaveErrorBanner(message: String?,
                              retry: @escaping () -> Void) -> some View {
        modifier(AngleSaveErrorBannerModifier(message: message, retry: retry))
    }
}
