import SwiftUI
import SwiftData
import SceneKit

/// 角度训练（T-P18-48 拆两卡）：单 View 由两个 route 以 `initialCameraMode`
/// 参数化——「2D 角度训练」俯视练几何判断 / 「3D 角度训练」站位练临场球感。
/// 页内不再提供 2D ⇄ 3D toggle；成绩按视角分记 `quizType`（scene2D / scene3D）。
/// 入口流程（T-P18-48）：点卡先弹完整训练设置（模式/类型）再开始，训练中三点菜单可换。
struct SceneAimingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @State private var showSubscription = false
    @State private var isScenePrepared = false
    @State private var preferredPlayerView: CameraRig.PlayerView = .thirdPerson

    /// Camera mode is fixed per route (2D top-down or 3D perspective).
    private let cameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) {
        self.cameraMode = initialCameraMode == .perspective3D ? .perspective3D : .topDown2D
        _vm = StateObject(wrappedValue: AimingQuizViewModel(limiter: .shared))
    }

    private var is3D: Bool { cameraMode == .perspective3D }

    // The reference palette keeps a fixed header through every question phase.
    private static let topRowHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                if is3D { sceneFullscreen.ignoresSafeArea() }
                VStack(spacing: 0) {
                    topInset
                        .frame(height: Self.topRowHeight)
                    HStack(spacing: Spacing.sm) {
                        observationColumn
                        ZStack {
                            if !is3D { sceneFullscreen }
                            if vm.phase == .showingResult, !vm.testFinished, vm.limiter.isLimitReached {
                                BTDailyLimitGate(compact: true) { showSubscription = true }
                                    .padding(Spacing.lg)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear.accessibilityElement()
                            .accessibilityIdentifier("angleTraining.stage"))
                        actionColumn
                    }
                    .padding(.horizontal, Spacing.xs)
                }
                if vm.phase == .inputting, !vm.testFinished {
                    keypadOverlay
                        .frame(width: min(280, geo.size.width * 0.44))
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                if vm.testFinished {
                    // F-OV-05: modal summary — light scrim keeps table readable.
                    ZStack {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()
                        ScrollView { summaryOverlay }
                            .frame(maxWidth: 520, maxHeight: max(geo.size.height - 32, 1))
                    }
                    .transition(.opacity)
                } else if vm.limiter.isLimitReached, vm.phase != .showingResult {
                    // C23：满额主卡（full）；总结/结果区另用 compact。
                    ZStack {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()
                        BTDailyLimitGate { showSubscription = true }
                            .padding(.horizontal, Spacing.lg)
                    }
                    .transition(.opacity)
                    .sheet(isPresented: $showSubscription) {
                        SubscriptionView().environmentObject(subscriptionManager)
                    }
                }
            }
            .animation(BTMotion.easeChrome, value: vm.phase)
            .animation(BTMotion.easeChrome, value: vm.testFinished)
            .animation(BTMotion.easeChrome, value: vm.limiter.isLimitReached)
        }
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .trainingBackgroundMusic()
        .btDarkToolChrome(is3D ? "3D 角度训练" : "2D 角度训练")
        .background { DailyTableOrientation(landscape: true) }
        .ignoresSafeArea(.container, edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .sheet(isPresented: $vm.showSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            vm.quizTypeLabel = is3D ? "scene3D" : "scene2D"
            vm.configure(context: modelContext)
            // 入口流程（T-P18-48）：先建场景但不出题，弹完整训练设置，
            // 用户点「开始训练」后才 startTest。
            // 渲染统一（条 11.2 / ADR-P5-01）：弃 enhanced 管线，与其他球桌页同走
            // 默认的移动渲染管线（2D/3D 同源），观感一致。
            if !isScenePrepared {
                vm.setupScene(initialCameraMode: cameraMode, enhanced: false, autoStart: false)
                if is3D {
                    vm.scene.cameraRig?.usesRailCameraControls = true
                    vm.scene.cameraRig?.usesShotAwareCamera = true
                }
                isScenePrepared = true
            }
            vm.showSettings = true
        }
        // Sheet dismissed by swipe before ever starting → start with the
        // currently-selected defaults so the page is never a dead end.
        .onChange(of: vm.showSettings) { _, showing in
            if !showing, vm.currentQuestion == nil, !vm.testFinished {
                vm.startTest()
                applyAimingPoseForCurrentQuestion(reason: "settingsDismissed.startTest")
            }
        }
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

    // MARK: - Top inset (progress pill OR result HUD)

    private var topInset: some View {
        HStack(spacing: Spacing.sm) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.btTitle2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("angleTraining.back")
            Text(is3D ? "3D 角度训练" : "2D 角度训练")
                .font(.btSubheadlineSemibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            topBallPalette
            Spacer(minLength: 0)
            Button { vm.showSettings = true } label: {
                Image(systemName: "ellipsis")
                    .font(.btHeadline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("训练设置")
            .accessibilityIdentifier("angleTraining.settings")
        }
        .padding(.horizontal, Spacing.xs)
        .foregroundStyle(.white)
        .background(is3D ? HUDStyle.controlBackground : Color.black)
        .environment(\.colorScheme, .dark)
    }

    /// Reference-only palette: the question owns the balls; changing a ball would change the task.
    private var topBallPalette: some View {
        GeometryReader { geo in
            let keys = PositionPlayBall.allKeys
            let diameter = min(24, max(12, (geo.size.width - CGFloat(keys.count - 1) * 3) / CGFloat(keys.count)))
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    let isTarget = PositionPlayBall.number(for: key) == vm.targetBallNumber
                    PoolBallFace(key: key, diameter: diameter)
                        .opacity(isTarget || key == PositionPlayBall.cueKey ? 1 : 0.25)
                        .overlay(Circle().stroke(isTarget ? HUDStyle.accent : Color.clear, lineWidth: 2))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("球库，当前目标球\(vm.targetBallNumber)号")
        .accessibilityIdentifier("angleTraining.palette")
        .allowsHitTesting(false)
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
        .environment(\.colorScheme, .dark)
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
                // Anchor-lock only matters in 3D — in 2D the camera is already
                // fixed top-down. The lock guard inside AngleSceneView already
                // bypasses it for non-perspective modes, so this is just an
                // extra defence.
                locksCueBallScreenAnchor: is3D,
                // Landscape uses the same whole-table fitting as Daily Clearance.
                // World ball positions and the question's pocket index stay fixed.
                autoFitsLandscapeTable: !is3D,
                onPocketTapped: nil // Target pocket is fixed by the question; no selection action.
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
        guard vm.phase == .observing, !vm.showSettings, !vm.testFinished,
              !vm.limiter.isLimitReached else { return .none }
        return is3D ? .cameraControl : .tapsOnly
    }

    // MARK: - Question actions

    private var observationColumn: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 0)
            if is3D {
                if let rig = vm.scene.cameraRig {
                    ShotPlayerCameraButtons(rig: rig,
                        isEnabled: vm.phase == .observing && vm.currentQuestion != nil && !vm.testFinished,
                        onWholeTable: {
                            vm.scene.discardSavedPerspectiveView()
                            rig.observeWholeTable()
                        }, onSelect: { requestPlayerView($0) })
                }
                BTSceneObservationMenu(scene: vm.scene,
                    targetNode: vm.scene.targetBallNodes.first,
                    pocketIndex: vm.selectedPocketIndex,
                    identifierPrefix: "angleTraining") {
                        requestPlayerView(.firstPerson)
                    }
                    .background(HUDStyle.controlBackground, in: RoundedRectangle(cornerRadius: BTRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: BTRadius.md)
                        .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                    .disabled(vm.phase != .observing || vm.currentQuestion == nil || vm.testFinished)
            }
        }
        .frame(width: 52)
        .padding(.vertical, Spacing.sm)
    }

    private var actionColumn: some View {
        VStack(spacing: Spacing.sm) {
            Group {
                if vm.phase == .showingResult, let record = vm.sessionResults.last {
                    resultHUD(record: record)
                } else if vm.currentQuestion != nil {
                    progressPill
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("angleTraining.questionInfo")
            Spacer(minLength: 0)
            if vm.phase == .observing, !vm.testFinished, vm.currentQuestion != nil,
               !vm.limiter.isLimitReached {
                Button { vm.toggleAimingAssist() } label: {
                    Text(vm.showAimingAssist ? "隐藏" : "辅助")
                        .font(.btSubheadlineSemibold)
                        .foregroundStyle(vm.showAimingAssist ? HUDStyle.accent : .white)
                        .frame(width: 52, height: 44)
                        .background(HUDStyle.controlBackground, in: RoundedRectangle(cornerRadius: BTRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("angleTraining.assist")
                .accessibilityValue(vm.showAimingAssist ? "已开启" : "已关闭")
                primaryAction("答题") { vm.openAnswerInput() }
            } else if vm.phase == .showingResult, !vm.testFinished, !vm.limiter.isLimitReached {
                primaryAction(nextButtonTitle) { vm.advanceToNext() }
            }
        }
        .frame(width: 96)
        .padding(.vertical, Spacing.sm)
        .environment(\.colorScheme, .dark)
    }

    private func primaryAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.btSubheadlineSemibold)
                .frame(width: 52, height: 52)
                .foregroundStyle(HUDStyle.onAccent)
                .background(HUDStyle.accent, in: Circle())
                .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }
        .buttonStyle(.plain)
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
        let names = ["左上角袋", "右上角袋", "左下角袋", "右下角袋", "上侧中袋", "下侧中袋"]
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

    /// 完整训练设置（T-P18-48 入口流程）：进页先弹本 sheet 再开始；训练中
    /// 三点再开、点「开始训练」按新设置重开一轮。§1.6：浮出层统一暗材质。
    private var settingsSheet: some View {
        NavigationStack {
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
                Section("显示") {
                    BTTableGridMenuToggle(scene: vm.scene)
                }
            }
            .navigationTitle("训练设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.currentQuestion == nil ? "开始训练" : "重新开始") {
                        vm.showSettings = false
                        vm.startTest()
                        applyAimingPoseForCurrentQuestion(reason: "settingsConfirm.startTest")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        // §1.6 浮出层统一暗材质：preferredColorScheme 能同时压暗 sheet 的
        // presentation 背景（environment(\.colorScheme) 只影响内容层）。
        .preferredColorScheme(.dark)
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
        let dir = cueToTargetDirection()
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
        guard is3D, let cue = vm.scene.cueBallNode, let rig = vm.scene.cameraRig else { return }
        preferredPlayerView = view
        vm.scene.discardSavedPerspectiveView()
        rig.observationCandidates = [cue.position] + vm.scene.targetBallNodes.map(\.position)
        rig.enterPlayerView(view, cue: cue.position, aim: cueToTargetDirection(),
            duration: UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.95)
    }

    /// World-space horizontal vector cue → target, or `-X` fallback.
    private func cueToTargetDirection() -> SCNVector3 {
        guard let cueBall = vm.scene.cueBallNode else { return SCNVector3(-1, 0, 0) }
        guard let target = vm.scene.targetBallNodes.first else { return SCNVector3(-1, 0, 0) }
        let dx = target.position.x - cueBall.position.x
        let dz = target.position.z - cueBall.position.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.0001 else { return SCNVector3(-1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
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
