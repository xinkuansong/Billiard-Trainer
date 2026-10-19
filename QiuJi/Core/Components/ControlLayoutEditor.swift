import SwiftUI
import SceneKit

/// Synthetic readouts only; no question, record, or submission closure is shared.
struct ControlLayoutQuizInformationPreview: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            metric("题目", "1/20")
            metric("目标袋", "角袋")
            metric("作答", "独立")
        }.padding(.vertical, Spacing.xs)
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.btMicro).foregroundStyle(.secondary)
            Text(value).font(.btCaption).monospacedDigit()
        }
    }
}

/// A separate native accessibility container keeps focus inside the editor without
/// dismissing/recreating the training view or routing its alerts through training presenters.
struct ControlLayoutEditorContainer: UIViewControllerRepresentable {
    let editor: ControlLayoutEditor
    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        let controller = UIHostingController(rootView: AnyView(editor.ignoresSafeArea()))
        controller.view.backgroundColor = .clear
        controller.view.accessibilityViewIsModal = true
        return controller
    }
    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        controller.rootView = AnyView(editor.ignoresSafeArea())
    }
}

extension ControlLayoutGroup {
    var title: String {
        switch self {
        case .direction: return "方向"
        case .instrument: return "杆速与打点"
        case .primary: return "主动作"
        case .replay: return "重打与回放"
        case .planning: return "规划工具"
        case .camera: return "相机"
        case .information: return "信息与读数"
        case .keyboard: return "答题键盘"
        }
    }
}
extension ControlLayoutDomain {
    var title: String {
        switch self { case .phoneLandscape: return "手机横屏"; case .padLandscape: return "平板横屏"; case .padPortrait: return "平板竖屏" }
    }
}

/// One independent display model; never receives a training VM or business callback.
private final class ControlLayoutPreviewValues: ObservableObject {
    @Published var speed = 1.5
    @Published var spinX = 0.0
    @Published var spinY = 0.0
    @Published var direction: Float = 0
    @Published var tracks = Set(0..<8)
    @Published var answer = ""
    let camera: CameraRig = {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0)
        rig.configurePlayerCameraControls(daily: true)
        return rig
    }()
}

struct ControlLayoutEditor: View {
    let page: TablePreferencePage
    let domain: ControlLayoutDomain
    let input: ControlLayoutPlacement.Input
    let rulerHeight: CGFloat
    let primaryTitle: String
    let sequenceReadOnly: Bool
    let onClose: () -> Void
    let templateID: UUID?
    let libraryPreview: Bool
    @ObservedObject private var store = ControlLayoutStore.shared
    @State private var draft: ControlLayoutDraft
    @State private var selected: ControlLayoutGroup = .primary
    @State private var layer: ControlLayoutLayer = .common
    @State private var previewMode: ControlLayoutLayer
    @State private var interactive = false
    @State private var spinOpen = false
    @State private var menuOpen = false
    @State private var message = "拖动选中的控件，或使用下方位置操作。"
    @State private var confirmDiscard = false
    #if DEBUG
    @State private var cancelRequests = 0
    #endif
    @State private var libraryOpen = false
    @State private var promoting = false
    @State private var promotionSaved = false
    @State private var conflict = false
    @State private var copyOnly = false
    @State private var naming = false
    @State private var templateName = ""
    @State private var failure: String?
    @StateObject private var values = ControlLayoutPreviewValues()
    @AccessibilityFocusState private var titleFocused: Bool

