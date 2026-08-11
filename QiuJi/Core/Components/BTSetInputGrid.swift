import SwiftUI

// MARK: - Data Model

struct DrillSetData: Identifiable {
    let id: Int
    var madeBalls: Int
    var targetBalls: Int
    var isCompleted: Bool
    var isWarmup: Bool
    var duration: TimeInterval?
    /// 本组打的是哪个球形（契约 §4.1）。单球形 drill 为 nil。
    var formationToken: String?
    /// 球形显示名，随组次一起快照落库（契约 §6.5）。
    var formationName: String?

    init(id: Int, madeBalls: Int = 0, targetBalls: Int = 15, isCompleted: Bool = false, isWarmup: Bool = false, duration: TimeInterval? = nil,
         formationToken: String? = nil, formationName: String? = nil) {
        self.id = id
        self.madeBalls = madeBalls
        self.targetBalls = targetBalls
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
        self.duration = duration
        self.formationToken = formationToken
        self.formationName = formationName
    }
}

/// 录入时可选的球形（来自 `DrillTryoutBoardStore.formations(for:)`）。
struct DrillFormationOption: Identifiable, Hashable {
    let token: String
    let name: String

    var id: String { token }

    /// 列表用短标签：序列名形如「中袋角度精准 · 球形2」，取「·」后一段避免撑爆行宽。
    var shortLabel: String {
        guard let tail = name.split(separator: "·").last, name.contains("·") else { return name }
        return tail.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - BTSetInputGrid

struct BTSetInputGrid: View {
    @Binding var sets: [DrillSetData]
    var onAddSet: () -> Void
    var onComplete: (Int) -> Void
    var onDeleteSet: ((Int) -> Void)? = nil
    var showSetTimer: Bool = false
    var showSuccessRate: Bool = false
    /// 多球形 drill 的可选球形；为空表示单球形，不出球形列。
    var formationOptions: [DrillFormationOption] = []
    /// v34 R12：多球形时按球形插入分节头。
    var sectionByFormation: Bool = false

    private var activeIndex: Int? {
        sets.firstIndex(where: { !$0.isCompleted })
    }

    /// 连续同 token 分组；仅当存在 ≥2 种球形时才出分节头。
    private var formationSections: [(title: String?, indices: [Int])] {
        guard !sets.isEmpty else { return [] }
        let keys = sets.map { $0.formationToken ?? "" }
        let distinct = Set(keys.filter { !$0.isEmpty })
        let shouldSection = sectionByFormation && distinct.count > 1

        var sections: [(String?, [Int])] = []
        var currentKey: String?
        var currentIndices: [Int] = []
        var sectionOrdinal = 0

        for (index, set) in sets.enumerated() {
            let key = set.formationToken ?? ""
            if currentKey == nil {
                currentKey = key
                currentIndices = [index]
                sectionOrdinal = 1
            } else if key == currentKey {
                currentIndices.append(index)
            } else {
                sections.append((shouldSection ? sectionTitle(token: currentKey!, name: sets[currentIndices[0]].formationName, ordinal: sectionOrdinal) : nil, currentIndices))
                sectionOrdinal += 1
                currentKey = key
                currentIndices = [index]
            }
        }
        if !currentIndices.isEmpty {
            let title: String? = shouldSection
                ? sectionTitle(token: currentKey ?? "", name: sets[currentIndices[0]].formationName, ordinal: sectionOrdinal)
                : nil
            sections.append((title, currentIndices))
        }
        return sections
    }

    private func sectionTitle(token: String, name: String?, ordinal: Int) -> String {
        if let name, !name.isEmpty { return name }
        if let option = formationOptions.first(where: { $0.token == token }) {
            return option.shortLabel
        }
        return "球形\(ordinal)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundStyle(.btSeparator)

            if sets.isEmpty {
                emptyState
            } else {
                ForEach(Array(formationSections.enumerated()), id: \.offset) { _, section in
                    VStack(spacing: 0) {
                        if let title = section.title {
                            formationSectionHeader(title)
                        }
                        ForEach(section.indices, id: \.self) { index in
                            SetRow(
                                setData: $sets[index],
                                rowState: rowState(for: index),
                                showSetTimer: showSetTimer,
                                showSuccessRate: showSuccessRate,
                                formationOptions: formationOptions,
                                onComplete: { onComplete(index) },
                                onDelete: onDeleteSet != nil ? { onDeleteSet?(index) } : nil
                            )
                            if index < sets.count - 1 {
                                Divider()
                                    .foregroundStyle(.btSeparator)
                                    .padding(.leading, section.title == nil ? Spacing.lg : 0)
                            }
                        }
                    }
                }
            }

            addButton
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .accessibilityIdentifier("setInputGrid")
    }

    private func formationSectionHeader(_ title: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "square.stack.3d.up")
                .font(.btCaption2)
                .foregroundStyle(.btPrimary)
            Text(title)
                .font(.btCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btPrimaryMuted)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("formationSectionHeader")
        .accessibilityLabel("分节 \(title)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("组")
                .frame(width: 32)
            Text("进球")
                .frame(maxWidth: .infinity)
            Text("总球")
                .frame(maxWidth: .infinity)
            if !formationOptions.isEmpty {
                Text("球形")
                    .frame(maxWidth: .infinity)
            }
            if showSetTimer {
                Text("时间")
                    .frame(maxWidth: .infinity)
            }
            if showSuccessRate {
                Text("成功率")
                    .frame(maxWidth: .infinity)
            }
            Image(systemName: "checkmark")
                .frame(width: 44)
            Image(systemName: "ellipsis")
                .frame(width: 44)
        }
        .font(.btCaption)
        .foregroundStyle(.btTextSecondary)
        .frame(height: 36)
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.btStatNumber)
                .fontWeight(.regular)
                .foregroundStyle(.btTextTertiary)
            Text("还没有组数")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAddSet) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus")
                Text("添加一组")
            }
            .font(.btCallout)
            .foregroundStyle(.btPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加一组")
    }

    // MARK: - Row State

    enum RowState: Equatable {
        case completed, active, pending
    }

    func rowState(for index: Int) -> RowState {
        if sets[index].isCompleted { return .completed }
        if index == activeIndex { return .active }
        return .pending
    }
}

