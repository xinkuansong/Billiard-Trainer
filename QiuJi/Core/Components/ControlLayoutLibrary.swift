import SwiftUI

extension TablePreferencePage {
    var layoutTitle: String {
        switch self {
        case .dailyClearance: return "每日清台"
        case .freePlay: return "自由击球"
        case .shotSimulation: return "分离角与走位"
        case .snakePractice: return "蛇彩"
        case .composer: return "自由走位"
        case .drillTryout: return "动作详情试打"
        case .silu: return "思路训练"
        case .planThree: return "打一走二想三"
        case .snookerTactics: return "防守"
        case .bankShot: return "翻袋"
        case .diamondSystem: return "颗星"
        case .angleDynamic: return "角度与瞄准"
        case .separationAngleAtlas: return "分离角图谱"
        case .cushionEnglishAtlas: return "加塞吃库图谱"
        case .sceneAiming2D: return "2D角度训练"
        case .sceneAiming3D: return "3D角度训练"
        case .aimPointScene2D: return "2D瞄准点训练"
        case .aimPointScene3D: return "3D瞄准点训练"
        default: return rawValue
        }
    }
}
extension ControlLayoutFamily {
    var title: String {
        switch self {
        case .shot: return "击球"
        case .planning: return "规划与求解"
        case .teaching: return "交互教学"
        case .angleQuiz: return "角度答题"
        case .aimPointQuiz: return "瞄准点答题"
        }
    }
    var pages: [TablePreferencePage] { TablePreferencePage.allCases.filter { $0.controlLayoutFamily == self } }
}
extension ControlLayoutAddress {
    var summary: String {
        let mode = layer == .common ? "共用" : (layer == .twoD ? "2D" : "3D")
        let field: String
        switch property {
        case .lane: field = "左右位置"
        case .offset: field = "上下位置"
        case .order: field = "组间顺序"
        case .size: field = "尺寸"
        case .cameraSlot: field = "相机位置"
        }
        return "\(domain.title) · \(mode) · \(group.title) · \(field)"
    }
}

/// Personal-library management has no implicit current page and never applies a template.
struct ControlLayoutLibrary: View {
    @ObservedObject private var store = FreeControlLayoutStore.shared
    @State private var renaming: FreeControlTemplate?
    @State private var deleting: FreeControlTemplate?
    @State private var name = ""
    @State private var recovery = false
    @State private var failure: String?
    @State private var backedUpLegacy = false
    var body: some View {
        List {
            if let error = store.loadError {
                Section("布局暂不可用") {
                    Text(error)
                    Button("重试读取") { store.reload() }
                    Button("备份后恢复默认", role: .destructive) { recovery = true }
                }
            }
            Section {
                if store.archive.templates.isEmpty { Text("暂无个人模板") }
                ForEach(store.archive.templates.sorted { $0.createdAt > $1.createdAt }) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(template.displayName)
                            Text(TablePreferencePage(rawValue: template.sourcePage)?.layoutTitle ?? template.sourcePage)
                                .font(.btCaption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("改名") { name = template.baseName; renaming = template }
                            Button("删除", role: .destructive) { deleting = template }
                        } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("管理 " + template.displayName)
                        .accessibilityIdentifier("freeLibrary.actions." + template.id.uuidString)
                    }
                }
            } header: { Text("个人模板") } footer: {
                Text("到相应练习页面的“更多 → 操作布局”中使用或调整。改名和删除不会改变已经使用的页面布局。")
            }
            if store.legacyArchive != nil || store.legacyError != nil {
                Section("旧版归档") {
                    if let error = store.legacyError { Text(error) }
                    if store.archive.legacyImportDisabled == true {
                        Text("已恢复新版默认。旧归档仍保留，未自动重新应用。")
                    } else {
                        Text("旧记录按实际页面、模式和窗口测量后转换。未取得对应测量的记录保留在旧归档中，不会用猜测位置覆盖当前布局。")
                    }
                    ForEach((store.legacyArchive?.templates.values.map { $0 } ?? []).sorted { $0.name < $1.name }) { template in
                        Text("原模板：" + template.name)
                    }
                    ForEach((store.archive.legacyRecords?.values.map { $0 } ?? []).sorted { $0.id < $1.id }) { record in
                        VStack(alignment: .leading) {
                            Text(record.name + " · " + record.mode.title)
                            Text(record.detail).font(.btCaption).foregroundStyle(.secondary)
                        }
                    }
                    Button("重新读取旧归档") { store.reloadLegacy() }
                    Button(backedUpLegacy ? "旧归档已备份" : "备份旧归档") {
                        do { try store.backUpLegacy(); backedUpLegacy = true }
                        catch { failure = error.localizedDescription }
                    }.disabled(backedUpLegacy)
                }
            }
        }
        .navigationTitle("操作布局").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("freeLibrary")
        .preference(key: TrainingActivityPausedKey.self, value: true)
        .onAppear { store.reload(); store.reloadLegacy() }
        .alert("修改名称 · " + (renaming?.mode.title ?? ""), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("模板名称", text: $name).accessibilityIdentifier("freeLibrary.name")
            Button("取消", role: .cancel) { renaming = nil }
            Button("保存") {
                guard let template = renaming else { return }
                do { try store.rename(template, to: name); renaming = nil }
                catch { failure = error.localizedDescription }
            }
        }
        .confirmationDialog("删除这个个人模板？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                guard let template = deleting else { return }
                do { try store.delete(template); deleting = nil }
                catch { failure = error.localizedDescription }
            }
        } message: { Text("已应用到各页面的布局将继续保留。") }
        .confirmationDialog("备份现有归档并恢复默认？", isPresented: $recovery, titleVisibility: .visible) {
            Button("备份并恢复", role: .destructive) {
                do { try store.recoverWithDefault() } catch { failure = error.localizedDescription }
            }
        } message: { Text("个人模板和页面自定义布局将从当前库中移除；原始归档保留在本机备份中。") }
        .alert("操作未完成", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("好", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }
}

