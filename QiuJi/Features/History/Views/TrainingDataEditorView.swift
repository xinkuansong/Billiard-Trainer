import SwiftUI
import SwiftData

// MARK: - Draft

/// 「编辑数据」的可编辑面：**只含这条历史记录自身的成绩数据**。
///
/// 契约 §6.5：`drillNameZh` / `criteriaText` / `unitLabel` / `passMade` / `passTotal`
/// 是写入即冻结的快照，本编辑器只读展示、不回查当前 drill 内容重建。
/// `formationToken/formationName` 例外——改它表示「这组打的其实是另一个球形」，
/// 属用户修正当时的录入错误，故选中球形时把**该球形当时的显示名**一并写入。
struct TrainingDataDraft: Equatable {

    struct SetDraft: Identifiable, Equatable {
        /// `DrillSet.id`
        let id: UUID
        let setNumber: Int
        /// 快照，只读，用于给输入框标单位。
        let unitLabel: String
        var madeText: String
        var targetText: String
        /// 每组用时（秒）；空串表示未记录（写回 nil）。
        var durationText: String
        var formationToken: String?
        var formationName: String?
    }

    struct EntryDraft: Identifiable, Equatable {
        /// `DrillEntry.id`
        let id: UUID
        let drillId: String
        /// 快照，只读。
        let drillNameZh: String
        /// 快照，只读。
        let criteriaText: String
        let formationOptions: [DrillFormationOption]
        var sets: [SetDraft]
    }

    var entries: [EntryDraft]

    // MARK: Build

    /// 多球形 drill 的可选球形；单球形（或无序列）返回空数组，不出球形列。
    /// 与录入侧 `ActiveTrainingViewModel.formationOptions(for:)` 同规则——那边是
    /// `@MainActor` 隔离的，这里的草稿构造要在非隔离上下文可用，故各自持有一份调用。
    static func formationOptions(for drillId: String) -> [DrillFormationOption] {
        let formations = DrillTryoutBoardStore.formations(for: drillId)
        guard formations.count > 1 else { return [] }
        return formations.map {
            DrillFormationOption(token: $0.token, name: $0.title, displayName: $0.displayName)
        }
    }

    init(
        session: TrainingSession,
        formationProvider: (String) -> [DrillFormationOption] = { Self.formationOptions(for: $0) }
    ) {
        // orderIndex 是 W4 之后才写的；旧库统一为 0，用原数组下标兜底保证顺序稳定。
        let orderedEntries = session.drillEntries.enumerated()
            .sorted { ($0.element.orderIndex, $0.offset) < ($1.element.orderIndex, $1.offset) }
            .map(\.element)

        entries = orderedEntries.map { entry in
            EntryDraft(
                id: entry.id,
                drillId: entry.drillId,
                drillNameZh: entry.drillNameZh,
                criteriaText: entry.criteriaText,
                formationOptions: formationProvider(entry.drillId),
                sets: entry.sets
                    .sorted { $0.setNumber < $1.setNumber }
                    .map { drillSet in
                        SetDraft(
                            id: drillSet.id,
                            setNumber: drillSet.setNumber,
                            unitLabel: drillSet.unitLabel,
                            madeText: "\(drillSet.madeBalls)",
                            targetText: "\(drillSet.targetBalls)",
                            durationText: drillSet.durationSeconds.map { "\($0)" } ?? "",
                            formationToken: drillSet.formationToken,
                            formationName: drillSet.formationName
                        )
                    }
            )
        }
    }

    // MARK: Validation

    enum Field { case made, target, duration }

    /// 单组的校验信息；nil 表示合法。
    static func error(for set: SetDraft) -> (field: Field, message: String)? {
        guard let target = Int(set.targetText.trimmingCharacters(in: .whitespaces)), target > 0 else {
            return (.target, "总数需为大于 0 的整数")
        }
        let madeRaw = set.madeText.trimmingCharacters(in: .whitespaces)
        let made = madeRaw.isEmpty ? 0 : Int(madeRaw)
        guard let made, made >= 0 else {
            return (.made, "进球数需为 0 或正整数")
        }
        if made > target {
            return (.made, "进球数不能大于总数（\(target)）")
        }
        let durationRaw = set.durationText.trimmingCharacters(in: .whitespaces)
        if !durationRaw.isEmpty {
            guard let seconds = Int(durationRaw), seconds >= 0 else {
                return (.duration, "用时需为 0 或正整数秒，留空表示未记录")
            }
        }
        return nil
    }

    /// 所有不合法的组：`DrillSet.id` → 提示文案。
    var validationErrors: [UUID: String] {
        var result: [UUID: String] = [:]
        for entry in entries {
            for set in entry.sets where Self.error(for: set) != nil {
                result[set.id] = Self.error(for: set)?.message
            }
        }
        return result
    }

    var isValid: Bool { validationErrors.isEmpty }

    // MARK: Apply

    enum ApplyError: LocalizedError {
        case invalidInput(count: Int)

        var errorDescription: String? {
            switch self {
            case .invalidInput(let count):
                return "有 \(count) 处数据不合法，请先修正标红的组。"
            }
        }
    }