// MARK: - Set Row

private struct SetRow: View {
    @Binding var setData: DrillSetData
    let rowState: BTSetInputGrid.RowState
    let showSetTimer: Bool
    let showSuccessRate: Bool
    let formationOptions: [DrillFormationOption]
    let onComplete: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var madeBallsText: Binding<String> {
        Binding(
            get: { setData.madeBalls > 0 ? "\(setData.madeBalls)" : "" },
            set: { newValue in
                if let val = Int(newValue), val >= 0 {
                    setData.madeBalls = min(val, setData.targetBalls)
                } else if newValue.isEmpty {
                    setData.madeBalls = 0
                }
            }
        )
    }

    private var targetBallsText: Binding<String> {
        Binding(
            get: { "\(setData.targetBalls)" },
            set: { newValue in
                if let val = Int(newValue), val > 0 {
                    setData.targetBalls = val
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            setNumberColumn
            madeBallsColumn
            targetBallsColumn
            if !formationOptions.isEmpty {
                formationColumn
            }
            if showSetTimer {
                timerColumn
            }
            if showSuccessRate {
                successRateColumn
            }
            checkColumn
            menuColumn
        }
        .frame(height: 48)
        .padding(.horizontal, Spacing.sm)
        .background(rowState == .completed ? Color.btPrimary.opacity(0.06) : Color.clear)
        .overlay(alignment: .leading) {
            if rowState == .active {
                Rectangle()
                    .fill(Color.btPrimary)
                    .frame(width: 4)
            }
        }
        // F-AT-02: animate completed fill + active bar (driven by ViewModel withAnimation)
        .animation(BTMotion.easeFast, value: setData.isCompleted)
        .animation(BTMotion.easeFast, value: rowState)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第\(setData.id)组, \(setData.madeBalls)/\(setData.targetBalls)球")
    }

    private var setNumberColumn: some View {
        Group {
            if setData.isWarmup {
                Text("热")
                    .font(.btCaption2)
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.btWarning)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.xxs))
            } else {
                Text("\(setData.id)")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 32)
    }