    init(page: TablePreferencePage, domain: ControlLayoutDomain, mode: ControlLayoutLayer,
         input: ControlLayoutPlacement.Input, rulerHeight: CGFloat, primaryTitle: String, sequenceReadOnly: Bool = false, templateID: UUID? = nil, libraryPreview: Bool = false, onClose: @escaping () -> Void) {
        self.page = page; self.domain = domain; self.input = input; self.rulerHeight = rulerHeight; self.onClose = onClose
        self.primaryTitle = primaryTitle; self.sequenceReadOnly = sequenceReadOnly; self.templateID = templateID; self.libraryPreview = libraryPreview
        _draft = State(initialValue: ControlLayoutDraft(archive: ControlLayoutStore.shared.archive, page: page, domain: domain, templateID: templateID, editingTemplate: libraryPreview))
        _previewMode = State(initialValue: mode)
        _selected = State(initialValue: [.primary, .information, .direction, .planning, .instrument, .camera, .keyboard].first { input.defaults[$0] != nil } ?? .primary)
    }
    private var previewInput: ControlLayoutPlacement.Input {
        var result = input
        if previewMode == .twoD { result.defaults.removeValue(forKey: .camera) }
        else if result.defaults[.camera] == nil, let instrument = result.defaults[.instrument] {
            // Same daily CameraLane geometry; the preview rig has four 44pt controls with 4pt gaps.
            let height: CGFloat = 188
            let powerShell = CGRect(x: 0, y: instrument.maxY - (rulerHeight + 46), width: 52, height: rulerHeight + 46)
            let offset = DailyLayoutMetrics.CameraLane(column: input.trailing, rulerHeight: rulerHeight,
                                                       powerShell: powerShell, stackHeight: height).offset
            result.defaults[.camera] = CGRect(x: input.trailing.minX + offset.width,
                                             y: offset.height, width: 44, height: height)
        } else if previewMode == .threeD, page == .angleDynamic, result.defaults[.camera] == nil,
                  let information = input.defaults[.information] {
            // This host has no power column; its camera is centred on the table.
            result.defaults[.camera] = CGRect(x: input.trailing.midX - 22,
                y: information.midY - 94, width: 44, height: 188)
        }
        if previewMode == .threeD, (page.controlLayoutFamily == .angleQuiz || page.controlLayoutFamily == .aimPointQuiz),
           result.defaults[.camera] == nil, result.defaults[.keyboard] == nil,
           let information = input.defaults[.information] ?? input.defaults[.primary] {
            result.defaults[.camera] = CGRect(x: input.trailing.minX - 48,
                y: information.midY - 94, width: 44, height: 188)
        }
        return result
    }
    private func resolved(_ value: ControlLayoutDraft) -> ControlLayoutResolved {
        ControlLayoutResolver.resolve(value.preview, page: page, domain: domain, mode: previewMode,
                                      capabilities: Set(previewInput.defaults.keys))
    }
    private var placement: ControlLayoutPlacement.Result { ControlLayoutPlacement.place(resolved(draft), in: previewInput) }
    private var groups: [ControlLayoutGroup] { previewInput.defaults.keys.sorted { $0.rawValue < $1.rawValue } }
    private var centerWidth: CGFloat {
        if let keyboard = placement.frames[.keyboard] {
            let space = keyboard.midX > input.page.midX ? keyboard.minX - input.leading.maxX : input.trailing.minX - keyboard.maxX
            return max(160, min(430, space - 16))
        }
        return max(220, min(430, input.trailing.minX - input.leading.maxX - 112))
    }
    private var propertiesCenterX: CGFloat {
        guard let keyboard = placement.frames[.keyboard] else { return input.page.midX }
        return keyboard.midX > input.page.midX ? input.leading.maxX + 8 + centerWidth / 2 : input.trailing.minX - 8 - centerWidth / 2
    }
    private var fixedMode: ControlLayoutLayer? { libraryPreview ? nil : page.fixedControlLayoutMode }

