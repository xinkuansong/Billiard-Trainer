import SwiftUI
import SceneKit

struct CustomFormationPracticeView: View {
    @EnvironmentObject private var authState: AuthState
    @StateObject private var library: CustomFormationLibrary
    @State private var active: CustomFormationSession?
    @State private var renaming: CustomFormationTemplate?
    @State private var renameText = ""
    @State private var deleting: CustomFormationTemplate?
    @Environment(\.dismiss) private var dismiss

    init(ownerKey: String) {
        _library = StateObject(wrappedValue: CustomFormationLibrary(ownerKey: ownerKey))
    }

    var body: some View {
        Group {
            if let active {
                let destination = $active
                CustomFormationTableView(session: active, library: library,
                    onDismiss: { destination.wrappedValue = nil }).id(active.id)
            } else {
                selectionBody
            }
        }
    }

    // As with the other practice pages, selection and table share one navigation
    // destination. An extra isPresented push here loops during iOS 17 layout.
    private var selectionBody: some View {
        List {
            Section("内置球形") {
                ForEach(BuiltInCustomFormations.templates) { template in
                    HStack {
                        Button { library.select(template.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(template.name).foregroundStyle(.primary)
                                    Text("\(template.ballKeys.count)颗目标球").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                BTSelectionIndicator(isSelected: library.selectedID == template.id)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("formation.builtin.\(template.id)")
                        .accessibilityValue(library.selectedID == template.id ? "已选" : "未选")
                        Menu {
                            Button("复制到我的球形", systemImage: "doc.on.doc") { library.duplicate(template) }
                                .disabled(library.failedToLoad)
                        } label: {
                            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("\(template.name)，模板操作")
                        .accessibilityIdentifier("formation.templateMenu.\(template.id)")
                    }
                }
            }
            Section("练习模板") {
                if library.failedToLoad {
                    Button("重新读取模板") { library.reload() }
                } else if library.templates.isEmpty {
                    Text("还没有球形模板").foregroundStyle(.secondary)
                }
                ForEach(library.templates) { template in
                    HStack {
                        Button { library.select(template.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(template.name).foregroundStyle(.primary)
                                    Text(template.practiceIssue.map { "\($0)，请编辑后再练习" } ?? "\(template.ballKeys.count)颗目标球").font(.footnote).foregroundStyle(.secondary)
                                    Text(library.syncLabel(for: template.id, enabled: authState.cloudSyncEnabled))
                                        .font(.btCaption).foregroundStyle(.btTextSecondary)
                                        .accessibilityIdentifier("formation.sync.\(template.id)")
                                }
                                Spacer()
                                BTSelectionIndicator(isSelected: library.selectedID == template.id)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("formation.template.\(template.id)")
                        .accessibilityValue(library.selectedID == template.id ? "已选" : "未选")
                        Menu {
                            Button("编辑", systemImage: "pencil") { openEditor(template) }
                            Button("复制", systemImage: "doc.on.doc") { library.duplicate(template) }
                            Button("重命名", systemImage: "character.cursor.ibeam") { renameText = template.name; renaming = template }
                            Button("删除", systemImage: "trash", role: .destructive) { deleting = template }
                        } label: {
                            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("\(template.name)，模板操作")
                        .accessibilityIdentifier("formation.templateMenu.\(template.id)")
                    }
                }
            }
            if let notice = library.archive.notice {
                Section { BTTrainingSettingsNote(notice).font(.btFootnote).foregroundStyle(.btTextSecondary) }
            }
            Section("模板管理") {
                Button("新建模板", systemImage: "plus") { openEditor(nil) }
                    .disabled(library.failedToLoad).accessibilityIdentifier("formation.new")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .formationStoreChanged)) { _ in library.reload() }
        .onAppear { library.reload() }
        .navigationTitle("选择球形")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("选择球形").font(.btHeadline).foregroundStyle(.btPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarLeading) { Button("返回") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("开始练习") {
                    if let template = library.selected, template.practiceIssue == nil { active = library.practiceSession(for: template) }
                }
                .fontWeight(.semibold).disabled(library.selected == nil || library.selected?.practiceIssue != nil)
                .accessibilityIdentifier("formation.start")
            }
        }
        .alert("重命名模板", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("模板名称", text: $renameText)
            Button("保存") { if let renaming { library.rename(renaming, name: renameText) }; renaming = nil }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("取消", role: .cancel) { renaming = nil }
        }
        .alert("删除这个模板？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { template in
            Button("删除模板", role: .destructive) { library.delete(template.id); deleting = nil }
            Button("取消", role: .cancel) { deleting = nil }
        } message: { template in
            Text("将删除“\(template.name)”及其练习进度。")
        }
        .alert("操作未完成", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("知道了", role: .cancel) { library.error = nil }
        } message: { Text(library.error ?? "") }
    }
    private func openEditor(_ template: CustomFormationTemplate?) {
        // The placement action opens the same editable top-down surface as the composer.
        TablePreferencesStore.shared.apply(.view3D, value: 0, to: .customFormationEditor)
        active = .init(template: template, editing: true)
    }
}

private struct CustomFormationTableView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: CustomFormationSession
    @ObservedObject var library: CustomFormationLibrary
    // The navigation owner clears the destination. Reading DismissAction here
    // repeatedly invalidates this observed destination during iOS 17 pushes.
    let onDismiss: () -> Void
    @State private var saveError: String?

    var body: some View {
        FreePlayView(editorModel: session.vm, editor: .init(
            title: session.name, isTryout: false,
            loadsDefaultLayout: false, setup: session.setup, onInteraction: {}, onRearrange: session.reset,
            menuItems: menuItems, overlay: AnyView(CustomFormationNotice(session: session)),
            formation: session, onBack: requestBack))
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.saveProgress() } }
        .onDisappear { session.finishPractice() }
        .alert("保存模板", isPresented: $session.showSave) {
            TextField("模板名称", text: $session.name).accessibilityIdentifier("formation.name")
            Button("保存") { save() }.disabled(session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("formation.save.confirm")
            Button("取消", role: .cancel) {}
        }
        .alert("未能保存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("知道了", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .confirmationDialog("球形尚未保存", isPresented: $session.showExit, titleVisibility: .visible) {
            Button("保存并返回") { session.showSave = true }.disabled(!session.canSave)
            Button("放弃修改", role: .destructive) { onDismiss() }
            Button("继续编辑", role: .cancel) {}
        }
        .confirmationDialog("清空所有目标球？", isPresented: $session.showClear, titleVisibility: .visible) {
            Button("清空目标球", role: .destructive) { session.clearTargets() }
            Button("取消", role: .cancel) {}
        }
        .overlay {
            if session.showRestart {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.opacity(0.2).contentShape(Rectangle()).onTapGesture {}
                        DailyConfirmationCard(title: "恢复初始球形并重新开始？",
                            availableHeight: geometry.size.height - 32, availableWidth: geometry.size.width - 32,
                            firstTitle: "重新开始", secondTitle: "取消", firstID: "formation.restart.confirm", secondID: "formation.restart.cancel",
                            first: { session.reset(); session.showRestart = false }, second: { session.showRestart = false })
                    }
                }
            }
        }
    }