    private var inputCellFill: Color {
        if rowState == .completed { return Color.btBGSecondary }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private var madeBallsColumn: some View {
        ZStack {
            if rowState != .completed {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: rowState == .active ? 1.5 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(inputCellFill)
                    )
            }
            if setData.isCompleted {
                Text("\(setData.madeBalls)")
                    .font(.btHeadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.btText)
            } else {
                TextField("-", text: madeBallsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
        }
        .frame(width: 44, height: 36)
        .frame(maxWidth: .infinity)
    }

    private var targetBallsColumn: some View {
        ZStack {
            if rowState != .completed {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.btSeparator, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(inputCellFill)
                    )
            }
            if setData.isCompleted {
                Text("\(setData.targetBalls)")
                    .font(.btSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.btTextSecondary)
            } else {
                TextField("", text: targetBallsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 44, height: 36)
        .frame(maxWidth: .infinity)
    }

    private var checkColumn: some View {
        Button(action: onComplete) {
            ZStack {
                if setData.isCompleted {
                    Circle()
                        .fill(Color.btPrimary)
                    Image(systemName: BTIcon.checkmark)
                        .font(.btCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(Color.btSeparator, lineWidth: 1.5)
                }
            }
            .frame(width: 24, height: 24)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        // F-AT-02: press feedback on highest-frequency complete control
        .buttonStyle(BTPressableStyle.row)
        .highPriorityGesture(TapGesture().onEnded { onComplete() })
        .accessibilityLabel(setData.isCompleted ? "已完成" : "标记完成")
    }

    @ViewBuilder
    private var menuColumn: some View {
        if let deleteFn = onDelete {
            Menu {
                Button(role: .destructive, action: deleteFn) {
                    Label("删除此组", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("更多操作")
        } else {
            Image(systemName: "ellipsis")
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44, height: 44)
                .accessibilityLabel("更多操作")
        }
    }

    /// 多球形 drill：逐组选择本组打的球形（契约 §4.1 球形维度）。
    private var formationColumn: some View {
        BTFormationMenu(
            options: formationOptions,
            token: $setData.formationToken,
            name: $setData.formationName,
            accessibilityText: "第\(setData.id)组球形：\(setData.formationName ?? "未选择")"
        )
    }

    private var timerColumn: some View {
        Group {
            if setData.isCompleted, let duration = setData.duration {
                Text(Self.formatDuration(duration))
                    .font(.btCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(.btTextSecondary)
            } else {
                Text("-")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var successRateColumn: some View {
        Group {
            if setData.isCompleted, setData.targetBalls > 0 {
                let rate = Double(setData.madeBalls) / Double(setData.targetBalls)
                Text("\(Int(rate * 100))%")
                    .font(.btCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(Self.rateColor(rate))
            } else {
                Text("-")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private static func rateColor(_ rate: Double) -> Color {
        if rate >= 0.9 { return .btSuccess }
        if rate >= 0.7 { return .btPrimary }
        return .btTextSecondary
    }

    private var borderColor: Color {
        switch rowState {
        case .active: return .btPrimary
        case .completed: return .btSeparator
        case .pending: return .btSeparator
        }
    }
}

// MARK: - Formation Menu

/// 球形选择菜单：训练录入表格与历史「编辑数据」共用同一组件，保证两处的视觉与
/// 写入语义一致 —— 选中一个球形即同时写 token 与**当时的显示名**（契约 §6.5）。
struct BTFormationMenu: View {
    let options: [DrillFormationOption]
    @Binding var token: String?
    @Binding var name: String?
    var accessibilityText: String

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    token = option.token
                    name = option.name
                } label: {
                    if token == option.token {
                        Label(option.name, systemImage: BTIcon.checkmark)
                    } else {
                        Text(option.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(name.map { DrillFormationOption(token: "", name: $0).shortLabel } ?? "选择")
                    .font(.btCaption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(name == nil ? .btTextTertiary : .btPrimary)
                Image(systemName: BTIcon.chevronDown)
                    .font(.btMicro)
                    .foregroundStyle(.btTextTertiary)
            }
            // 球形列是行内唯一的可变宽文本列，却和纯数字列平分弹性空间，分到的宽度只比
            // 标签固有宽度多 1–2 pt。SF Pro 的比例数字里「2」比「1」宽，于是同为三字的
            // 「球形1」（固有 31.3 pt）放得下、「球形2」放不下被截成「…」——同宽文本部分行
            // 截断的成因在此，与行状态无关。固定为固有宽度，让弹性数字列让出这几 pt。
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - RowState conformance for external use
extension BTSetInputGrid.RowState: Sendable {}

// MARK: - Preview

#Preview("BTSetInputGrid Light") {
    SetInputGridPreview()
        .background(Color.btBG)
}

#Preview("BTSetInputGrid Dark") {
    SetInputGridPreview()
        .background(Color.btBG)
        .preferredColorScheme(.dark)
}

#Preview("BTSetInputGrid Empty") {
    SetInputGridEmptyPreview()
        .background(Color.btBG)
}

private struct SetInputGridPreview: View {
    @State private var sets: [DrillSetData] = [
        DrillSetData(id: 1, madeBalls: 15, targetBalls: 15, isCompleted: true),
        DrillSetData(id: 2, madeBalls: 12, targetBalls: 15, isCompleted: true),
        DrillSetData(id: 3, madeBalls: 14, targetBalls: 15),
        DrillSetData(id: 4, targetBalls: 15),
        DrillSetData(id: 5, targetBalls: 15),
    ]

    var body: some View {
        BTSetInputGrid(
            sets: $sets,
            onAddSet: { sets.append(DrillSetData(id: sets.count + 1, targetBalls: 15)) },
            onComplete: { sets[$0].isCompleted.toggle() }
        )
        .padding(Spacing.lg)
    }
}

private struct SetInputGridEmptyPreview: View {
    @State private var sets: [DrillSetData] = []

    var body: some View {
        BTSetInputGrid(
            sets: $sets,
            onAddSet: { sets.append(DrillSetData(id: 1, targetBalls: 15)) },
            onComplete: { _ in }
        )
        .padding(Spacing.lg)
    }
}