private struct ControlLayoutReviewRequest: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let pages: [TablePreferencePage]
    let archive: ControlLayoutArchive
    let perform: () throws -> Void
}
private struct ControlLayoutReviewSheet: View {
    let request: ControlLayoutReviewRequest
    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            List {
                Section { Text(request.detail) }
                Section("影响页面") {
                    if request.pages.isEmpty { Text("当前没有页面引用") }
                    ForEach(request.pages, id: \.self) { page in
                        VStack(alignment: .leading) {
                            Text(page.layoutTitle)
                            Text("保留\(request.archive.bindings[page]?.overrides.count ?? 0)项本页微调")
                                .font(.btCaption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let failure { Section { Text(failure).foregroundStyle(.red) } }

            }.navigationTitle(request.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确认") { do { try request.perform(); dismiss() } catch { failure = error.localizedDescription } }
                            .accessibilityIdentifier("layoutReview.confirm")
                    }
                }
        }
    }
}

private struct ControlLayoutFamilyDetail: View {
    let family: ControlLayoutFamily
    @ObservedObject private var store = ControlLayoutStore.shared
    @State private var review: ControlLayoutReviewRequest?
    var body: some View {
        List {
            Section("分类默认") {
                Text(store.archive.familyDefaults[family].flatMap { store.archive.templates[$0]?.name } ?? "球迹默认")
                Menu {
                    Button("球迹默认") { setDefault(nil) }
                    ForEach(store.archive.templates.values.sorted { $0.name < $1.name }) { template in
                        Button(template.name) { setDefault(template.id) }
                    }
                } label: {
                    HStack { Text("更换默认模板"); Spacer(); Image(systemName: "chevron.up.chevron.down") }
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }.disabled(!family.pages.contains(where: \.supportsControlLayoutEditing))
                Text("只影响跟随本类默认的页面，显式选择模板和本页微调保持原值。")
                    .font(.btCaption).foregroundStyle(.secondary)
            }
            Section("页面") {
                ForEach(family.pages, id: \.self) { page in
                    VStack(alignment: .leading) {
                        Text(page.layoutTitle)
                        Text(page.supportsControlLayoutEditing ? bindingTitle(page) : "尚未支持")
                            .font(.btCaption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle(family.title).sheet(item: $review) { ControlLayoutReviewSheet(request: $0) }
    }
    private func bindingTitle(_ page: TablePreferencePage) -> String {
        let name = store.archive.templateID(for: page).flatMap { store.archive.templates[$0]?.name } ?? "球迹默认"
        let follows = (store.archive.bindings[page]?.selection ?? .familyDefault) == .familyDefault
        return "\(follows ? "跟随分类默认：" : "独立选择：")\(name) · \(store.archive.bindings[page]?.overrides.count ?? 0)项微调"
    }
    private func setDefault(_ id: UUID?) {
        let archive = store.archive
        review = .init(title: "更换分类默认", detail: "改为\(id.flatMap { archive.templates[$0]?.name } ?? "球迹默认")；不清除本页微调。",
            pages: family.pages.filter { ($0.supportsControlLayoutEditing) && (archive.bindings[$0]?.selection ?? .familyDefault) == .familyDefault }, archive: archive,
            perform: { try store.setFamilyDefault(family, template: id, expectedRevision: archive.revision) })
    }
}

private struct ControlLayoutTemplateDetail: View {
    let templateID: UUID?
    @ObservedObject private var store = ControlLayoutStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var naming = false
    @State private var renaming = false
    @State private var nameRevision: UInt64 = 0
    @State private var failure: String?
    @State private var applying = false
    @State private var previewing = false
    @State private var review: ControlLayoutReviewRequest?
    private var template: ControlLayoutTemplate? { templateID.flatMap { store.archive.templates[$0] } }
    private var references: [TablePreferencePage] {
        TablePreferencePage.allCases.filter { $0.controlLayoutFamily != nil && store.archive.templateID(for: $0) == templateID }
    }
    var body: some View {
        detailList.navigationTitle(template?.name ?? "球迹默认").navigationBarTitleDisplayMode(.inline)
            .accessibilityHidden(previewing)
            .sheet(isPresented: $applying) { ControlLayoutApplySheet(selection: templateID.map(ControlLayoutSelection.template) ?? .builtIn, archive: store.archive) }
            .background(ControlLayoutPreviewPresentation(isPresented: $previewing, templateID: templateID).frame(width: 0, height: 0))
            .sheet(item: $review) { ControlLayoutReviewSheet(request: $0) }
            .alert(renaming ? "重命名模板" : "复制模板", isPresented: $naming) {
                TextField("模板名称", text: $name)
                Button("取消", role: .cancel) { }
                Button("保存") {
                    do {
                        if renaming, let templateID { try store.rename(templateID, name: name, expectedRevision: nameRevision) }
                        else { try store.copy(templateID, id: UUID(), name: name, expectedRevision: nameRevision) }
                    } catch { failure = error.localizedDescription }
                }
            }
            .alert("操作未完成", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("重新载入") { store.reload() }
                Button("好", role: .cancel) { }
            } message: { Text(failure ?? "") }
    }
    private var detailList: some View {
        List {
            if templateID != nil && template == nil {
                Text("模板已被删除，请返回模板库。")
            } else {
                Section {
                    Text(templateID == nil ? "各页面原生布局" : "独立模板 · 第\(template?.revision ?? 1)版")
                    Button("预览与编辑") { previewing = true }.accessibilityIdentifier("layoutLibrary.edit")
                    Button("应用到页面") { applying = true }.accessibilityIdentifier("layoutLibrary.apply")
                    Button("复制为新模板") { beginNaming(rename: false) }
                    if templateID != nil { Button("重命名") { beginNaming(rename: true) } }
                }
                Section("引用页面") {
                    if references.isEmpty { Text("暂无页面引用") }
                    ForEach(references, id: \.self) { page in
                        Text("\(page.layoutTitle) · \(store.archive.bindings[page]?.overrides.count ?? 0)项本页微调")
                    }
                }
                if let template {
                    Section("已保存的调整") {
                        if template.values.isEmpty { Text("所有方向均使用原生默认") }
                        ForEach(template.values.keys.sorted { $0.summary < $1.summary }, id: \.self) { key in Text(key.summary + "：" + (template.values[key]?.layoutDescription ?? "默认")).font(.btCaption) }
                    }
                    Section {
                        Menu {
                            Button("引用页面改用球迹默认", role: .destructive) { delete(replacement: nil) }
                            ForEach(store.archive.templates.values.filter { $0.id != template.id }.sorted { $0.name < $1.name }) { other in
                                Button("改用" + other.name) { delete(replacement: other.id) }
                            }
                        } label: {
                            HStack { Text("删除模板"); Spacer(); Image(systemName: "chevron.up.chevron.down") }
                                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                                .foregroundStyle(.red)
                        }.accessibilityIdentifier("layoutLibrary.delete")
                    }
                }
            }
        }
    }
    private func beginNaming(rename: Bool) {
        renaming = rename; name = (template?.name ?? "球迹默认") + (rename ? "" : " 副本")
        nameRevision = store.archive.revision; naming = true
    }
    private func delete(replacement: UUID?) {
        guard let templateID else { return }
        let archive = store.archive
        review = .init(title: "删除模板", detail: "全部引用（包括分类默认）改用\(replacement.flatMap { archive.templates[$0]?.name } ?? "球迹默认")，本页微调保留。", pages: references, archive: archive,
            perform: { try store.delete(templateID, replacingWith: replacement, expectedRevision: archive.revision); dismiss() })
    }
}

private struct ControlLayoutApplySheet: View {
    let selection: ControlLayoutSelection
    @State private var archive: ControlLayoutArchive
    @ObservedObject private var store = ControlLayoutStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pages: Set<TablePreferencePage> = []
    @State private var clear: Set<ControlLayoutAddress> = []
    @State private var failure: String?
    init(selection: ControlLayoutSelection, archive: ControlLayoutArchive) {
        self.selection = selection; _archive = State(initialValue: archive)
    }
    private var template: ControlLayoutTemplate? {
        if case .template(let id) = selection { return archive.templates[id] }
        return nil
    }
    private func inactiveCount(_ page: TablePreferencePage) -> Int {
        let groups: Set<ControlLayoutGroup>
        switch page.controlLayoutFamily {
        case .shot: groups = [.direction, .instrument, .primary, .replay, .camera]
        case .planning: groups = page == .snookerTactics ? [.planning, .instrument, .primary, .camera] : [.planning, .direction, .instrument, .primary, .camera]
        case .teaching: groups = page == .angleDynamic ? [.information, .camera] : [.information, .instrument, .camera]
        case .angleQuiz: groups = [.information, .primary, .keyboard, .camera]
        case .aimPointQuiz: groups = [.direction, .primary, .camera]
        default: groups = []
        }
        return template?.values.keys.filter { !groups.contains($0.group) }.count ?? 0
    }
    private var keys: [ControlLayoutAddress] {
        Set(pages.flatMap { Array(archive.bindings[$0]?.overrides.keys ?? [:].keys) }).sorted { $0.summary < $1.summary }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("选择页面") {
                    ForEach(TablePreferencePage.allCases.filter { $0.controlLayoutFamily != nil }, id: \.self) { page in
                        Toggle(isOn: Binding(get: { pages.contains(page) }, set: { if $0 { pages.insert(page) } else { pages.remove(page) } })) {
                            VStack(alignment: .leading) {
                                Text(page.layoutTitle)
                                Text(page.supportsControlLayoutEditing ? "保留\(archive.bindings[page]?.overrides.count ?? 0)项微调；\(inactiveCount(page))项不适用调整保留但不启用" : "尚未支持")
                                    .font(.btCaption).foregroundStyle(.secondary)
                            }
                        }.disabled(!page.supportsControlLayoutEditing).accessibilityIdentifier("layoutApply." + page.rawValue)
                    }
                }
                if !keys.isEmpty {
                    Section { ForEach(keys, id: \.self) { key in
                        Toggle(key.summary, isOn: Binding(get: { clear.contains(key) }, set: { if $0 { clear.insert(key) } else { clear.remove(key) } }))
                    } } header: { Text("清除所选本页微调") } footer: { Text("默认全部保留。仅勾选的精确属性会清除；其他方向和视图不受影响。") }
                }
                if let failure { Text(failure).foregroundStyle(.red) }

            }.navigationTitle("应用模板").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                Button("应用") {
                    do {
                        try store.apply(selection, to: pages, clearing: Dictionary(uniqueKeysWithValues: pages.map { ($0, clear) }), expectedRevision: archive.revision)
                        dismiss()
                    } catch { failure = error.localizedDescription }
                }.disabled(pages.isEmpty).accessibilityIdentifier("layoutApply.confirm")
                    }
                }
        }
    }
}

struct ControlLayoutPromotionSheet: View {
    let draft: ControlLayoutDraft
    let onSaved: () -> Void
    @ObservedObject private var store = ControlLayoutStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<ControlLayoutAddress> = []
    @State private var clearPromoted = true
    @State private var failure: String?
    @State private var conflicting = false
    @State private var copyName = "布局草稿副本"
    private var templateID: UUID? { draft.templateID ?? draft.preview.templateID(for: draft.page) }
    private var keys: [ControlLayoutAddress] {
        draft.binding.overrides.keys.filter { $0.domain == draft.domain }.sorted { $0.summary < $1.summary }
    }
    private var pages: [TablePreferencePage] {
        TablePreferencePage.allCases.filter { $0.controlLayoutFamily != nil && draft.base.templateID(for: $0) == templateID }
    }
    private var changed: Set<ControlLayoutAddress> {
        if !draft.isTemplateDraft { return selected }
        let old = templateID.flatMap { draft.base.templates[$0]?.values } ?? [:]
        return Set(old.keys).union(draft.binding.overrides.keys).filter { old[$0] != draft.binding.overrides[$0] }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(templateID.flatMap { draft.base.templates[$0]?.name } ?? "模板")
                    Text("更新后，引用页面在空闲时使用新版本。未使用的控件属性保留；本页微调优先于模板。")
                        .font(.btCaption).foregroundStyle(.secondary)
                }
                if !draft.isTemplateDraft {
                    Section("选择合入模板的属性") {
                        ForEach(keys, id: \.self) { key in
                            Toggle(key.summary + "：" + (draft.binding.overrides[key]?.layoutDescription ?? "默认"), isOn: Binding(get: { selected.contains(key) }, set: { if $0 { selected.insert(key) } else { selected.remove(key) } }))
                        }
                        Toggle("清除已合入的本页微调，继续跟随模板", isOn: $clearPromoted)
                        Text("未勾选的修改仅保存在本页，其他页面的微调全部保留。")
                            .font(.btCaption).foregroundStyle(.secondary)
                    }
                }
                Section("影响预览") {
                    if pages.isEmpty { Text("暂无页面引用") }
                    ForEach(pages, id: \.self) { page in
                        let local = page == draft.page && !draft.isTemplateDraft ? draft.binding.overrides : draft.base.bindings[page]?.overrides ?? [:]
                        let retained = local.filter { !(page == draft.page && !draft.isTemplateDraft && clearPromoted && selected.contains($0.key)) }
                        let covered = changed.filter { key in retained.keys.contains { $0.domain == key.domain && $0.group == key.group && $0.property == key.property && ($0.layer == .common || key.layer == .common || $0.layer == key.layer) } }.count
                        VStack(alignment: .leading) {
                            Text(page.layoutTitle)
                            Text("保留\(retained.count)项微调；\(covered)项更新仍可能被本页微调覆盖")
                                .font(.btCaption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let failure { Section { Text(failure).foregroundStyle(.red) } }
                if conflicting {
                    Section("保留草稿") {
                        TextField("副本名称", text: $copyName)
                        Button("另存副本并返回") {
                            do { try store.preserveCopy(draft, id: UUID(), name: copyName); dismiss(); onSaved() }
                            catch { failure = error.localizedDescription }
                        }
                        Text("副本独立保存，现有页面绑定不变。")
                    }
                }

            }.navigationTitle("更新共享模板").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                Button("确认更新") {
                    do {
                        if draft.isTemplateDraft { try store.saveTemplate(draft) }
                        else { try store.promote(draft, keys: selected, clearPromoted: clearPromoted) }
                        dismiss(); onSaved()
                    } catch { conflicting = (error as? ControlLayoutError) == .conflict; failure = error.localizedDescription }
                }.disabled(changed.isEmpty || conflicting).accessibilityIdentifier("layoutPromotion.confirm")
                    }
                }
                .onAppear { if selected.isEmpty { selected = Set(keys) } }
        }
    }
}

private struct LayoutPreviewMeasurements: PreferenceKey {
    static var defaultValue: [ControlLayoutGroup: CGRect] = [:]
    static func reduce(value: inout [ControlLayoutGroup: CGRect], nextValue: () -> [ControlLayoutGroup: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Native controls are measured in an independent sample. No training VM, scene,
/// timer, solver or submission callback is created by the settings preview.
private struct ControlLayoutLibraryPreview: View {
    let templateID: UUID?
    let onClose: () -> Void
    @State private var frames: [ControlLayoutGroup: CGRect] = [:]
    @State private var velocity = 1.5
    @State private var family: ControlLayoutFamily = .shot
    @State private var tracks = Set(0..<8)
    @State private var editing = false
    @State private var keyboardPreview = false
    @State private var answer = ""
    private var page: TablePreferencePage { family == .aimPointQuiz ? .aimPointScene2D : (family == .angleQuiz ? .sceneAiming2D : (family == .teaching ? .separationAngleAtlas : (family == .planning ? .silu : .dailyClearance))) }
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let foundation = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: proxy.safeAreaInsets.leading,
                trailingSafeArea: proxy.safeAreaInsets.trailing, halfLength: CameraRig.defaultTableOuterHalfLength,
                halfWidth: CameraRig.defaultTableOuterHalfWidth, instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight)
            let domain: ControlLayoutDomain = UIDevice.current.userInterfaceIdiom == .pad ? (size.height > size.width ? .padPortrait : .padLandscape) : .phoneLandscape
            ZStack(alignment: .topLeading) {
                Color.btBG
                RoundedRectangle(cornerRadius: 18).fill(Color.btPrimary.opacity(0.12))
                    .frame(width: foundation.table.width, height: foundation.table.height)
                    .position(x: foundation.table.midX, y: foundation.table.midY)
                VStack(spacing: 4) {
                    if family == .aimPointQuiz {
                        VStack(spacing: 4) {
                            ControlLayoutAimPointInformationPreview().frame(height: foundation.topDiameter + 14)
                            BTTeachingAimRuler(layout: BTTeachingInstrumentLayout(foundation: foundation),
                                enabled: true, onNudge: { _ in }, degreesPerPoint: AimWheelGain.defaultDegreesPerPoint,
                                onDragActiveChanged: { _ in })
                        }.modifier(PreviewMeasure(group: .direction))
                    } else if family == .angleQuiz {
                        ControlLayoutQuizInformationPreview().modifier(PreviewMeasure(group: .information))
                    } else if family == .teaching {
                        ControlLayoutTeachingPreview(page: .separationAngleAtlas, tracks: $tracks)
                            .frame(height: min(320, size.height - 80)).modifier(PreviewMeasure(group: .information))
                    } else if family == .planning {
                        VStack(spacing: 4) {
                            ForEach(["摆球", "清除", "求解", "方案", "重打", "回放"], id: \.self) { text in
                                Button(text) {}.frame(width: 44, height: 44).buttonStyle(BTAdaptiveToolActionStyle())
                            }
                        }.modifier(PreviewMeasure(group: .planning))
                    } else {
                        VStack(spacing: 4) {
                            Button {} label: {
                                VStack(spacing: 2) {
                                    BreakRackGlyph(color: HUDStyle.valueMeasured, size: foundation.topDiameter - 1, hollowBalls: true)
                                        .frame(width: foundation.topDiameter, height: foundation.topDiameter)
                                    Text("开球").font(.btMicro)
                                }
                            }
                            VStack(spacing: 6) {
                                BTAimWheel(onNudge: { _ in }, degreeHapticEnabled: false, visibleWidth: 32, showsDirectionLabel: false)
                                    .frame(width: 44, height: foundation.rulerLength)
                                Text("方向").font(.btMicro)
                            }.padding(.vertical, 6)
                        }.modifier(PreviewMeasure(group: .direction))
                        let layout = foundation.horizontalActions ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))
                        layout {
                            BTHUDCompactAction(title: "重打", symbol: "arrow.uturn.backward", size: foundation.auxiliarySize) {}
                            BTHUDCompactAction(title: "回放", symbol: "play.rectangle", size: foundation.auxiliarySize) {}
                        }.modifier(PreviewMeasure(group: .replay))
                    }
                }.frame(width: 60).position(x: foundation.left.midX, y: foundation.left.midY)
                if family == .angleQuiz || family == .aimPointQuiz {
                    if keyboardPreview && family == .angleQuiz {
                        NumericKeypadHUD(input: $answer, title: "示例题目", subtitle: nil, compact: true, usesSceneStyle: true,
                            onSubmit: {}, onCancel: { answer = "" })
                            .frame(width: min(280, foundation.stage.width)).modifier(PreviewMeasure(group: .keyboard))
                            .padding(.bottom, 8).padding(.trailing, size.width - foundation.stage.maxX)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    } else {
                        VStack(spacing: 8) {
                            Spacer(minLength: 0)
                            Button {} label: {
                                Text(family == .aimPointQuiz ? "角度提示" : "辅助").font(.btCaption)
                                    .frame(width: 52, height: 52).background { BTHUDControlBackground(shape: Circle()) }
                            }.buttonStyle(BTHUDPressStyle())
                            Button(family == .aimPointQuiz ? "提交" : "答题") {}.frame(width: 52, height: 52).buttonStyle(DailyStrikeButtonStyle())
                        }.frame(width: 60).padding(.vertical, 8).frame(height: min(200, foundation.stage.height))
                            .modifier(PreviewMeasure(group: .primary)).position(x: foundation.right.midX, y: foundation.table.midY)
                    }
                } else {
                VStack(spacing: 4) {
                    BTShotInstrumentColumn(spinX: 0, spinY: 0, onSpinTap: family == .teaching ? nil : {}, showsDisabledSpinEntry: family == .teaching, velocity: $velocity,
                        range: ShotTuning.velocityRange, fixedPowerBarHeight: foundation.rulerLength,
                        powerLabel: "杆速", compactPowerBarWidth: 32, compactSpinButtonDiameter: foundation.topDiameter, compactGroupSpacing: 4)
                        .modifier(PreviewMeasure(group: .instrument))
                    if family != .teaching {
                    Button {} label: { Text("击球").font(.btSubheadlineSemibold).frame(width: 60, height: 60) }
                        .buttonStyle(DailyStrikeButtonStyle()).modifier(PreviewMeasure(group: .primary))
                    }
                }.frame(width: 60).position(x: foundation.right.midX, y: foundation.right.midY)
                }
                VStack {
                    HStack {
                        Button("完成", action: onClose)
                        Spacer()
                        Text("模板独立预览").font(.btHeadline)
                        Spacer()
                        Button("编辑") { editing = true }.disabled(frames.isEmpty || !foundation.fits)
                            .accessibilityIdentifier("layoutLibrary.beginEdit")
                    }.frame(height: 44).padding(.horizontal)
                    Picker("控件样例", selection: $family) { Text("击球").tag(ControlLayoutFamily.shot); Text("规划").tag(ControlLayoutFamily.planning); Text("教学").tag(ControlLayoutFamily.teaching); Text("角度").tag(ControlLayoutFamily.angleQuiz); Text("瞄点").tag(ControlLayoutFamily.aimPointQuiz) }
                        .pickerStyle(.segmented).frame(maxWidth: 320)
                    if family == .angleQuiz { Toggle("键盘样例", isOn: $keyboardPreview).frame(maxWidth: 220) }
                    Text("选择样例后进入编辑，查看当前方向的模板效果。实际页面按各自控件能力应用。")
                        .font(.btCaption).multilineTextAlignment(.center).frame(maxWidth: max(160, foundation.table.width - 80))
                    if !foundation.fits { Text("扩大窗口或横屏后编辑").font(.btHeadline) }
                    Spacer()
                }
                if editing {
                    ControlLayoutEditorContainer(editor: ControlLayoutEditor(page: page, domain: domain, mode: .twoD,
                        input: .init(page: CGRect(origin: .zero, size: size),
                            leading: CGRect(x: foundation.left.minX, y: 44, width: 60, height: max(1, size.height - 44)),
                            trailing: CGRect(x: foundation.right.minX, y: 44, width: 60, height: max(1, size.height - 44)),
                            defaults: frames, defaultFits: foundation.fits, groupRegions: family == .angleQuiz ? [.keyboard: .init(
                                leading: CGRect(x: foundation.stage.minX, y: max(44, foundation.stage.minY), width: min(280, foundation.stage.width), height: max(1, size.height - 8 - max(44, foundation.stage.minY))),
                                trailing: CGRect(x: foundation.stage.maxX - min(280, foundation.stage.width), y: max(44, foundation.stage.minY), width: min(280, foundation.stage.width), height: max(1, size.height - 8 - max(44, foundation.stage.minY))))] : [:]),
                        rulerHeight: foundation.rulerLength, primaryTitle: family == .aimPointQuiz ? "提交" : (family == .angleQuiz ? "答题" : "击球"), templateID: templateID, libraryPreview: true,
                        onClose: { editing = false }))
                }
            }.coordinateSpace(name: "libraryPreview")
                .onPreferenceChange(LayoutPreviewMeasurements.self) { value in if value != frames { frames = value } }
        }.background(DailyTableOrientation(landscape: true, allowsTabletRotation: true, restoresPreviousOwner: true))
            .environment(\.colorScheme, .dark).tint(.btPrimary)
            .preference(key: TrainingActivityPausedKey.self, value: true)
    }
    private struct PreviewMeasure: ViewModifier {
        let group: ControlLayoutGroup
        func body(content: Content) -> some View {
            content.background { GeometryReader { proxy in
                Color.clear.preference(key: LayoutPreviewMeasurements.self, value: [group: proxy.frame(in: .named("libraryPreview"))])
            } }
        }
    }
}