    private var topDiameter: CGFloat { input.page.height >= DailyLayoutMetrics.headerHeight + 352 ? 56 : 48 }
    private var templateTitle: String {
        (templateID ?? draft.preview.templateID(for: page)).flatMap { draft.base.templates[$0]?.name } ?? "球迹默认"
    }
    private var selectionTitle: String {
        switch draft.binding.selection {
        case .familyDefault: return "跟随本类默认"
        case .builtIn: return "本页使用球迹默认"
        case .template: return "本页使用所选模板"
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.btBG.contentShape(Rectangle()).onTapGesture { }
            RoundedRectangle(cornerRadius: 18).fill(Color.btPrimary.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.btPrimary.opacity(0.3)))
                .frame(width: max(1, input.trailing.minX - input.leading.maxX - 16), height: max(1, input.page.height - 64))
                .position(x: input.page.midX, y: (input.page.height + 44) / 2)
                .accessibilityHidden(true)
            ForEach(groups, id: \.self) { group in
                if let frame = placement.frames[group] {
                    previewGroup(group, frame: frame)
                        .frame(width: frame.width, height: frame.height)
                        .overlay {
                            if !interactive {
                                Rectangle().fill(Color.clear).contentShape(Rectangle())
                                    .overlay(Rectangle().stroke(selected == group ? Color.btPrimary : Color.btTextSecondary, lineWidth: selected == group ? 2 : 1))
                                    .onTapGesture { selected = group }
                                    .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                                        selected = group
                                        move(group, by: value.translation.height)
                                    })
                                    .accessibilityElement().accessibilityLabel(group.title)
                                    .accessibilityHint("选择后可用位置操作调整")
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { selected = group }
                                    .accessibilityIdentifier("layoutEditor.group." + group.rawValue)
                            }
                        }
                        .position(x: frame.midX, y: frame.midY)
                }
            }
            header
                .frame(width: input.page.width, height: 44)
            VStack(spacing: 8) {
                if spinOpen {
                    BTSpinPad(spinX: $values.spinX, spinY: $values.spinY, locksSideSpin: page == .cushionEnglishAtlas)
                        .frame(width: 180, height: 180)
                    Button("收起打点盘") { spinOpen = false }.frame(minHeight: 44)
                } else if menuOpen {
                    Text("更多面板预览").font(.btHeadline)
                    Text("此处只检查展开空间，练习中的显示设置保持原值。").font(.btFootnote)
                    Button("关闭面板") { menuOpen = false }.frame(minHeight: 44)
                } else {
                    properties
                }
            }
            .padding(12).frame(width: centerWidth)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxHeight: max(1, input.page.height - 60))
            .position(x: propertiesCenterX, y: (input.page.height + 44) / 2)
        }
        .frame(width: input.page.width, height: input.page.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("layoutEditor")
        .accessibilityHidden(libraryOpen || promoting)
        .onAppear { titleFocused = true }
        .onChange(of: groups) { _, next in if !next.contains(selected), let first = next.first { selected = first } }
        .preference(key: TrainingActivityPausedKey.self, value: true)
        #if DEBUG
        .background {
            if DailyLayoutProbe.enabled {
                Color.clear.accessibilityElement().accessibilityIdentifier("layoutEditor.state")
                    .accessibilityValue("cancelRequests=\(cancelRequests) confirmDiscard=\(confirmDiscard) dirty=\(draft.isDirty)")
            }
        }
        #endif
        .confirmationDialog("放弃本次布局修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive, action: onClose)
            Button("继续编辑", role: .cancel) { }
        }
        .alert("另存为新模板", isPresented: $naming) {
            TextField("模板名称", text: $templateName)
            Button("取消", role: .cancel) { }
            Button(copyOnly || libraryPreview ? "保存副本" : "保存并应用") { save(newName: templateName) }
        } message: {
            Text(copyOnly || libraryPreview ? "保存独立副本，保留当前页面绑定。" : "合入当前\(domain.title)的共用、2D和3D微调，并清除这些本页覆盖。其他方向的微调保留。新模板独立于来源。")
        }
        .alert("布局未保存", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("继续编辑", role: .cancel) { }
            if conflict { Button("草稿另存为副本") { copyOnly = true; naming = true } }
            Button("重新载入") {
                store.reload()
                if store.loadError == nil { draft = .init(archive: store.archive, page: page, domain: domain, templateID: templateID, editingTemplate: libraryPreview) }
            }
        } message: { Text(failure ?? "") }
        .sheet(isPresented: $libraryOpen) {
            NavigationStack {
                ControlLayoutLibrary().toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回编辑") { libraryOpen = false } } }
            }
        }
        .sheet(isPresented: $promoting, onDismiss: {
            if promotionSaved { onClose() }
        }) {
            ControlLayoutPromotionSheet(draft: draft, onSaved: { promotionSaved = true })
        }
    }

    private var header: some View {
        HStack {
            Button("取消") {
                #if DEBUG
                cancelRequests += 1
                #endif
                if draft.isDirty { confirmDiscard = true } else { onClose() }
            }
                .accessibilityIdentifier("layoutEditor.cancel")
            Spacer()
            Text("操作布局").font(.btHeadline).accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
            Spacer()
            Menu("保存") {
                if libraryPreview {
                    if templateID != nil { Button("更新此模板") { promoting = true } }
                } else {
                    Button("仅保存到本页") { save() }.accessibilityIdentifier("layoutEditor.savePage")
                    if draft.preview.templateID(for: page) != nil {
                        Button("更新共享模板") { promoting = true }.accessibilityIdentifier("layoutEditor.promote")
                    }
                }
                Button("另存为新模板") { copyOnly = libraryPreview; naming = true }.accessibilityIdentifier("layoutEditor.saveAs")
            }.accessibilityIdentifier("layoutEditor.save")
                .disabled(placement.status == .temporaryDefault || placement.status == .insufficientSpace || domain != draft.domain)
        }.frame(minHeight: 44).padding(.horizontal, max(16, input.leading.minX))
            .background(.regularMaterial)
            .buttonStyle(BTAdaptiveToolActionStyle())
    }
    private var properties: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(templateTitle + " · " + draft.domain.title).font(.btSubheadlineSemibold)
                Text(libraryPreview ? "独立控件样例；不包含训练局面" : selectionTitle).font(.btFootnote).foregroundStyle(.btTextSecondary)
                if !libraryPreview {
                Button("管理模板") { libraryOpen = true }.accessibilityIdentifier("layoutEditor.library")
                Menu("选择模板") {
                    Button("跟随本类默认") { choose(.familyDefault) }
                    Button("球迹默认") { choose(.builtIn) }
                    ForEach(draft.base.templates.values.sorted { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name }) { template in
                        Button(template.name) { choose(.template(template.id)) }
                            .accessibilityIdentifier("layoutEditor.template." + template.id.uuidString)
                    }
                }.accessibilityIdentifier("layoutEditor.templates")
                }
                if placement.status == .temporaryDefault || placement.status == .insufficientSpace {
                    Text("所选布局在当前页面放不下。可调整控件位置或恢复跟随，再保存。").font(.btFootnote)
                }
                if !resolved(draft).inactive.isEmpty {
                    Text("有\(resolved(draft).inactive.count)项调整不适用于当前控件，保留在模板中。").font(.btFootnote)
                }
                if domain != draft.domain { Text("请回到原方向继续编辑或保存；草稿已保留。").font(.btFootnote) }
                Text(libraryPreview ? "修改只更新模板，示例页不产生本页微调" : (draft.binding.overrides.isEmpty ? "当前页没有微调" : "当前页有独立微调")).font(.btFootnote).foregroundStyle(.btTextSecondary)
                Picker("预览视图", selection: $previewMode) {
                    if fixedMode != .threeD { Text("2D").tag(ControlLayoutLayer.twoD) }
                    if fixedMode != .twoD { Text("3D").tag(ControlLayoutLayer.threeD) }
                }.pickerStyle(.segmented)
                    .accessibilityIdentifier("layoutEditor.mode")
                    .onChange(of: previewMode) { _, value in if layer != .common { layer = value } }
                Toggle("交互预览", isOn: $interactive).accessibilityIdentifier("layoutEditor.preview")
                if !interactive {
                    Picker("调整范围", selection: $layer) {
                        Text("2D/3D共用").tag(ControlLayoutLayer.common)
                        if fixedMode != .threeD { Text("仅2D").tag(ControlLayoutLayer.twoD) }
                        if fixedMode != .twoD { Text("仅3D").tag(ControlLayoutLayer.threeD) }
                    }.accessibilityIdentifier("layoutEditor.layer")
                    .onChange(of: layer) { _, value in if value != .common { previewMode = value } }
                    Picker("控件", selection: $selected) { ForEach(groups, id: \.self) { Text($0.title).tag($0) } }
                        .accessibilityIdentifier("layoutEditor.selection")
                    HStack {
                        Button("上移") { move(selected, by: -8) }.disabled(selected == .camera).accessibilityIdentifier("layoutEditor.up")
                        Button("下移") { move(selected, by: 8) }.disabled(selected == .camera).accessibilityIdentifier("layoutEditor.down")
                        Button(libraryPreview ? "恢复默认" : "恢复跟随") { restoreSelected() }.accessibilityIdentifier("layoutEditor.restoreGroup")
                    }.frame(minHeight: 44)
                    if selected == .camera {
                        Button("相机换侧") { mirrorCamera() }.frame(minHeight: 44)
                            .accessibilityIdentifier("layoutEditor.mirrorCamera")
                    }
                    HStack {
                        Button("左右交换") { swapColumns() }.accessibilityIdentifier("layoutEditor.swap")
                        Button("撤销") { draft.undo() }.disabled(draft.undoStack.isEmpty)
                        Button("重做") { draft.redo() }.disabled(draft.redoStack.isEmpty)
                    }.frame(minHeight: 44)
                    HStack {
                        Button("移到左侧") { setLane(.leading) }.accessibilityIdentifier("layoutEditor.leading")
                        Button("移到右侧") { setLane(.trailing) }.accessibilityIdentifier("layoutEditor.trailing")
                    }.disabled(selected == .camera).frame(minHeight: 44)
                    HStack {
                        Button("组间前移") { reorder(by: -1) }
                        Button("组间后移") { reorder(by: 1) }
                    }.disabled(input.groupRegions[selected] != nil || selected == .camera).frame(minHeight: 44)
                    Menu(libraryPreview ? "恢复当前方向" : "恢复本页") {
                        if libraryPreview {
                            Button("当前方向使用球迹默认") {
                                draft.change { binding in binding.overrides = binding.overrides.filter { $0.key.domain != domain } }
                            }
                        } else {
                            Button("恢复本页跟随") { draft.change { $0 = .init() } }
                            Button("本页使用球迹默认") { draft.change { $0 = .init(selection: .builtIn) } }
                        }
                    }.frame(minHeight: 44)
                } else {
                    Text("试调方向、杆速和打点；击球只显示触达反馈。").font(.btFootnote)
                    Button("预览更多面板") { menuOpen = true }.frame(minHeight: 44)
                }
                Text(message).font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .accessibilityIdentifier("layoutEditor.feedback")
                Text("顶部导航、球库和球桌固定；当前尺寸保持原档位。").font(.btFootnote).foregroundStyle(.btTextSecondary)
            }
        }.frame(maxHeight: max(160, input.page.height - 100))
            .buttonStyle(BTAdaptiveToolActionStyle())
            .accessibilityIdentifier("layoutEditor.properties")
    }

    private var isFreeSolver: Bool { page == .bankShot || page == .diamondSystem }
    private var directionTitle: String { isFreeSolver ? "自由" : (page == .snakePractice ? "重新开始" : (page == .drillTryout ? "重摆" : "开球")) }
    private var planningTitles: [String] {
        switch page {
        case .planThree: return ["计划", "摆球", "清除", "求解", "方案", "重打", "回放"]
        case .bankShot, .diamondSystem: return ["求解", "库数", "方案", "重打", "回放"]
        default: return ["摆球", "清除", "求解", "方案", "重打", "回放"]
        }
    }

    @ViewBuilder private func previewGroup(_ group: ControlLayoutGroup, frame: CGRect) -> some View {
        Group {
            switch group {
            case .instrument:
                BTShotInstrumentColumn(spinX: values.spinX, spinY: values.spinY, onSpinTap: page == .separationAngleAtlas ? nil : { spinOpen = true },
                    showsDisabledSpinEntry: page == .separationAngleAtlas, velocity: $values.speed, range: ShotTuning.velocityRange, isReadOnly: sequenceReadOnly, fixedPowerBarHeight: rulerHeight,
                    powerLabel: "杆速", compactPowerBarWidth: DailyLayoutMetrics.rulerWidth,
                    compactSpinButtonDiameter: topDiameter, compactGroupSpacing: 4)
            case .direction:
                VStack(spacing: 4) {
                    if page.controlLayoutFamily == .aimPointQuiz {
                        ControlLayoutAimPointInformationPreview().frame(height: topDiameter + 14)
                    } else if page == .shotSimulation {
                        VStack(spacing: 2) {
                            Text("切角 30°").font(.btMicro)
                            ThicknessOverlapIcon(cutAngle: 30).accessibilityHidden(true)
                            Text("厚薄 半球").font(.btMicro)
                        }.frame(height: topDiameter + 14).accessibilityLabel("示例切角30度，半球厚度")
                    } else {
                    Button { message = "已触达\(directionTitle)；练习局面保持不变。" } label: {
                        VStack(spacing: 2) {
                            Group {
                                if isFreeSolver { Image(systemName: "scope").font(.title2) }
                                else if page == .snakePractice { Image(systemName: "arrow.clockwise").font(.title2) }
                                else { BreakRackGlyph(color: HUDStyle.valueMeasured, size: topDiameter - 1, hollowBalls: true) }
                            }
                                .frame(width: topDiameter, height: topDiameter)
                                .background { BTHUDControlBackground(shape: Circle()) }
                                .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: 1))
                            Text(directionTitle).font(.btMicro)
                        }
                    }.buttonStyle(BTHUDPressStyle())
                    }
                    VStack(spacing: 6) {
                        BTAimWheel(onNudge: { values.direction += $0 }, degreeHapticEnabled: false,
                            visibleWidth: DailyLayoutMetrics.rulerWidth, showsDirectionLabel: false)
                            .frame(width: 44, height: rulerHeight)
                        Text("方向").font(.btMicro).foregroundStyle(.btTextSecondary)
                    }.disabled(sequenceReadOnly).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: BTRadius.xl).fill(HUDStyle.controlBackground))
                    if isFreeSolver {
                        let side: CGFloat = topDiameter == 56 ? 48 : 44
                        let verticalHeight = topDiameter + 14 + 4 + rulerHeight + 30 + 4 + 2 * side + 4
                        let horizontal = frame.height < verticalHeight - 0.5
                        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))
                        layout {
                            BTHUDCompactAction(title: "重打", symbol: "arrow.uturn.backward", size: side) { message = "已触达重打；练习局面保持不变。" }
                            BTHUDCompactAction(title: "回放", symbol: "play.rectangle", size: side) { message = "已触达回放；未播放训练。" }
                        }.frame(width: horizontal ? 2 * side + 4 : side)
                            .frame(width: frame.width, alignment: horizontal ? .trailing : .center)
                    }
                }
            case .primary:
                if page.controlLayoutFamily == .angleQuiz || page.controlLayoutFamily == .aimPointQuiz {
                    VStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Button { message = "示例辅助；题目保持不变。" } label: {
                            Text(page.controlLayoutFamily == .aimPointQuiz ? "角度提示" : "辅助").font(.btCaption)
                                .frame(width: 52, height: 52).background { BTHUDControlBackground(shape: Circle()) }
                        }.buttonStyle(BTHUDPressStyle())
                        Button(primaryTitle) { message = "示例操作；未提交训练。" }.frame(width: 52, height: 52).buttonStyle(DailyStrikeButtonStyle())
                    }.padding(.vertical, 8)
                } else {
                Button { message = "已触达\(primaryTitle)；练习局面保持不变。" } label: {
                    Text(primaryTitle).font(.btSubheadlineSemibold).frame(width: 60, height: 60)
                }.buttonStyle(DailyStrikeButtonStyle()).accessibilityIdentifier("layoutEditor.previewStrike")
                }
            case .camera:
                ShotPlayerCameraButtons(controlSpacing: 4, rig: values.camera, isEnabled: true,
                    onWholeTable: { message = "已触达全局观察。" }, usesTwoViewControls: true,
                    onTemporaryTopDownBegan: { message = "已触达临时俯视。" }, onSelect: { _ in message = "已触达相机切换。" })
            case .replay:
                let horizontal = frame.width > frame.height
                let layout = horizontal ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: 4))
                let side = horizontal ? frame.height : frame.width
                layout {
                    BTHUDCompactAction(title: page == .drillTryout || sequenceReadOnly ? "上一杆" : "重打", symbol: page == .drillTryout ? "backward.end" : "arrow.uturn.backward", size: side) { message = "已触达示例操作；练习局面保持不变。" }
                    BTHUDCompactAction(title: page == .drillTryout ? "下一杆" : (sequenceReadOnly ? "重播" : "回放"), symbol: page == .drillTryout ? "forward.end" : "play.rectangle", size: side) { message = "已触达示例操作；未播放训练。" }
                }
            case .keyboard:
                NumericKeypadHUD(input: $values.answer, title: "示例题目", subtitle: nil, compact: true,
                    usesSceneStyle: true, onSubmit: { message = "示例输入\(values.answer)，未提交训练。" },
                    onCancel: { values.answer = "" })
            case .information:
                if page.controlLayoutFamily == .angleQuiz {
                    ControlLayoutQuizInformationPreview()
                } else {
                ControlLayoutTeachingPreview(page: page, spinY: values.spinY, tracks: $values.tracks)
                }
            case .planning:
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(planningTitles, id: \.self) { title in
                            Button { message = "已触达\(title)；未执行训练操作。" } label: {
                                Text(title).font(.btCaption).frame(width: 44, height: 44)
                                    .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: 1))
                            }.buttonStyle(BTHUDPressStyle())
                        }
                    }.frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            default:
                VStack(spacing: 4) {
                    Button(group == .replay ? "重打" : group.title) { message = "已触达\(group.title)。" }.frame(minWidth: 44, minHeight: 44)
                    Button("回放") { message = "已触达回放；未播放训练。" }.frame(minWidth: 44, minHeight: 44)
                }
            }
        }.allowsHitTesting(interactive)
            .accessibilityElement(children: interactive ? .contain : .ignore)
            .accessibilityHidden(!interactive)
    }

    private func accept(_ candidate: ControlLayoutDraft) {
        guard domain == draft.domain else { message = "请回到原方向继续编辑。"; return }
        let status = ControlLayoutPlacement.place(resolved(candidate), in: previewInput, allowClamping: false).status
        guard status == .original || status == .customized else {
            message = "此位置空间不足或会遮挡其他控件，已保留原位置。"; return
        }
        let masked = layer == .common && candidate.isDirty && resolved(candidate).values == resolved(draft).values
        draft = candidate
        message = masked ? "已调整共用草稿；当前视图的独立设置优先。" : "已调整草稿，保存后应用。"
    }
    private func choose(_ selection: ControlLayoutSelection) {
        // Show the target page's defaults for missing groups. Keep local overrides
        // until the user explicitly restores them; preview does not publish a binding.
        draft.change { $0.selection = selection }
        message = "已预览模板；本页微调保留，保存后才应用。"
    }
    private func setLane(_ lane: ControlLayoutLane) {
        guard selected != .camera else { return }
        var next = draft
        next.change { $0.overrides[draft.address(selected, .lane, layer: layer)] = .lane(lane) }
        accept(next)
    }
    private func move(_ group: ControlLayoutGroup, by delta: CGFloat) {
        guard group != .camera else { message = "相机随杆速组移动，使用左右交换调整。"; return }
        let key = draft.address(group, .offset, layer: layer)
        var previous = 0.0
        if case .offset(let value) = draft.value(group, .offset, editing: layer) { previous = value }
        var next = draft
        next.change { $0.overrides[key] = .offset((previous + delta).rounded()) }
        accept(next)
    }
    private func mirrorCamera() {
        var next = draft
        let current = draft.value(.camera, .cameraSlot, editing: layer)
        next.change { $0.overrides[draft.address(.camera, .cameraSlot, layer: layer)] = .cameraSlot(current == .cameraSlot(.mirrored) ? .automatic : .mirrored) }
        accept(next)
    }
    private func swapColumns() {
        var next = draft
        next.change { binding in
            for (group, frame) in placement.frames where group != .camera {
                let leading = abs(frame.midX - input.leading.midX) < abs(frame.midX - input.trailing.midX)
                binding.overrides[draft.address(group, .lane, layer: layer)] = .lane(leading ? .trailing : .leading)
            }
        }
        accept(next)
    }
    private func restoreSelected() {
        var next = draft
        next.change { binding in
            for key in binding.overrides.keys where key.domain == domain && key.layer == layer && key.group == selected {
                binding.overrides.removeValue(forKey: key)
            }
        }
        accept(next)
    }
    private func reorder(by delta: Int) {
        guard selected != .camera, input.groupRegions[selected] == nil, let frame = placement.frames[selected] else { return }
        let isLeading = abs(frame.midX - input.leading.midX) < abs(frame.midX - input.trailing.midX)
        var ordered = placement.frames.keys.filter { group in
            guard group != .camera, input.groupRegions[group] == nil, let other = placement.frames[group] else { return false }
            return (abs(other.midX - input.leading.midX) < abs(other.midX - input.trailing.midX)) == isLeading
        }.sorted { (placement.frames[$0]?.minY ?? 0) < (placement.frames[$1]?.minY ?? 0) }
        guard let index = ordered.firstIndex(of: selected), ordered.indices.contains(index + delta) else {
            message = "已经位于这一侧的最前或最后。"; return
        }
        ordered.swapAt(index, index + delta)
        var next = draft
        next.change { binding in
            for (position, group) in ordered.enumerated() {
                binding.overrides[draft.address(group, .order, layer: layer)] = .order(position)
                binding.overrides[draft.address(group, .offset, layer: layer)] = .offset(0)
            }
        }
        accept(next)
    }
    private func save(newName: String? = nil) {
        do {
            if copyOnly || libraryPreview {
                guard let newName else { return }
                try store.preserveCopy(draft, id: UUID(), name: newName)
            } else { try store.save(draft, newTemplate: newName.map { (UUID(), $0) }) }
            onClose()
        } catch { conflict = (error as? ControlLayoutError) == .conflict; failure = error.localizedDescription }
    }
}

