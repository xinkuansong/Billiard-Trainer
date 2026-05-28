import SwiftUI
import SwiftData
import SceneKit

/// 3D 瞄准训练 page. Mirrors `Scene2DAimingView`'s layout (top progress
/// pill / result HUD, FAB column, numeric-keypad bottom inset, settings
/// sheet) so that the only behavioural delta from the 2D page is a single
/// segmented 2D / 3D toggle that flips the rendered camera mode.
struct Scene3DAimingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @State private var showSubscription = false

    /// Live camera mode, driven by the 2D / 3D segmented toggle. Default
    /// `.perspective3D` so the page opens in the 3D study view.
    @State private var cameraMode: AngleTrainingScene.CameraMode = .perspective3D

    init() {
        _vm = StateObject(wrappedValue: AimingQuizViewModel(limiter: AngleUsageLimiter()))
    }

    var body: some View {
        ZStack {
            sceneFullscreen
            overlayLayer
            if vm.testFinished { summaryOverlay }
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topInset }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomInset }
        .navigationTitle("3D 瞄准训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $vm.showSettings) {
            settingsSheet.presentationDetents([.medium])
        }
        .onAppear {
            vm.quizTypeLabel = "scene3D"
            vm.configure(context: modelContext)
            vm.setupScene(initialCameraMode: .perspective3D, enhanced: true)
            // Land down the natural cue→target aim line on first open.
            applyAimingPoseForCurrentQuestion()
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        // Each new question re-frames the aim line so the cue ball stays
        // pinned to its anchor and the target is visible past it.
        .onChange(of: vm.questionIndex) { _, _ in
            applyAimingPoseForCurrentQuestion()
        }
        // Animated 2D ⇄ 3D transition when the user taps the toggle.
        // `setCameraMode` + the scene's `transitionToPerspective` already
        // land the camera at the aim pose down the cue → target line; no
        // additional re-aim call is needed.
        .onChange(of: cameraMode) { _, newValue in
            vm.scene.setCameraMode(newValue, animated: true)
            // Re-issue any active visualization so its line-label flag picks
            // up the new mode (3D hides 瞄准线 / 进球线 inline text).
            vm.refreshVisualization()
        }
    }

    // MARK: - Top inset (progress pill OR result HUD, plus 2D / 3D toggle)

    @ViewBuilder
    private var topInset: some View {
        HStack(spacing: Spacing.sm) {
            if vm.phase == .showingResult, let record = vm.sessionResults.last {
                resultHUD(record: record)
            } else {
                progressPill
            }
            Spacer()
            modeToggle
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
    }

    /// 2D / 3D segmented control. Replaces the old 观察 / 瞄准 picker —
    /// observation vs aiming is now driven by the vertical swipe gesture
    /// (zoom = 0 → low aiming pose, zoom = 1 → high observation pose).
    private var modeToggle: some View {
        Picker("视图", selection: $cameraMode) {
            Text("2D").tag(AngleTrainingScene.CameraMode.topDown2DRotated)
            Text("3D").tag(AngleTrainingScene.CameraMode.perspective3D)
        }
        .pickerStyle(.segmented)
        // 72 leaves room for "2D"/"3D" labels but keeps the pill room
        // wide enough to render its 4 cells on a single line.
        .frame(width: 72)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Bottom inset (numeric keypad while inputting)

    @ViewBuilder
    private var bottomInset: some View {
        if vm.phase == .inputting, !vm.testFinished {
            NumericKeypadHUD(
                input: $vm.userInput,
                title: "第 \(vm.questionIndex + 1) 题",
                subtitle: vm.currentQuestion.map { "目标袋口：\($0.pocket.label)" },
                onSubmit: { vm.submitAnswer() },
                onCancel: { vm.cancelAnswerInput() }
            )
        }
    }

    // MARK: - Scene (fullscreen)

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $cameraMode,
            interactionMode: interactionMode,
            // Anchor-lock only matters in 3D — in 2D the camera is already
            // fixed top-down. The lock guard inside AngleSceneView already
            // bypasses it for non-perspective modes, so this is just an
            // extra defence.
            locksCueBallScreenAnchor: cameraMode == .perspective3D,
            onPocketTapped: { _ in /* fixed by question */ }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    /// 3D + observing: full pan/pinch so the user can swipe yaw and zoom
    /// between aim/observation poses.
    /// 2D + observing: taps only, mirroring `Scene2DAimingView` (the
    /// orthographic top-down is meant to be a fixed reference frame).
    /// inputting / showingResult: all gestures disabled so the keypad and
    /// result HUD aren't fighting touch events.
    private var interactionMode: AngleSceneView.InteractionMode {
        guard vm.phase == .observing else { return .none }
        return cameraMode == .perspective3D ? .cameraControl : .tapsOnly
    }

    // MARK: - Overlay (FAB column)

    private var overlayLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            if vm.phase == .observing, !vm.testFinished {
                VStack(spacing: Spacing.md) {
                    fab(
                        icon: vm.showAimingAssist ? "eye.slash.fill" : "scope",
                        title: vm.showAimingAssist ? "隐藏" : "辅助"
                    ) {
                        vm.toggleAimingAssist()
                    }
                    .opacity(vm.showAimingAssist ? 1.0 : 0.92)

                    fab(icon: "pencil.and.list.clipboard", title: "答题") {
                        vm.openAnswerInput()
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl + 64)
                .transition(.scale.combined(with: .opacity))
            } else if vm.phase == .showingResult, !vm.testFinished {
                fab(icon: "arrow.right", title: nextButtonTitle) {
                    vm.advanceToNext()
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl + 64)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.phase)
    }

    // MARK: - Top progress pill (observing / inputting)

    private var progressPill: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: 4) {
                Image(systemName: "list.number").font(.btCaption)
                Text(progressText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            divider
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.btCaption)
                Text(targetPocketText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            divider
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill").font(.btCaption)
                Text(averageErrorText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            if !vm.limiter.isPremium {
                divider
                Text("剩余 \(vm.limiter.remainingToday)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.btAccent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
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
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private func resultStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private var nextButtonTitle: String {
        if vm.isFreePractice { return "下一题" }
        if vm.questionIndex + 1 < vm.totalQuestions, !vm.limiter.isLimitReached {
            return "下一题"
        }
        return "总结"
    }

    // MARK: - FAB

    private func fab(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.btPrimary, Color(red: 0.0, green: 0.45, blue: 0.25)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 64, height: 64)
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Sheet

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
            }
            .navigationTitle("训练设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        vm.showSettings = false
                        vm.startTest()
                    }
                }
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
                VStack(spacing: Spacing.sm) {
                    Text("今日免费次数已用完").font(.btHeadline).foregroundStyle(.white)
                    Button { showSubscription = true } label: {
                        Label("解锁全部内容", systemImage: "crown.fill")
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .padding(.horizontal, Spacing.xxxxl)
                }
            }
        }
        .padding(Spacing.xl)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xl))
        .padding(.horizontal, Spacing.lg)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView().environmentObject(subscriptionManager)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value).font(.btTitle2).foregroundStyle(.white)
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
