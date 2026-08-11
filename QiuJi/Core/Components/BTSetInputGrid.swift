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
    /// 本组训练模式：重复型一组 = 重复某一杆（行标签「杆N」）；
    /// 走位链一组 = 整链一遍（行标签「遍N」）。nil 时回落纯组号。
    var mode: DrillContent.DoseMode?
    /// 重复型：本组重复的是序列第几杆（1-based）。展示层信息，不落库；
    /// nil 时行标签回落分节内序号。走位链 / 无模式恒为 nil。
    var shotIndex: Int?
    /// 计划自带组的球形是既定事实，不可改选（v34 后续）；手动新增组保持可选。
    var isFormationLocked: Bool

    init(id: Int, madeBalls: Int = 0, targetBalls: Int = 15, isCompleted: Bool = false, isWarmup: Bool = false, duration: TimeInterval? = nil,
         formationToken: String? = nil, formationName: String? = nil, mode: DrillContent.DoseMode? = nil,
         shotIndex: Int? = nil, isFormationLocked: Bool = false) {
        self.id = id
        self.madeBalls = madeBalls
        self.targetBalls = targetBalls
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
        self.duration = duration
        self.formationToken = formationToken
        self.formationName = formationName
        self.mode = mode
        self.shotIndex = shotIndex
        self.isFormationLocked = isFormationLocked
    }
}

/// 「添加一组」的可选目标（v34 后续）：多球形 drill 先选球形，重复型再选第几杆；
/// 走位链一组 = 整链一遍，无杆数维度。
struct DrillAddSetChoice: Identifiable {
    /// 球形 token；单球形 drill 为 nil（契约 §4.1，落库同口径）。
    let token: String?
    /// 球形显示名（快照落库用）；单球形为 nil。
    let name: String?
    let mode: DrillContent.DoseMode?
    /// 序列杆数：重复型 = 可选位置数；走位链仅作展示参考。
    let shotCount: Int
    /// 该球形一组的默认目标球数。
    let targetBalls: Int
    /// 序号制展示名（「球形N」，来自 `DrillTryoutFormation.displayName` 映射）；
    /// nil 回落原始名短标签。
    var displayName: String? = nil

    var id: String { token ?? "_single" }

    /// 菜单短标签（「球形1」式）。
    var menuLabel: String {
        if let displayName { return displayName }
        guard let name else { return "本球形" }
        return DrillFormationOption(token: token ?? "", name: name).shortLabel
    }
}

/// 录入时可选的球形（来自 `DrillTryoutBoardStore.formations(for:)`）。
struct DrillFormationOption: Identifiable, Hashable {
    let token: String
    let name: String
    /// 序号制展示名（「球形N」，来自 `DrillTryoutFormation.displayName` 映射）；
    /// nil 回落原始名短标签。
    var displayName: String? = nil

    var id: String { token }

    /// 列表用短标签：序列名形如「中袋角度精准 · 球形2」，取「·」后一段避免撑爆行宽。
    var shortLabel: String {
        guard let tail = name.split(separator: "·").last, name.contains("·") else { return name }
        return tail.trimmingCharacters(in: .whitespaces)
    }

    /// 用户可见标签：优先序号制映射名。
    var displayLabel: String { displayName ?? shortLabel }
}

