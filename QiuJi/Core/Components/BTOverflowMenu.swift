import SwiftUI

// MARK: - Menu Item

struct BTMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let label: String
    let isDestructive: Bool
    let action: () -> Void

    init(icon: String, iconColor: Color, label: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.isDestructive = isDestructive
        self.action = action
    }
}

// MARK: - BTOverflowMenu

struct BTOverflowMenu: View {
    let items: [BTMenuItem]
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.btCallout)
                .fontWeight(.medium)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更多操作")
        .confirmationDialog("", isPresented: $isPresented, titleVisibility: .hidden) {
            ForEach(items) { item in
                Button(item.label, role: item.isDestructive ? .destructive : nil) {
                    item.action()
                }
            }
        }
    }
}

// MARK: - Custom popup variant (for contexts requiring the exact design)

struct BTOverflowMenuPopup: View {
    let items: [BTMenuItem]
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isPresented {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if item.isDestructive && index > 0 {
                        Divider()
                            .padding(.leading, Spacing.lg)
                    }

                    Button {
                        isPresented = false
                        item.action()
                    } label: {
                        HStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(item.isDestructive ? Color.btDestructive.opacity(0.12) : item.iconColor.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: item.icon)
                                    .font(.btFootnote14)
                                    .fontWeight(.medium)
                                    .foregroundStyle(item.isDestructive ? .btDestructive : item.iconColor)
                            }

                            Text(item.label)
                                .font(.btCallout)
                                .foregroundStyle(item.isDestructive ? .btDestructive : .btText)

                            Spacer()
                        }
                        .padding(.horizontal, Spacing.lg)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.12), radius: 16, x: 0, y: 4)
            .frame(width: 220)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
        }
    }
}

// MARK: - Preview

#Preview("BTOverflowMenu Light") {
    VStack(spacing: Spacing.xxxl) {
        HStack {
            Spacer()
            BTOverflowMenu(items: [
                BTMenuItem(icon: "square.and.arrow.up", iconColor: .btPrimary, label: "生成分享图") {},
                BTMenuItem(icon: "calendar", iconColor: .btPrimary, label: "移动到某天") {},
                BTMenuItem(icon: "pencil", iconColor: .btAccent, label: "编辑心得") {},
                BTMenuItem(icon: "doc.on.doc", iconColor: .btPrimary, label: "导入为模板") {},
                BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
            ])
        }

        StatefulMenuPreview { binding in
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { binding.wrappedValue.toggle() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.btCallout)
                            .fontWeight(.medium)
                            .foregroundStyle(.btTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Spacer()
                    BTOverflowMenuPopup(items: [
                        BTMenuItem(icon: "square.and.arrow.up", iconColor: .btPrimary, label: "生成分享图") {},
                        BTMenuItem(icon: "calendar", iconColor: .btPrimary, label: "移动到某天") {},
                        BTMenuItem(icon: "pencil", iconColor: .btAccent, label: "编辑心得") {},
                        BTMenuItem(icon: "doc.on.doc", iconColor: .btPrimary, label: "导入为模板") {},
                        BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
                    ], isPresented: binding)
                }
            }
        }
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
}

#Preview("BTOverflowMenu Dark") {
    VStack(spacing: Spacing.xxxl) {
        HStack {
            Spacer()
            BTOverflowMenu(items: [
                BTMenuItem(icon: "square.and.arrow.up", iconColor: .btPrimary, label: "生成分享图") {},
                BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
            ])
        }

        StatefulMenuPreview { binding in
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { binding.wrappedValue.toggle() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.btCallout)
                            .fontWeight(.medium)
                            .foregroundStyle(.btTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Spacer()
                    BTOverflowMenuPopup(items: [
                        BTMenuItem(icon: "square.and.arrow.up", iconColor: .btPrimary, label: "生成分享图") {},
                        BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
                    ], isPresented: binding)
                }
            }
        }
    }
    .padding(Spacing.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}

private struct StatefulMenuPreview<Content: View>: View {
    @State private var isPresented = true
    let content: (Binding<Bool>) -> Content

    init(@ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        self.content = content
    }

    var body: some View {
        content($isPresented)
    }
}
