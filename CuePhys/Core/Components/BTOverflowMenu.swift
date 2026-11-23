import SwiftUI

/// Fits the longest menu row, including its icon/selection indicator, without
/// imposing the system Menu's minimum width. The cap still permits wrapping.
struct BTIntrinsicMenuLayout: Layout {
    var maximumWidth: CGFloat = 340

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let ideal = content.sizeThatFits(.unspecified)
        let available = proposal.width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? maximumWidth
        let width = min(maximumWidth, available, max(112, ideal.width))
        return CGSize(width: width, height: content.sizeThatFits(.init(width: width, height: nil)).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: .init(width: bounds.width, height: bounds.height))
    }
}

/// Short action menus keep their original Button callbacks and dismissal
/// semantics, while allowing a content-sized native anchored popover.
struct BTCompactMenu<Content: View, Trigger: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Trigger
    @State private var expanded = false
    @State private var pendingAction: (() -> Void)?

    var body: some View {
        Button { expanded = true } label: { label() }
            .popover(isPresented: $expanded) {
                BTIntrinsicMenuLayout {
                    VStack(alignment: .leading, spacing: 0) { content() }
                        .padding(.vertical, 8)
                }
                .font(.body)
                .foregroundStyle(Color.btText)
                .labelStyle(BTCompactMenuLabelStyle())
                .environment(\.btCompactMenuPerform, { action in
                    pendingAction = action
                    expanded = false
                })
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    // Present sheets/alerts only after this popover has left.
                    let action = pendingAction
                    pendingAction = nil
                    action?()
                }
            }
    }
}

struct BTCompactMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption).foregroundStyle(Color.btTextSecondary)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

private struct BTCompactMenuLabelStyle: LabelStyle {
    var iconColor: Color = .btPrimary
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon.frame(width: 22).foregroundStyle(iconColor)
            configuration.title
        }
    }
}

/// Keep a stable selection column for every option.
struct BTCompactMenuChoiceLabel: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? BTIcon.checkmarkSquare : BTIcon.square).frame(width: 22)
                .foregroundStyle(isSelected ? Color.btPrimary : Color.btTextSecondary)
                .accessibilityHidden(true)
            Text(title)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BTCompactMenuPerformKey: EnvironmentKey {
    static let defaultValue: (@escaping () -> Void) -> Void = { $0() }
}

private extension EnvironmentValues {
    var btCompactMenuPerform: (@escaping () -> Void) -> Void {
        get { self[BTCompactMenuPerformKey.self] }
        set { self[BTCompactMenuPerformKey.self] = newValue }
    }
}

/// The dismissal is part of the real Button action, including accessibility
/// activation; a PrimitiveButtonStyle alone does not intercept every activation.
struct BTCompactMenuAction<Label: View>: View {
    var role: ButtonRole? = nil
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.btCompactMenuPerform) private var perform
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(role: role) { perform(action) } label: {
            label()
                .labelStyle(BTCompactMenuLabelStyle(iconColor: role == .destructive ? .btDestructive : .btPrimary))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .foregroundStyle(role == .destructive ? Color.btDestructive : Color.btText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

extension BTCompactMenuAction where Label == Text {
    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.role = role
        self.action = action
        self.label = { Text(title) }
    }
}

extension BTCompactMenuAction where Label == SwiftUI.Label<Text, Image> {
    init(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.role = role
        self.action = action
        self.label = { SwiftUI.Label(title, systemImage: systemImage) }
    }
}

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
            Image(systemName: BTIcon.menu)
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
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
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
                BTMenuItem(icon: "pencil", iconColor: .btPrimary, label: "编辑心得") {},
                BTMenuItem(icon: "doc.on.doc", iconColor: .btPrimary, label: "导入为模板") {},
                BTMenuItem(icon: "trash", iconColor: .btDestructive, label: "删除", isDestructive: true) {},
            ])
        }

        StatefulMenuPreview { binding in
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(BTMotion.easeFast) { binding.wrappedValue.toggle() }
                    } label: {
                        Image(systemName: BTIcon.menu)
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
                        BTMenuItem(icon: "pencil", iconColor: .btPrimary, label: "编辑心得") {},
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
                        withAnimation(BTMotion.easeFast) { binding.wrappedValue.toggle() }
                    } label: {
                        Image(systemName: BTIcon.menu)
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