    private func requestBack() {
        if session.isTemplateEditor && (session.hasEdits || session.original == nil) { session.showExit = true }
        else { session.finishPractice(); onDismiss() }
    }

    private func save() {
        do {
            let template = try session.templateForSaving()
            if library.save(template, basedOn: template.id == session.original?.id ? session.original : nil) {
                if session.isTemplateEditor { onDismiss() }
                else { session.notice = "已另存为模板" }
            } else { saveError = library.error; library.error = nil }
        } catch { saveError = error.localizedDescription }
    }

    private var menuItems: [DailyHUDMenuItem] {
        if !session.isTemplateEditor {
            return [
                .init(id: "formation.practice", title: "练习"),
                .init(id: "formation.playback", title: "回放", disabled: session.busy || !session.vm.canPlayback || session.vm.temporaryTopDownActive,
                    action: { session.vm.cancelPowerRelease(); session.vm.replayLastShot() }),
                .init(id: "formation.save", title: "将当前球形另存为模板", disabled: !session.canSave,
                    action: { session.saveAsNew = true; session.showSave = true })
            ]
        }
        var items: [DailyHUDMenuItem] = [.init(id: "formation.heading", title: session.isTemplateEditor ? "模板" : "练习")]
        if session.trialBoard != nil {
            items += [
                .init(id: "formation.returnDraft", title: "返回摆球", disabled: session.busy, action: { session.resumeArrangement() }),
                .init(id: "formation.adoptTrial", title: "采用当前球形继续编辑", disabled: session.busy, action: { session.resumeArrangement(adoptTrial: true) })]
        } else {
            items.append(.init(id: "formation.save", title: session.isTemplateEditor ? "保存模板" : "将当前球形另存为模板",
                disabled: !session.canSave, action: { session.saveAsNew = !session.isTemplateEditor; session.showSave = true }))
            if session.isTemplateEditor && session.original != nil {
                items.append(.init(id: "formation.saveCopy", title: "另存为新模板", disabled: !session.canSave,
                    action: { session.saveAsNew = true; session.showSave = true }))
            }
        }
        items += [
            .init(id: "formation.arrange", title: session.toolsActive ? "完成摆球" : "摆球工具", disabled: session.busy,
                  action: { if session.toolsActive { session.clearTools(); session.toolsActive = false } else { session.resumeArrangement() } }),
            .init(id: "formation.line", title: session.guide.phase == .off ? "直线工具" : "清除辅助线", disabled: session.busy,
                  action: { if session.guide.phase == .off { session.startLine() } else { session.guide.clear(scene: session.vm.scene) } }),
            .init(id: "formation.cue", title: "放回母球", disabled: session.busy, action: { session.place(PositionPlayBall.cueKey, world: nil) }),
            .init(id: "formation.clear", title: "清空目标球", disabled: session.busy, action: { session.showClear = true })]
        if !session.isTemplateEditor {
            items.append(.init(id: "formation.settings", title: "训练设置", disclosure: true, disabled: session.busy, action: { onDismiss() }))
        }
        return items
    }
}

