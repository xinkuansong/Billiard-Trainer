import SwiftUI

struct BTEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.btLargeTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(.btPrimary)
            }

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
                    .padding(.horizontal, Spacing.xxl)
            }
        }
        .padding(Spacing.xxxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Light") {
    BTEmptyState(
        icon: "tray",
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
