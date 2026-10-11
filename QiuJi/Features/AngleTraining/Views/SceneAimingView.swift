import SwiftUI
import SwiftData
import SceneKit

/// 角度训练（T-P18-48 拆两卡）：单 View 由两个 route 以 `initialCameraMode`
/// 参数化——「2D 角度训练」俯视练几何判断 / 「3D 角度训练」站位练临场球感。
/// 页内不再提供 2D ⇄ 3D toggle；成绩按视角分记 `quizType`（scene2D / scene3D）。
/// 入口流程（T-P18-48）：点卡先弹完整训练设置（模式/类型）再开始，训练中三点菜单可换。
struct SceneAimingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var pageColorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @State private var showSubscription = false
    @State private var isScenePrepared = false
    @State private var preferredPlayerView: CameraRig.PlayerView = .thirdPerson

    /// Camera mode is fixed per route (2D top-down or 3D perspective).
    private let routeCameraMode: AngleTrainingScene.CameraMode
    @State private var hasStarted = false
    @State private var cameraReadableFrame: CGRect?
    @State private var configured = false
    @State private var portrait = false
    @State private var showMenu = false
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = false
    @State private var titleSize = CGSize(width: 60, height: 34)
    @StateObject private var fps = TableFPSReadoutState()
    @ObservedObject private var preferences = UserPreferences.shared
    private var cameraMode: AngleTrainingScene.CameraMode {
        is3D ? .perspective3D : (portrait ? .topDown2DRotated : .topDown2D)
    }

    init(initialCameraMode: AngleTrainingScene.CameraMode) {
        self.routeCameraMode = initialCameraMode == .perspective3D ? .perspective3D : .topDown2D
        _vm = StateObject(wrappedValue: AimingQuizViewModel(limiter: .shared))
    }

    private var is3D: Bool { routeCameraMode == .perspective3D }

    var body: some View {
        Group {
            if !hasStarted { settingsContent }
            else { quizTable }
        }
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .trainingBackgroundMusic()
        .navigationTitle(hasStarted ? (is3D ? "3D角度" : "2D角度") : "训练设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background {
            if hasStarted {
                DailyTableOrientation(landscape: true, allowsTabletRotation: true)
            }
        }
        .toolbar(!hasStarted ? .visible : .hidden, for: .navigationBar)
        .statusBarHidden(hasStarted && UIDevice.current.userInterfaceIdiom != .pad)
        .sheet(isPresented: $vm.showSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            guard !configured else { return }
            configured = true
            vm.quizTypeLabel = is3D ? "scene3D" : "scene2D"
            vm.configure(context: modelContext)
            // Both routes defer renderer and orientation ownership until Start.
        }
        .onChange(of: vm.phase) { _, phase in
            if phase != .observing { vm.endTemporaryTopDown() }
        }
        .onDisappear { vm.endTemporaryTopDown() }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        // Each new question re-frames the aim line so the cue ball stays
        // pinned to its anchor and the target is visible past it.
        // K4：defer 到下一 runloop，避免 `advanceToNext` 先改 questionIndex
        // 触发本回调时 `nextQuestion()` 尚未 `applyBallLayout` → cueBallNode 偶发 nil
        // 早退，机位不复位（与成功走 enterAiming 的题形成忽近忽远）。
        .onChange(of: vm.questionIndex) { _, idx in
            DispatchQueue.main.async {
                applyAimingPoseForCurrentQuestion(reason: "onChange.questionIndex=\(idx)")
            }
        }
    }

    private func prepareScene() {
        guard !isScenePrepared else { return }
        vm.scene.configureReferenceTableRendering()
        vm.setupScene(initialCameraMode: cameraMode, enhanced: false, autoStart: false)
        isScenePrepared = true
    }

    private var quizTable: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            quizTemplate(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                .padding(.top, extraTop).padding(.bottom, extraBottom)
                .offset(x: -geo.safeAreaInsets.leading)
                .ignoresSafeArea(.container, edges: .trailing)
        }
    }

    private func quizTemplate(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let keys = PositionPlayBall.allKeys.filter { !PositionPlayBall.isCue($0) }
        let reservation = DailyLayoutMetrics.FoundationReservation(width: size.width - 2 * side,
            targetCount: keys.count, chineseEightBall: true, titleWidth: 92, actionWidth: 138,
            prefersSeparateRow: size.height > size.width || size.height >= 600,
            separateWidth: size.width > size.height && size.height < 600 ? size.width - 2 * (side + 68) : nil)
        let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: safe, trailingSafeArea: safe,
            halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
            halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth,
            instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight, palette: reservation)
        let plan = DailyLayoutMetrics.Palette(size: size, sideInset: side, table: f.table,
            targetCount: keys.count, chineseEightBall: true, obstacles: [
                CGRect(x: side + windowControls.left, y: 0, width: 44, height: 44),
                CGRect(x: side + windowControls.left + 32, y: (44 - titleSize.height) / 2,
                       width: titleSize.width, height: titleSize.height),
                CGRect(x: size.width - side - windowControls.right - 44, y: 0, width: 44, height: 44), f.left, f.right])
        let ppm = f.table.height / CGFloat(2 * (f.rotated
            ? (vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength)
            : (vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)))
        return ZStack(alignment: .topLeading) {
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: keys, chineseEightBall: true, titleWidth: titleSize.width, titleHeight: titleSize.height,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible,
                title: {
                    HStack(spacing: -12) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.btTitle2)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.accessibilityLabel("返回").accessibilityIdentifier("angleTraining.back")
                        BTTrainingPageTitle(text: is3D ? "3D角度" : "2D角度")
                            .background(GeometryReader { g in
                                Color.clear.preference(key: AngleQuizTitleSize.self, value: g.size)
                            })
                    }.fixedSize(horizontal: true, vertical: false)
                        .onPreferenceChange(AngleQuizTitleSize.self) { titleSize = $0 }
                }, actions: {
                    Button { showMenu = true } label: {
                        Image(systemName: BTIcon.menuCircle).font(.btTitle2)
                            .frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: Circle()) }
                    }.accessibilityLabel("更多").accessibilityIdentifier("angleTraining.settings")
                }, ball: { key, diameter, height in
                    let selected = PositionPlayBall.number(for: key) == vm.targetBallNumber
                    PoolBallFace(key: key, diameter: diameter).opacity(selected ? 1 : 0.25)
                        .overlay(Circle().stroke(selected ? HUDStyle.accent : .clear, lineWidth: 1))
                        .frame(width: diameter + 2, height: height)
                        .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
                        .accessibilityValue(selected ? "当前目标球" : "参考球")
                        .accessibilityIdentifier("angleTraining.ball." + key)
                }, paletteMarker: { Color.clear.accessibilityElement().accessibilityIdentifier("angleTraining.palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            Color.clear.accessibilityElement().accessibilityIdentifier("angleTraining.stage")
                .frame(width: f.stage.width, height: f.stage.height)
                .background(GeometryReader { g in
                    Color.clear.preference(key: AngleQuizReadableFrame.self, value: g.frame(in: .global))
                })
                .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            if is3D {
                observationColumn.position(x: f.right.midX - f.right.width / 2 - 26, y: f.table.midY)
            }
            questionInformation.frame(width: f.left.width).position(x: f.left.midX, y: f.table.midY)
            actionColumn.frame(height: min(200, f.stage.height)).position(x: f.right.midX, y: f.table.midY)
            if vm.phase == .inputting, !vm.testFinished {
                keypadOverlay.frame(width: min(280, f.stage.width))
                    .padding(.bottom, 8).padding(.trailing, size.width - f.stage.maxX)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if vm.testFinished {
                Color.black.opacity(0.32)
                ScrollView { summaryOverlay }.frame(width: min(520, size.width - 16), height: size.height - 32)
                    .position(x: size.width / 2, y: size.height / 2)
            } else if vm.limiter.isLimitReached {
                BTDailyLimitGate(compact: vm.phase == .showingResult) { showSubscription = true }
                    .frame(width: min(400, f.stage.width)).position(x: f.stage.midX, y: f.stage.midY)
            }
            if showMenu {
                Button { showMenu = false } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单").accessibilityIdentifier("angleTraining.dismissMenu")
                DailyHUDMenuPanel(title: nil, items: quizSettingsItems,
                    availableSize: CGSize(width: size.width - 2 * side, height: size.height - DailyLayoutMetrics.Panels.top - 8),
                    onBack: { showMenu = false }, onClose: { showMenu = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .frame(width: size.width, height: size.height)
        .background {
            // Daily Clearance's renderer ownership: measure the full window behind
            // the safe HUD, and keep one SCNView alive as projection/layout changes.
            GeometryReader { viewport in
                let fullFrame = viewport.frame(in: .global)
                let renderFrame = is3D ? fullFrame : (cameraReadableFrame ?? fullFrame)
                sceneFullscreen
                    .frame(width: renderFrame.width, height: renderFrame.height)
                    .position(x: renderFrame.midX - fullFrame.minX,
                              y: renderFrame.midY - fullFrame.minY)
                    .opacity(is3D || cameraReadableFrame != nil ? 1 : 0)
                    .allowsHitTesting(!showMenu)
            }
            .ignoresSafeArea()
        }
        .background {
            DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: ppm).ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark).environment(\.dailyHUDControls, true)
        .onChange(of: size.height > size.width, initial: true) { _, rotated in
            portrait = rotated
            if !is3D { vm.setCameraMode(rotated ? .topDown2DRotated : .topDown2D) }
            showMenu = false
        }
        .onPreferenceChange(AngleQuizReadableFrame.self) { cameraReadableFrame = $0 }
        .sheet(isPresented: $showSubscription) { SubscriptionView().environmentObject(subscriptionManager) }
    }

    private var quizSettingsItems: [DailyHUDMenuItem] {
        [.init(id: "angleTraining.display", title: "显示"),
         .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: preferences.showTableGrid, action: {
            preferences.showTableGrid.toggle(); vm.scene.setTableGridVisible(preferences.showTableGrid)
            showMenu = false
         }),
         .init(id: "angleTraining.trainingSettings", title: "训练设置", disclosure: true, action: {
            showMenu = false; vm.showSettings = true
         })]
    }

    private var questionInformation: some View {
        Group {
            if vm.phase == .showingResult, let record = vm.sessionResults.last { resultHUD(record: record) }
            else if vm.currentQuestion != nil { progressPill }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("angleTraining.questionInfo")
    }

    // MARK: - 答题键盘浮层（G10：不改变 scene 高度）

    private var keypadOverlay: some View {
        NumericKeypadHUD(
            input: $vm.userInput,
            title: "第 \(vm.questionIndex + 1) 题",
            subtitle: "目标袋口：\(targetPocketText)",
            compact: true,
            usesSceneStyle: true,
            onSubmit: { vm.submitAnswer() },
            onCancel: { vm.cancelAnswerInput() }
        )
        .environment(\.colorScheme, pageColorScheme)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: - Scene (fullscreen)

    @ViewBuilder
    private var sceneFullscreen: some View {
        if isScenePrepared {
            AngleSceneView(
                scene: vm.scene,
                cameraMode: .constant(cameraMode),
                interactionMode: interactionMode,
                // Landscape uses the same whole-table fitting as Daily Clearance.
                // World ball positions and the question's pocket index stay fixed.
                autoFitsLandscapeTable: !is3D,
                backgroundColor: is3D ? .black : .clear,
                onPocketTapped: nil, // The question owns the pocket.
                contentIsAnimating: vm.cameraTransitionBusy,
                fpsReadoutState: fps,
                twoViewReadableFrameInWindow: is3D ? cameraReadableFrame : nil,
                onCameraObservationBegan: { vm.beginCameraObservation() },
                onCameraObservationEnded: { vm.endCameraObservation() },
                onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
                topDownContentRevision: vm.topDownContentRevision,
                usesStandardTemporaryTable: is3D
            )
            .clipped()
            .accessibilityIdentifier("angleTraining.scene")
        } else {
            // setupScene 会装载 USDZ 并建立大量 mesh/material。先在 renderer
            // 尚未连接时完成构建，再创建 SCNView；否则 iOS 17 iPad 上渲染线程
            // 可能与 C3D scene flush 并发访问半成品 mesh 而 EXC_BAD_ACCESS。
            Color.black
        }
    }

    /// 3D + observing: full pan/pinch so the user can swipe yaw and zoom
    /// between aim/observation poses.
    /// 2D + observing: taps only, mirroring `Scene2DAimingView` (the
    /// orthographic top-down is meant to be a fixed reference frame).
    /// inputting / showingResult: all gestures disabled so the keypad and
    /// result HUD aren't fighting touch events.
    private var interactionMode: AngleSceneView.InteractionMode {
        guard vm.phase == .observing, !showMenu, !vm.showSettings, !vm.testFinished,
              !vm.limiter.isLimitReached else { return .none }
        return is3D ? .cameraControl : .tapsOnly
    }

    // MARK: - Question actions

    @ViewBuilder private var observationColumn: some View {
        if let rig = vm.scene.cameraRig {
            ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                isEnabled: vm.phase != .inputting && !vm.showSettings && !showMenu
                    && vm.currentQuestion != nil && !vm.testFinished && !vm.limiter.isLimitReached,
                onWholeTable: { vm.requestSurfaceOverview() },
                usesTwoViewControls: rig.usesTwoViewCameraControls,
                temporaryTopDownActive: vm.temporaryTopDownActive,
                onTemporaryTopDownBegan: { vm.beginTemporaryTopDown() },
                onTemporaryTopDownEnded: { vm.endTemporaryTopDown() },
                onSelect: { requestPlayerView($0) })
        }
    }

    private var actionColumn: some View {
        VStack(spacing: Spacing.sm) {
            Spacer(minLength: 0)
            if vm.phase == .observing, !vm.testFinished, vm.currentQuestion != nil,
               !vm.limiter.isLimitReached {
                Button { vm.toggleAimingAssist() } label: {
                    Text(vm.showAimingAssist ? "隐藏" : "辅助")
                        .font(.btSubheadlineSemibold)
                        .foregroundStyle(vm.showAimingAssist ? HUDStyle.accent : .white)
                        .frame(width: 52, height: 52)
                        .background { BTHUDControlBackground(shape: Circle()) }
                        .overlay(Circle()
                            .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                }
                .buttonStyle(BTHUDPressStyle())
                .accessibilityIdentifier("angleTraining.assist")
                .accessibilityValue(vm.showAimingAssist ? "已开启" : "已关闭")
                primaryAction("答题") { vm.openAnswerInput() }
            } else if vm.phase == .showingResult, !vm.testFinished, !vm.limiter.isLimitReached {
                primaryAction(nextButtonTitle) { vm.advanceToNext() }
            }
        }
        .frame(width: 60)
        .padding(.vertical, Spacing.sm)
        .environment(\.colorScheme, .dark)
    }

    private func primaryAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.btSubheadlineSemibold)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(DailyStrikeButtonStyle())
        .accessibilityIdentifier("angleTraining.primaryAction")
    }

    // MARK: - Top progress pill (observing / inputting)

    /// 统计 chip 前缀（题/袋/差/剩余，T-P18-49 / D9）：与几何角度训练同一 `BTReadout` 语法。
    private var progressPill: some View {
        VStack(spacing: Spacing.sm) {
            sideMetric("题目", value: progressText)
            sideMetric("目标袋", value: targetPocketText)
            sideMetric("平均误差", value: averageErrorText)
            if !vm.limiter.isPremium {
                sideMetric("剩余", value: "\(vm.limiter.remainingToday)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
    }

    private func sideMetric(_ label: String, value: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.btCaption2).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.btCaption.weight(.semibold)).foregroundStyle(color)
                .monospacedDigit().lineLimit(1)
        }
    }

    private var progressText: String {
        if vm.isFreePractice { return "\(vm.questionIndex + 1)" }
        return "\(vm.questionIndex + 1)/\(vm.totalQuestions)"
    }

    private var averageErrorText: String {
        guard !vm.sessionResults.isEmpty else { return "—" }
        return String(format: "%.1f°", vm.averageError)
    }

    private var targetPocketText: String {
        guard let question = vm.currentQuestion else { return "—" }
        // Perspective can orbit: describe the highlighted pocket, not a screen direction.
        if is3D { return question.pocket.type == .corner ? "高亮角袋" : "高亮中袋" }
        // topDown2D: screen-right = +X; screen-down = +Z (normalized y).
        let names = portrait
            ? ["左下角袋", "左上角袋", "右下角袋", "右上角袋", "左侧中袋", "右侧中袋"]
            : ["左上角袋", "右上角袋", "左下角袋", "右下角袋", "上侧中袋", "下侧中袋"]
        return names.indices.contains(question.pocketIndex) ? names[question.pocketIndex] : "—"
    }

    // MARK: - Top result HUD

    private func resultHUD(record: AimingQuizViewModel.AnswerRecord) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(vm.errorRating.label).font(.btCaption.weight(.semibold))
                .foregroundStyle(vm.errorRating.color)
            sideMetric("作答", value: "\(Int(record.userAngle))°")
            sideMetric("答案", value: "\(Int(record.question.actualAngle))°", color: HUDStyle.accent)
            sideMetric("误差", value: String(format: "%.0f°", record.error), color: vm.errorRating.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
    }

    private var nextButtonTitle: String {
        if vm.isFreePractice { return "下一题" }
        if vm.questionIndex + 1 < vm.totalQuestions, !vm.limiter.isLimitReached {
            return "下一题"
        }
        return "总结"
    }

    // MARK: - Settings Sheet

    /// 同一份训练设置：两个入口首次由外层导航承载，训练中从共用菜单打开。
    private var settingsSheet: some View {
        NavigationStack { settingsContent }
    }

    private var settingsContent: some View {
            List {
                Section("练习模式") {
                    Picker("模式", selection: $vm.practiceMode) {
                        ForEach(AimingQuizViewModel.PracticeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("训练类型") {
                    ForEach(AimingQuizViewModel.TrainingType.allCases) { type in
                        Button {
                            vm.trainingType = type
                        } label: {
                            HStack {
                                Text(type.rawValue).foregroundStyle(.btText)
                                Spacer()
                                if vm.trainingType == type {
                                    Image(systemName: "checkmark").foregroundStyle(.btPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("训练设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!hasStarted)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.currentQuestion == nil ? "开始训练" : "重新开始") {
                        prepareScene()
                        hasStarted = true
                        vm.showSettings = false
                        vm.startTest()
                        applyAimingPoseForCurrentQuestion(reason: "settingsConfirm.startTest")
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("angleTraining.start")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasStarted ? "完成" : "返回") {
                        if hasStarted { vm.showSettings = false } else { dismiss() }
                    }.accessibilityIdentifier("angleTraining.settingsClose")
                }
            }
    }

    // MARK: - Summary

    private var summaryOverlay: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.btSuccess)
            Text("测试完成").font(.btTitle).foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                summaryCard(title: "题数", value: "\(vm.sessionResults.count)")
                summaryCard(title: "平均误差", value: String(format: "%.1f°", vm.averageError))
                summaryCard(title: "精准 (≤3°)", value: "\(vm.accurateCount)")
            }

            if vm.limiter.isLimitReached {
                BTDailyLimitGate(compact: true) { showSubscription = true }
                    .padding(.horizontal, Spacing.xxxxl)
            }
        }
        .padding(Spacing.xl)
        .btHudGlass(in: RoundedRectangle(cornerRadius: BTRadius.xl))
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, Spacing.lg)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView().environmentObject(subscriptionManager)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value).font(.btTitle2).foregroundStyle(.white).monospacedDigit()
            Text(title).font(.btCaption).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Camera framing helpers

    /// Reframe each new question with the selected player view and its new cue → target line.
    private func applyAimingPoseForCurrentQuestion(reason: String = "unspecified") {
        guard cameraMode == .perspective3D else {
            #if DEBUG
            print("[SceneAiming.applyAimingPose] skip reason=\(reason) (not perspective3D)")
            #endif
            return
        }
        guard let cueBall = vm.scene.cueBallNode else {
            // K4 复现路径：早退不复位 → 保住上一题 zoom（常为近景「正常」）。
            #if DEBUG
            print("[SceneAiming.applyAimingPose] EARLY_RETURN cueBallNode==nil reason=\(reason) qIndex=\(vm.questionIndex) zoom=\(vm.scene.cameraRig?.zoom ?? -1)")
            #endif
            return
        }
        guard let dir = vm.currentPlayerAim else { return }
        #if DEBUG
        print(String(format:
            "[SceneAiming.applyAimingPose] ENTER reason=%@ qIndex=%d cue=(%.3f,%.3f,%.3f) dir=(%.3f,%.3f) prevZoom=%.2f",
            reason, vm.questionIndex,
            cueBall.position.x, cueBall.position.y, cueBall.position.z,
            dir.x, dir.z, vm.scene.cameraRig?.zoom ?? -1))
        #endif
        // A new question hides the cue: reset its reference so the prior ball layout cannot leak.
        vm.scene.cameraRig?.updateCuePose(strike: cueBall.position, aim: dir, elevation: 0.05, cue: cueBall.position)
        requestPlayerView(preferredPlayerView)
    }

    private func requestPlayerView(_ view: CameraRig.PlayerView) {
        guard is3D else { return }
        preferredPlayerView = view
        vm.requestPlayerView(view)
    }

}

#Preview("2D · Light") {
    NavigationStack {
        SceneAimingView(initialCameraMode: .topDown2DRotated)
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.light)
}

#Preview("3D · Dark") {
    NavigationStack {
        SceneAimingView(initialCameraMode: .perspective3D)
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}

private struct AngleQuizTitleSize: PreferenceKey {
    static let defaultValue = CGSize(width: 60, height: 34)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct AngleQuizReadableFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

/// The four training routes share the existing title reservation; renaming must
/// not feed a wider budget back into the palette/table layout.
struct BTTrainingPageTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.btFootnote.weight(.semibold)).lineLimit(1)
            .frame(width: 60, height: 34, alignment: .leading)
            .accessibilityIdentifier("training.pageTitle")
    }
}