private extension ControlLayoutValue {
    var layoutDescription: String {
        switch self {
        case .lane(let lane): return lane == .leading ? "左侧" : "右侧"
        case .offset(let value): return "\(Int(value))点"
        case .order(let value): return "第\(value + 1)组"
        case .size(let value): return value == .automatic ? "自动" : (value == .compact ? "紧凑" : "常规")
        case .cameraSlot(let value): return value == .automatic ? "自动" : "镜像"
        }
    }
}

/// overFullScreen retains the presenting training hierarchy. A SwiftUI full-screen
/// cover can send onDisappear to that hierarchy and incorrectly end its visit.
private struct ControlLayoutPreviewPresentation: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let templateID: UUID?
    func makeUIViewController(context: Context) -> Presenter { Presenter() }
    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.open = isPresented
        controller.templateID = templateID
        controller.onClose = { isPresented = false }
        controller.synchronize()
    }
    final class Presenter: UIViewController {
        var open = false
        var templateID: UUID?
        var onClose: () -> Void = {}
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated); synchronize()
        }
        func synchronize() {
            guard isViewLoaded, view.window != nil else { return }
            if open, presentedViewController == nil {
                let preview = UIHostingController(rootView: ControlLayoutLibraryPreview(templateID: templateID, onClose: { [weak self] in self?.onClose() }))
                preview.modalPresentationStyle = .overFullScreen
                preview.view.accessibilityViewIsModal = true
                present(preview, animated: true)
            } else if !open, presentedViewController != nil {
                dismiss(animated: true)
            }
        }
    }
}