struct CustomFormationNotice: View {
    @ObservedObject var session: CustomFormationSession
    var body: some View {
        VStack(spacing: Spacing.xs) {
            if let text = session.isTemplateEditor ? session.editHint : (session.guide.hint ?? (session.swapMode ? "点选目标球，与母球交换位置" : session.notice)) {
                BTNoticeContent(message: .init(text, tone: .info), compact: true, textOnly: true)
                    .accessibilityIdentifier("formation.notice")
            }
            if !session.isTemplateEditor && session.guide.isPicking {
                HStack(spacing: Spacing.sm) {
                    Button("确认") { session.confirmLine() }.disabled(!session.guide.hasCurrentPoint)
                        .accessibilityIdentifier("formation.line.confirm")
                    Button("取消") { session.guide.clear(scene: session.vm.scene) }
                        .accessibilityIdentifier("formation.line.cancel")
                }.buttonStyle(BTAdaptiveToolActionStyle())
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct CustomFormationToolEntry: View {
    @ObservedObject var session: CustomFormationSession
    let diameter: CGFloat
    var body: some View {
        Button { session.showRestart = true } label: { label("arrow.clockwise", title: "重新开始") }
            .buttonStyle(BTHUDPressStyle())
            .disabled(session.busy)
            .accessibilityIdentifier("formation.restart")
            .freeControlItem("formation.restart", name: "重新开始")
    }
    private func label(_ symbol: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.title2).btHUDActionContent()
                .frame(width: diameter, height: diameter)
                .background { BTHUDControlBackground(shape: Circle()) }
            Text(title).font(.btMicro).foregroundStyle(.white)
        }
    }
}

struct FormationEditorLeft: View {
    @ObservedObject var session: CustomFormationSession
    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(FormationEditTool.allCases, id: \.self) { tool in
                BTHUDCompactAction(title: tool.rawValue,
                    symbol: tool == .line ? "line.diagonal" : tool == .distance ? "ruler" : "angle",
                    selected: session.editTool == tool) { session.beginTool(tool) }
                    .accessibilityIdentifier("formation.tool.\(tool)")
                    .freeControlItem("formation.tool.\(tool)", name: tool.rawValue)
            }
            Spacer(minLength: Spacing.xs)
            action("撤销", icon: "arrow.uturn.backward", id: "undo", disabled: session.undoStack.isEmpty, run: session.undoEdit)
            action("重做", icon: "arrow.uturn.forward", id: "redo", disabled: session.redoStack.isEmpty, run: session.redoEdit)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .foregroundStyle(.btText).buttonStyle(BTHUDPressStyle())
    }
    private func action(_ title: String, icon: String, id: String, disabled: Bool, run: @escaping () -> Void) -> some View {
        BTHUDCompactAction(title: title, symbol: icon, action: run)
            .disabled(disabled).accessibilityIdentifier("formation.edit.\(id)")
            .freeControlItem("formation.edit.\(id)", name: title)
    }
}

struct FormationEditorRight: View {
    @ObservedObject var session: CustomFormationSession
    var projector: TableProjector? = nil
    var body: some View {
        VStack(spacing: Spacing.xs) {
            if session.editTool == .distance || session.editTool == .angle {
                readout(session.editTool == .distance ? "距离 cm" : "角度 °", value: number(session.measurementValue), id: "measurement")
            } else if session.selectedLine != nil {
                readout("球数", value: String(session.lineBallCount), id: "count")
                readout("球距 cm", value: number(session.lineSpacingCM), id: "spacing")
                readout("线长 cm", value: number(session.lineLengthCM), id: "length")
            }
            Spacer(minLength: Spacing.xs)
            if session.editTool == .distance || session.editTool == .angle {
                operation("清除", id: "clearMeasure", enabled: !session.measurement.isEmpty, run: session.clearMeasurement)
                operation("完成", id: "finish", run: session.cancelTool)
            } else if session.editTool == .line {
                operation("完成", id: "finish", run: session.cancelTool)
            } else {
                if session.selectedLine != nil {
                    operation(session.lineSortTitle, id: "sort", enabled: session.lineBallCount > 1) {
                        guard let line = session.selectedLine,
                              let a = session.drawing.vertex(line.start,y:session.vm.scene.surfaceY + BallPhysics.radius),
                              let b = session.drawing.vertex(line.end,y:session.vm.scene.surfaceY + BallPhysics.radius),
                              let start = projector?.project?(a), let end = projector?.project?(b) else { return }
                        session.sortSelectedLine(startPrecedesEnd:FormationGeometry.startPrecedesEnd(start,end))
                    }
                    .accessibilityLabel("球号排序")
                    .accessibilityValue(session.lineSortTitle == "排序" ? "原始顺序" : session.lineSortTitle)
                    .accessibilityHint("依次切换左到右、右到左、原始顺序；竖线从上到下")
                }
                if let key = session.focusKey, !PositionPlayBall.isCue(key) {
                    operation("删球", id: "delete") { session.remove(key, permanently: true) }
                } else if session.selectedLine != nil {
                    operation("删线", id: "deleteLine", run: session.deleteSelectedLine)
                }
                operation("保存", id: "save", enabled: session.canSave) { session.showSave = true }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .foregroundStyle(.btText).buttonStyle(BTHUDPressStyle())
    }
    private func number(_ value: Double?) -> String {
        value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(1))) } ?? "—"
    }
    private func readout(_ title: String, value: String, id: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(HUDStyle.labelFont).foregroundStyle(HUDStyle.labelColor).lineLimit(1)
            BTReadout(value: value, emphasis: id == "measurement" ? .measured : .adjustable).lineLimit(1)
        }.frame(width: 56, height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title).accessibilityValue(value)
            .accessibilityIdentifier("formation.parameter." + id)
    }
    private func operation(_ title: String, id: String, enabled: Bool = true, run: @escaping () -> Void) -> some View {
        BTTextActionButton(title: title, role: id == "delete" || id == "deleteLine" ? .destructive : (id == "save" ? .primary : .plain),
                           isDisabled: !enabled, height: 44, action: run)
            .fixedSize().frame(width: 56, height: 44)
            .accessibilityIdentifier("formation.edit." + id)
            .freeControlItem("formation.edit." + id, name: title)
    }
}
#Preview("Editor Light") { FormationEditorLeft(session: .init(template: nil, editing: true)).frame(width: 60, height: 300) }
#Preview("Editor Dark") { FormationEditorRight(session: .init(template: nil, editing: true)).frame(width: 60, height: 300).preferredColorScheme(.dark) }