/// 展示层球形名映射：优先按 token 命中 `options` 的序号制映射名；
/// 命不中（旧快照 / 选项缺失）回落落库原始名的短标签。
func formationDisplayLabel(
    token: String?, name: String?, options: [DrillFormationOption]
) -> String? {
    if let token, let hit = options.first(where: { $0.token == token }) {
        return hit.displayLabel
    }
    guard let name else { return nil }
    return DrillFormationOption(token: "", name: name).shortLabel
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
    /// 「添加一组」的结构化选项（球形 × 杆）；非空时加号出菜单，
    /// 选择结果走 `onAddSetChoice`。为空回落 `onAddSet` 直接追加。
    var addSetChoices: [DrillAddSetChoice] = []
    /// (choice, shotIndex)：重复型带选中的杆号；走位链 / 无模式为 nil。
    var onAddSetChoice: ((DrillAddSetChoice, Int?) -> Void)? = nil

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

    /// 模式感知行标签：重复型「杆N」优先取组自带 `shotIndex`（真实杆位，手动加组
    /// 可指定），缺失回落分节内序号；走位链「遍N」= 整链第 N 遍；无模式回落纯组号。
    private func rowLabel(for set: DrillSetData, ordinal: Int) -> String? {
        switch set.mode {
        case .repetition: return "杆\(set.shotIndex ?? ordinal)"
        case .sequence: return "遍\(ordinal)"
        case .none: return nil
        }
    }

    private func sectionTitle(token: String, name: String?, ordinal: Int) -> String {
        // 序号制映射名优先（token 命中选项）；旧快照回落落库原始名。
        if let mapped = formationDisplayLabel(token: token.isEmpty ? nil : token,
                                              name: name, options: formationOptions) {
            return mapped
        }
        if let name, !name.isEmpty { return name }
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
                        ForEach(Array(section.indices.enumerated()), id: \.element) { ordinal, index in
                            SetRow(
                                setData: $sets[index],
                                rowState: rowState(for: index),
                                rowLabel: rowLabel(for: sets[index], ordinal: ordinal + 1),
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
                // 与列内容（左对齐的球形名）同一起点。
                Text("球形")
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    /// 是否需要出选择菜单：任一选项存在杆数选择（重复型多杆）或有多个球形可选。
    private var needsAddMenu: Bool {
        guard onAddSetChoice != nil, !addSetChoices.isEmpty else { return false }
        if addSetChoices.count > 1 { return true }
        let only = addSetChoices[0]
        return only.mode == .repetition && only.shotCount > 1
    }

    @ViewBuilder
    private var addButton: some View {
        if needsAddMenu {
            Menu {
                if addSetChoices.count == 1, let only = addSetChoices.first {
                    // 单球形重复型：杆号直接平铺，不多包一层球形子菜单。
                    ForEach(1...max(1, only.shotCount), id: \.self) { shot in
                        Button("杆\(shot)") {
                            onAddSetChoice?(only, shot)
                        }
                    }
                } else {
                    ForEach(addSetChoices) { choice in
                        addMenuEntry(for: choice)
                    }
                }
            } label: {
                addButtonLabel
            }
            .accessibilityLabel("添加一组")
        } else {
            Button {
                // 单一无杆数维度的选项（如单球形走位链）直接落该选项，保留球形快照。
                if let choice = addSetChoices.first, let onAddSetChoice {
                    onAddSetChoice(choice, choice.mode == .repetition ? 1 : nil)
                } else {
                    onAddSet()
                }
            } label: {
                addButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加一组")
        }
    }

    private var addButtonLabel: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "plus")
            Text("添加一组")
        }
        .font(.btCallout)
        .foregroundStyle(.btPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    /// 单个球形的菜单项：重复型出「杆1…杆N」子菜单（选打哪一杆）；
    /// 走位链一组 = 整链一遍，直接一项。
    @ViewBuilder
    private func addMenuEntry(for choice: DrillAddSetChoice) -> some View {
        if choice.mode == .repetition, choice.shotCount > 1 {
            Menu(choice.menuLabel) {
                ForEach(1...choice.shotCount, id: \.self) { shot in
                    Button("杆\(shot)") {
                        onAddSetChoice?(choice, shot)
                    }
                }
            }
        } else {
            Button {
                onAddSetChoice?(choice, choice.mode == .repetition ? 1 : nil)
            } label: {
                if choice.mode == .sequence {
                    Text("\(choice.menuLabel) · 整链一遍")
                } else {
                    Text(choice.menuLabel)
                }
            }
        }
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
    /// 模式感知标签（「杆N」/「遍N」）；nil 回落纯组号。
    var rowLabel: String? = nil
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
        .accessibilityLabel(rowAccessibilityLabel)
    }

    /// 锁定球形的组：球形列是静态文本，会被本覆盖标签吞掉，故并入行标签
    /// （可选球形的组仍由 `BTFormationMenu` 自带「第N组球形：…」按钮元素）。
    private var rowAccessibilityLabel: String {
        var label = "\(rowLabel ?? "第\(setData.id)组"), \(setData.madeBalls)/\(setData.targetBalls)球"
        if setData.isFormationLocked,
           let mapped = formationDisplayLabel(token: setData.formationToken,
                                              name: setData.formationName,
                                              options: formationOptions) {
            label += ", 球形：\(mapped)"
        }
        return label
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
            } else if let rowLabel {
                Text(rowLabel)
                    .font(.btFootnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
    /// 计划自带组的球形是计划既定事实 → 静态文本；仅手动新增组可改选。
    /// 锁定/可选两态的球形名统一走序号制映射（token → 「球形N」）。
    private var formationDisplayText: String? {
        formationDisplayLabel(token: setData.formationToken,
                              name: setData.formationName,
                              options: formationOptions)
    }

    @ViewBuilder
    private var formationColumn: some View {
        if setData.isFormationLocked {
            // 与可选态的菜单标签同为左对齐，两态文字起点一致。
            Text(formationDisplayText ?? "-")
                .font(.btCaption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 36)
                .accessibilityLabel("第\(setData.id)组球形：\(formationDisplayText ?? "未选择")（预设）")
        } else {
            BTFormationMenu(
                options: formationOptions,
                token: $setData.formationToken,
                name: $setData.formationName,
                accessibilityText: "第\(setData.id)组球形：\(formationDisplayText ?? "未选择")"
            )
        }
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

    /// 用户可见标签统一走序号制映射（token 优先，旧快照名回落短标签）。
    private var selectedLabel: String? {
        formationDisplayLabel(token: token, name: name, options: options)
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    token = option.token
                    name = option.name
                } label: {
                    if token == option.token {
                        Label(option.displayLabel, systemImage: BTIcon.checkmark)
                    } else {
                        Text(option.displayLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(selectedLabel ?? "选择")
                    .font(.btCaption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(selectedLabel == nil ? .btTextTertiary : .btPrimary)
                // 已选定的组不再出下拉角标（仍可点开改选）；未选态保留引导角标。
                if selectedLabel == nil {
                    Image(systemName: BTIcon.chevronDown)
                        .font(.btMicro)
                        .foregroundStyle(.btTextTertiary)
                }
            }
            // 球形列是行内唯一的可变宽文本列，却和纯数字列平分弹性空间，分到的宽度只比
            // 标签固有宽度多 1–2 pt。SF Pro 的比例数字里「2」比「1」宽，于是同为三字的
            // 「球形1」（固有 31.3 pt）放得下、「球形2」放不下被截成「…」——同宽文本部分行
            // 截断的成因在此，与行状态无关。固定为固有宽度，让弹性数字列让出这几 pt。
            // 左对齐与锁定态静态文本起点一致（v34 后续）。
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
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