/// Sample readouts use the production visual controls with independent values.
struct ControlLayoutTeachingPreview: View {
    let page: TablePreferencePage
    var spinY = 0.0
    @Binding var tracks: Set<Int>
    private func toggle(_ index: Int) { tracks = AtlasSpinTrackSelection.toggle(tracks, index: index) }
    var body: some View {
        VStack(spacing: page == .angleDynamic ? 14 : 4) {
            metric("切角", "30°")
            if page == .angleDynamic {
                VStack(spacing: 3) {
                    ThicknessOverlapIcon(cutAngle: 30).frame(width: 26, height: 14)
                    Text("半球").font(.btCaption)
                }
                metric("d/R", "1.00")
                metric("横移", "28.6mm")
                metric("偏移", "50%")
            } else {
                if page == .cushionEnglishAtlas {
                    CushionEnglishAtlasSpinLegend(spinY: spinY, enabledTracks: tracks, onToggle: toggle)
                } else {
                    SeparationAngleAtlasSpinLegend(enabledTracks: tracks, onToggle: toggle)
                }
                Text("\(tracks.count)/8").font(.btCaption2).foregroundStyle(.white.opacity(0.6))
            }
        }.foregroundStyle(.white)
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.btCaption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.btFootnote.weight(.medium).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8)
        }.accessibilityElement(children: .combine)
    }
}

/// Synthetic question readout; never receives a live training run or answer.
struct ControlLayoutAimPointInformationPreview: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("示例题目"); Text("1/20"); Text("独立作答")
        }.font(.btCaption).monospacedDigit().foregroundStyle(HUDStyle.labelColor)
    }
}