    /// 把草稿写回模型对象。**只写成绩面**，快照字段一律不动。
    /// 调用方负责随后 `modelContext.save()`。
    func apply(to session: TrainingSession) throws {
        let errors = validationErrors
        guard errors.isEmpty else { throw ApplyError.invalidInput(count: errors.count) }

        var setsById: [UUID: DrillSet] = [:]
        for entry in session.drillEntries {
            for drillSet in entry.sets { setsById[drillSet.id] = drillSet }
        }

        for entry in entries {
            for setDraft in entry.sets {
                guard let model = setsById[setDraft.id] else { continue }
                let target = Int(setDraft.targetText.trimmingCharacters(in: .whitespaces)) ?? model.targetBalls
                let madeRaw = setDraft.madeText.trimmingCharacters(in: .whitespaces)
                let made = madeRaw.isEmpty ? 0 : (Int(madeRaw) ?? model.madeBalls)
                model.targetBalls = target
                model.madeBalls = made

                let durationRaw = setDraft.durationText.trimmingCharacters(in: .whitespaces)
                model.durationSeconds = durationRaw.isEmpty ? nil : Int(durationRaw)

                model.formationToken = setDraft.formationToken
                model.formationName = setDraft.formationName
            }
        }
    }
}

// MARK: - Editor View

/// 历史详情页「编辑数据」：编辑这条记录自身的每组成绩、用时与球形归属。
///
/// 本轮不开放「新增/删除组」与 session 级字段（日期 / 球种 / 计划归属）。
struct TrainingDataEditorView: View {
    let session: TrainingSession
    /// 保存回调。返回 nil 表示成功（编辑器自行关闭）；返回非 nil 时把该文案弹给用户，
    /// 编辑器保持打开，避免用户的修改因一次失败而丢失。
    let onSave: (TrainingDataDraft) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TrainingDataDraft
    @State private var saveError: String?

    init(session: TrainingSession, onSave: @escaping (TrainingDataDraft) -> String?) {
        self.session = session
        self.onSave = onSave
        _draft = State(initialValue: TrainingDataDraft(session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ForEach($draft.entries) { $entry in
                        entryCard($entry)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.btBG)
            .navigationTitle("编辑数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityIdentifier("dataEditorCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("dataEditorSave")
                }
            }
            .alert("无法保存", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                if let saveError { Text(saveError) }
            }
        }
    }

    // MARK: Entry card

    private func entryCard(_ entry: Binding<TrainingDataDraft.EntryDraft>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                BTDrillListThumbnail(drillId: entry.wrappedValue.drillId)
                VStack(alignment: .leading, spacing: 2) {
                    // 快照文本：只读展示，不随当前 drill 内容变化（契约 §6.5）。
                    Text(entry.wrappedValue.drillNameZh)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    if !entry.wrappedValue.criteriaText.isEmpty {
                        Text(entry.wrappedValue.criteriaText)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            columnHeader(showFormation: !entry.wrappedValue.formationOptions.isEmpty)

            ForEach(entry.sets) { $set in
                setEditorRow($set, options: entry.wrappedValue.formationOptions)
                if set.id != entry.wrappedValue.sets.last?.id {
                    Divider().foregroundStyle(.btSeparator)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func columnHeader(showFormation: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("组").frame(width: 36, alignment: .leading)
            Text("进球").frame(maxWidth: .infinity)
            Text("总数").frame(maxWidth: .infinity)
            Text("用时秒").frame(maxWidth: .infinity)
            if showFormation {
                Text("球形").frame(maxWidth: .infinity)
            }
        }
        .font(.btCaption)
        .foregroundStyle(.btTextSecondary)
    }

    // MARK: Set row

    private func setEditorRow(
        _ set: Binding<TrainingDataDraft.SetDraft>,
        options: [DrillFormationOption]
    ) -> some View {
        let issue = TrainingDataDraft.error(for: set.wrappedValue)
        let number = set.wrappedValue.setNumber
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text("第\(number)组")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 36, alignment: .leading)

                numberField(
                    text: set.madeText,
                    placeholder: "0",
                    isInvalid: issue?.field == .made,
                    identifier: "editSetMade_\(number)",
                    label: "第\(number)组进球数"
                )
                numberField(
                    text: set.targetText,
                    placeholder: "1",
                    isInvalid: issue?.field == .target,
                    identifier: "editSetTarget_\(number)",
                    label: "第\(number)组总数"
                )
                numberField(
                    text: set.durationText,
                    placeholder: "—",
                    isInvalid: issue?.field == .duration,
                    identifier: "editSetDuration_\(number)",
                    label: "第\(number)组用时秒"
                )

                if !options.isEmpty {
                    BTFormationMenu(
                        options: options,
                        token: set.formationToken,
                        name: set.formationName,
                        accessibilityText: "第\(number)组球形：\(formationDisplayLabel(token: set.wrappedValue.formationToken, name: set.wrappedValue.formationName, options: options) ?? "未选择")"
                    )
                }
            }

            if let issue {
                Text(issue.message)
                    .font(.btCaption)
                    .foregroundStyle(.btDestructive)
                    .accessibilityIdentifier("editSetError_\(number)")
            }
        }
    }

    private func numberField(
        text: Binding<String>,
        placeholder: String,
        isInvalid: Bool,
        identifier: String,
        label: String
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.btSubheadline)
            .foregroundStyle(.btText)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.btBGTertiary.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isInvalid ? Color.btDestructive : Color.btSeparator,
                            lineWidth: isInvalid ? 1.5 : 1)
            )
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
    }

    // MARK: Save

    private func save() {
        let errors = draft.validationErrors
        guard errors.isEmpty else {
            saveError = TrainingDataDraft.ApplyError.invalidInput(count: errors.count)
                .errorDescription
            return
        }
        if let message = onSave(draft) {
            saveError = message
        } else {
            dismiss()
        }
    }
}