/// Screen-space text stays readable at every table scale; geometry remains on the X/Z plane.
struct FormationMeasurementOverlay: View {
    @ObservedObject var session: CustomFormationSession
    let projector: TableProjector
    @State private var labelSize: CGSize = .zero
    var body: some View {
        // Camera zoom/pan happens in SceneKit without publishing a new measurement.
        TimelineView(.animation(minimumInterval: 1.0/30, paused: session.measurementValue == nil)) { _ in
            // Project on every timeline tick, before GeometryReader. Capturing only
            // the stable projector/session in its closure leaves the layout cached.
            let projected = session.measurementLabelPoint.flatMap { projector.project?($0) }
            GeometryReader { geometry in
                if let point = projected, let value = session.measurementValue {
                    let label = value.formatted(.number.grouping(.never).precision(.fractionLength(1))) + (session.editTool == .distance ? " cm" : "°")
                    Text(label).font(.btCaption).monospacedDigit().fontWeight(.semibold)
                        .foregroundStyle(Color(session.measurementAnnotationColor))
                        .fixedSize()
                        .background {
                            GeometryReader { measured in
                                Color.clear.onAppear { labelSize = measured.size }
                                    .onChange(of: measured.size) { _, size in labelSize = size }
                            }
                        }
                        .position(labelPosition(point,in:geometry.size))
                        .accessibilityIdentifier("formation.measurement.label")
                }
            }
        }.allowsHitTesting(false)
    }
    private func labelPosition(_ point: CGPoint, in size: CGSize) -> CGPoint {
        var centre = point
        if session.editTool == .angle, session.measurement.count == 3,
           let vertex = projector.project?(session.measurement[1]) {
            let dx = point.x-vertex.x, dy = point.y-vertex.y, radius = hypot(dx,dy)
            if radius > 0.1 {
                // The whole measured label rectangle clears the arc, including compact screens.
                let clearance = hypot(labelSize.width,labelSize.height)/2 + Spacing.xs
                centre.x += dx/radius*clearance; centre.y += dy/radius*clearance
            } else { centre.y -= labelSize.height/2 + Spacing.xs }
        } else { centre.y -= labelSize.height/2 + Spacing.xs }
        let marginX = labelSize.width/2 + Spacing.xs, marginY = labelSize.height/2 + Spacing.xs
        return CGPoint(x:min(max(centre.x,marginX),max(marginX,size.width-marginX)),
                       y:min(max(centre.y,marginY),max(marginY,size.height-marginY)))
    }
}
