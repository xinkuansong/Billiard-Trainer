import SwiftUI
import SwiftData
import SceneKit

struct Scene3DAimingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @FocusState private var inputFocused: Bool
    @State private var showSubscription = false
    @State private var viewMode: CameraRig.ViewMode = .observation

    init() {
        _vm = StateObject(wrappedValue: AimingQuizViewModel(limiter: AngleUsageLimiter()))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                viewModeToggle
                sceneContainer
            }

            if vm.testFinished {
                summaryOverlay
            } else if vm.showResult {
                resultHUD
            } else {
                inputHUD
            }
        }
        .background(.black)
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
            settingsSheet
                .presentationDetents([.medium])
        }
        .onAppear {
            vm.quizTypeLabel = "scene3D"
            vm.configure(context: modelContext)
            vm.setupScene(initialCameraMode: .perspective3D)
            enterObservation()
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack {
            Picker("视角", selection: $viewMode) {
                Text("观察").tag(CameraRig.ViewMode.observation)
                Text("瞄准").tag(CameraRig.ViewMode.aiming)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .onChange(of: viewMode) { _, newValue in
                switch newValue {
                case .observation:
                    enterObservation()
                case .aiming:
                    enterAiming()
                }
            }

            Spacer()

            Button {
                vm.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.black.opacity(0.8))
    }

    private func enterObservation() {
        guard let cueBall = vm.scene.cueBallNode else { return }
        let aimDir = SCNVector3(-1, 0, 0)
        vm.scene.cameraRig?.enterObservation(cueBallPosition: cueBall.position, aimDirection: aimDir)
    }

    private func enterAiming() {
        guard let cueBall = vm.scene.cueBallNode else { return }
        let targetDir: SCNVector3
        if let target = vm.scene.targetBallNodes.first {
            targetDir = SCNVector3(target.position.x - cueBall.position.x, 0, target.position.z - cueBall.position.z)
        } else {
            targetDir = SCNVector3(-1, 0, 0)
        }
        vm.scene.cameraRig?.enterAiming(cueBallPosition: cueBall.position, targetDirection: targetDir)
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
                                Text(type.rawValue)
                                    .foregroundStyle(.btText)
                                Spacer()
                                if vm.trainingType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.btPrimary)
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

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(.perspective3D),
            onPocketTapped: { index in
                vm.selectedPocketIndex = index
            }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Input HUD

    private var inputHUD: some View {
        VStack(spacing: Spacing.md) {
            progressRow

            if let q = vm.currentQuestion {
                Text("目标袋口：\(q.pocket.label)")
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: Spacing.sm) {
                HStack(spacing: 2) {
                    TextField("角度", text: $vm.userInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .focused($inputFocused)
                    Text("°")
                        .font(.btTitle)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 120, height: 52)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .onTapGesture {
                    inputFocused = true
                }

                Button("确认") {
                    inputFocused = false
                    vm.submitAnswer()
                }
                .buttonStyle(BTButtonStyle.primary)
                .disabled(vm.userInput.isEmpty)
            }

            if !vm.limiter.isPremium {
                Text("今日剩余 \(vm.limiter.remainingToday)")
                    .font(.btCaption)
                    .foregroundStyle(.btAccent)
            }
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xl))
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Result HUD

    private var resultHUD: some View {
        VStack(spacing: Spacing.md) {
            if let record = vm.sessionResults.last {
                HStack {
                    Text(vm.errorRating.label)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(vm.errorRating.color)
                        .clipShape(Capsule())
                    Spacer()
                    Text("第 \(vm.questionIndex) / \(vm.totalQuestions) 题")
                        .font(.btCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                HStack(spacing: Spacing.xl) {
                    resultColumn(value: "\(Int(record.userAngle))°", label: "你的答案", color: .white)
                    resultColumn(value: "\(Int(record.question.actualAngle))°", label: "正确答案", color: .btPrimary)
                    resultColumn(value: "\(Int(record.error))°", label: "误差", color: vm.errorRating.color)
                }

                if vm.isFreePractice || (vm.questionIndex < vm.totalQuestions && !vm.limiter.isLimitReached) {
                    Button("下一题") { vm.advanceToNext() }
                        .buttonStyle(BTButtonStyle.primary)
                } else {
                    Button("查看总结") { vm.advanceToNext() }
                        .buttonStyle(BTButtonStyle.primary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xl))
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Summary

    private var summaryOverlay: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.btSuccess)

            Text("测试完成")
                .font(.btTitle)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                summaryCard(title: "题数", value: "\(vm.sessionResults.count)")
                summaryCard(title: "平均误差", value: String(format: "%.1f°", vm.averageError))
                summaryCard(title: "精准 (≤3°)", value: "\(vm.accurateCount)")
            }

            if vm.limiter.isLimitReached {
                VStack(spacing: Spacing.sm) {
                    Text("今日免费次数已用完")
                        .font(.btHeadline)
                        .foregroundStyle(.white)
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
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xl))
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: - Helpers

    private var progressRow: some View {
        HStack {
            Text("第 \(vm.questionIndex + 1) / \(vm.totalQuestions) 题")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.white)
            Spacer()
            GeometryReader { geo in
                Capsule()
                    .fill(.white.opacity(0.2))
                    .overlay(alignment: .leading) {
                        let frac = CGFloat(vm.questionIndex) / CGFloat(vm.totalQuestions)
                        Capsule()
                            .fill(Color.btPrimary)
                            .frame(width: geo.size.width * frac)
                    }
            }
            .frame(width: 100, height: 6)
        }
    }

    private func resultColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.btTitle)
                .foregroundStyle(color)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.btTitle2)
                .foregroundStyle(.white)
            Text(title)
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}
