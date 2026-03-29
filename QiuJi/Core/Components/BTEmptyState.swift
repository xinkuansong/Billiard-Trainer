import SwiftUI

struct BTEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.btTextTertiary)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)

                Text(subtitle)
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(BTButtonStyle.primary)
                    .frame(width: 200)
            }
        }
        .padding(Spacing.xxxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Light") {
    BTEmptyState(
        icon: "figure.pool.swim",
        title: "还没有训练记录",
        subtitle: "完成第一次训练后，记录将在这里显示",
        actionTitle: "开始训练",
        action: {}
    )
    .background(.btBG)
}

#Preview("Dark") {
    BTEmptyState(
        icon: "magnifyingglass",
        title: "没有找到相关训练项目",
        subtitle: "试试换个关键词搜索"
    )
    .background(.btBG)
    .preferredColorScheme(.dark)
}
