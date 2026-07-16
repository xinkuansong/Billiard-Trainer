import SwiftUI
import SwiftData
import SceneKit

/// 瞄准训练（T-P18-48 拆两卡）：单 View 由两个 route 以 `initialCameraMode`
/// 参数化——「2D 瞄准训练」俯视练几何判断 / 「3D 瞄准训练」站位练临场球感。
/// 页内不再提供 2D ⇄ 3D toggle；成绩按视角分记 `quizType`（scene2D / scene3D）。
/// 入口流程（T-P18-48）：点卡先弹完整训练设置（模式/类型）再开始，训练中齿轮可换。
struct SceneAimingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @State private var showSubscription = false

    /// Camera mode is fixed per route (2D top-down or 3D perspective).
    private let cameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) {
        self.cameraMode = initialCameraMode
        _vm = StateObject(wrappedValue: AimingQuizViewModel(limiter: AngleUsageLimiter()))
    }

    private var is3D: Bool { cameraMode == .perspective3D }

    /// G10：顶栏 / 底栏定高锁桌（C11 → `ShotStageMetrics`）；2D 底栏 = 装饰球库。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

    /// 球桌外框实测半尺寸（装桌前 USDZ 兜底），供 ShotStageProxy 对齐球桌矩形。
    private var tableExtents: (length: Double, width: Double) {
        if let rig = vm.scene.cameraRig {
            return (rig.tableOuterHalfLength, rig.tableOuterHalfWidth)
        }
        return (ShotTableLayout.defaultHalfLength, ShotTableLayout.defaultHalfWidth)
    }

    var body: some View {
        GeometryReader { geo in
            let extents = tableExtents
            let bottomH: CGFloat = is3D ? 0 : Self.bottomBarHeight
            let sceneH = max(geo.size.height - Self.topRowHeight - bottomH, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: extents.length, halfWidth: extents.width
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topInset
                        .frame(height: Self.topRowHeight)
                    ZStack {
                        sceneFullscreen
                        overlayLayer(proxy)
                    }
                    .frame(height: sceneH)
                    if !is3D {
                        decorativePalette(proxy)
                            .frame(height: Self.bottomBarHeight)
                    }
                }
                // 答题键盘：浮层（不改变 scene 高度，G10 球桌尺寸锁定）。
                if vm.phase == .inputting, !vm.testFinished {
                    keypadOverlay
                }
                if vm.testFinished {
                    // F-OV-05: modal summary — light scrim keeps table readable.
                    ZStack {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()
                        summaryOverlay
                    }
                    .transition(.opacity)
                }
            }
            .animation(BTMotion.easeChrome, value: vm.phase)
            .animation(BTMotion.easeChrome, value: vm.testFinished)
        }
        .navigationTitle(is3D ? "3D 角度训练" : "2D 角度训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(title: is3D ? "3D 角度训练" : "2D 角度训练")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.showSettings.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
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
            // 渲染统一（条 11.2）：弃 enhanced 管线（IBL+studio 光把台呢抬得发灰白），
            // 与其他球桌页同走 plain 管线，观感一致。
            vm.setupScene(initialCameraMode: cameraMode, enhanced: false, autoStart: false)
            vm.showSettings = true
        }
        // Sheet dismissed by swipe before ever starting → start with the
        // currently-selected defaults so the page is never a dead end.
        .onChange(of: vm.showSettings) { _, showing in
            if !showing, vm.currentQuestion == nil, !vm.testFinished {
                vm.startTest()
                applyAimingPoseForCurrentQuestion()
            }
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        // Each new question re-frames the aim line so the cue ball stays
        // pinned to its anchor and the target is visible past it.
        .onChange(of: vm.questionIndex) { _, _ in
            applyAimingPoseForCurrentQuestion()
        }
    }

    // MARK: - Top inset (progress pill OR result HUD)

    @ViewBuilder
    private var topInset: some View {
        HStack(spacing: Spacing.sm) {
            if vm.phase == .showingResult, let record = vm.sessionResults.last {
                resultHUD(record: record)
            } else if vm.currentQuestion != nil {
                progressPill
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.black)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 答题键盘浮层（G10：不改变 scene 高度）

    private var keypadOverlay: some View {
        NumericKeypadHUD(
            input: $vm.userInput,
            title: "第 \(vm.questionIndex + 1) 题",
            subtitle: vm.currentQuestion.map { "目标袋口：\($0.pocket.label)" },
            compact: true,
            onSubmit: { vm.submitAnswer() },
            onCancel: { vm.cancelAnswerInput() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 装饰性球库（条 6.4：不可交互，仅为页面布局与其他球桌页一致）

    /// 两排 16 球、当前题目标球高亮，其余压暗；不可点、不可拖。
    /// G8：排球总宽 = 球桌宽（固定列宽求和），两侧留白。
    private func decorativePalette(_ proxy: ShotStageProxy) -> some View {
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(8))
        let row2 = Array(all.dropFirst(8))
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        let columnWidth = max(libraryWidth / 8, 1)
        return VStack(spacing: 3) {
            ForEach([row1, row2], id: \.self) { keys in
                HStack(spacing: 0) {
                    ForEach(keys, id: \.self) { key in
                        PoolBallFace(key: key, diameter: 34)
                            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
                            .frame(width: columnWidth, height: 38)
                            .opacity(PositionPlayBall.number(for: key) == vm.targetBallNumber ? 1 : 0.25)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .allowsHitTesting(false)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Scene (fullscreen)

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(cameraMode),
            interactionMode: interactionMode,
            // Anchor-lock only matters in 3D — in 2D the camera is already
            // fixed top-down. The lock guard inside AngleSceneView already
            // bypasses it for non-perspective modes, so this is just an
            // extra defence.
            locksCueBallScreenAnchor: is3D,
            // P6.1：2D 走统一自适应取景（球桌大小与其他击打页一致，
            // ShotStageProxy 的球桌矩形据此解析；3D 透视不受影响）。
            autoFitsRotatedTable: !is3D,
            onPocketTapped: { _ in /* fixed by question */ }
        )
        .clipped()
    }

    /// 3D + observing: full pan/pinch so the user can swipe yaw and zoom
    /// between aim/observation poses.
    /// 2D + observing: taps only, mirroring `Scene2DAimingView` (the
    /// orthographic top-down is meant to be a fixed reference frame).
    /// inputting / showingResult: all gestures disabled so the keypad and
    /// result HUD aren't fighting touch events.
    private var interactionMode: AngleSceneView.InteractionMode {
        guard vm.phase == .observing else { return .none }
        return is3D ? .cameraControl : .tapsOnly
    }

    // MARK: - Overlay (FAB column)

    private func overlayLayer(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            // P6.2：辅助/答题放**球桌右侧**（2D 走 ShotStageProxy 贴边——左缘贴
            // 球桌右缘、底边齐球桌底线，与全局击打页动作列同一布局语法；
            // 3D 透视无球桌矩形，保持右下浮动）。
            if vm.phase == .observing, !vm.testFinished, vm.currentQuestion != nil {
                positioned(proxy, size: CGSize(width: ShotStageMetrics.actionColumnWidth,
                                               height: 68)) {
                    VStack(spacing: 8) {
                        BTTextActionButton(title: vm.showAimingAssist ? "隐藏" : "辅助",
                                           width: ShotStageMetrics.actionColumnWidth) {
                            vm.toggleAimingAssist()
                        }
                        BTTextActionButton(title: "答题", role: .primary,
                                           width: ShotStageMetrics.actionColumnWidth) {
                            vm.openAnswerInput()
                        }
                    }
                }
            } else if vm.phase == .showingResult, !vm.testFinished {
                positioned(proxy, size: CGSize(width: ShotStageMetrics.actionColumnWidth,
                                               height: 30)) {
                    BTTextActionButton(title: nextButtonTitle, role: .primary,
                                       width: ShotStageMetrics.actionColumnWidth) {
                        vm.advanceToNext()
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.phase)
    }

    /// 动作按钮组按 2D/3D 分别定位：2D 贴球桌右缘齐底线（G6/G11），3D 右下浮动。
    @ViewBuilder
    private func positioned<Content: View>(
        _ proxy: ShotStageProxy, size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if !is3D, proxy.isValid {
            content()
                .btStageFrame(proxy.bottomTrailingFrame(size: size))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        } else {
            content()
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl + 64)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottomTrailing)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: - Top progress pill (observing / inputting)

    /// 统计 chip 单字前缀（题/袋/差/剩，T-P18-49）：SF 图标换单字 label，
    /// 与几何角度训练指标条同一 `BTReadout` 语法。
    private var progressPill: some View {
        HStack(spacing: Spacing.md) {
            BTReadout(label: "题", value: progressText)
                .fixedSize(horizontal: true, vertical: false)
            divider
            BTReadout(label: "袋", value: targetPocketText)
                .fixedSize(horizontal: true, vertical: false)
            divider
            BTReadout(label: "差", value: averageErrorText)
                .fixedSize(horizontal: true, vertical: false)
            if !vm.limiter.isPremium {
                divider
                BTReadout(label: "剩", value: "\(vm.limiter.remainingToday)",
                          emphasis: .adjustable, size: .compact)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
    }

    private var progressText: String {
        if vm.isFreePractice { return "\(vm.questionIndex)" }
        return "\(vm.questionIndex)/\(vm.totalQuestions)"
    }

    private var averageErrorText: String {
        guard !vm.sessionResults.isEmpty else { return "—" }
        return String(format: "%.1f°", vm.averageError)
    }

    private var targetPocketText: String {
        vm.currentQuestion?.pocket.label ?? "—"
    }

    // MARK: - Top result HUD

    private func resultHUD(record: AimingQuizViewModel.AnswerRecord) -> some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 3) {
                Circle().fill(vm.errorRating.color).frame(width: 7, height: 7)
                Text(vm.errorRating.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            divider
            resultStat(label: "你", value: "\(Int(record.userAngle))°", color: .white)
            resultStat(label: "答", value: "\(Int(record.question.actualAngle))°", color: .btPrimary)
            resultStat(label: "差", value: String(format: "%.0f°", record.error),
                       color: vm.errorRating.color)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .btHudGlass()
    }

    private func resultStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(HUDStyle.labelFont)
                .foregroundStyle(HUDStyle.labelColor)
            Text(value)
                .font(HUDStyle.valueFont)
                .foregroundStyle(color)
                .monospacedDigit()
        }
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
    /// 齿轮再开、点「开始训练」按新设置重开一轮。§1.6：浮出层统一暗材质。
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
                        applyAimingPoseForCurrentQuestion()
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

    /// Re-aim the rig down the cue → target line for the current question's
    /// ball layout, using the aiming pose (low/close). Only meaningful in
    /// `.perspective3D`; safe to call in 2D (the rig still updates yaw
    /// internally but the orthographic camera ignores yaw).
    private func applyAimingPoseForCurrentQuestion() {
        guard cameraMode == .perspective3D,
              let cueBall = vm.scene.cueBallNode else { return }
        vm.scene.cameraRig?.enterAiming(
            cueBallPosition: cueBall.position,
            targetDirection: cueToTargetDirection()
        )
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
