import SwiftUI
import SwiftData
import SceneKit

struct Scene2DAimingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AimingQuizViewModel
    @State private var showSubscription = false

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
        .safeAreaInset(edge: .top, spacing: 0) {
            topInset
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomInset
        }
        .navigationTitle("2D 瞄准训练")
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
            vm.quizTypeLabel = "scene2D"
            vm.configure(context: modelContext)
            vm.setupScene(initialCameraMode: .topDown2DRotated)
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
    }

    // MARK: - Top inset (progress pill OR result HUD)

    @ViewBuilder
    private var topInset: some View {
        HStack {
            if vm.phase == .showingResult, let record = vm.sessionResults.last {
                resultHUD(record: record)
            } else {
                progressPill
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .animation(.easeInOut(duration: 0.2), value: vm.phase)
    }

    // MARK: - Bottom inset (keypad when inputting; nothing otherwise)

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

    // MARK: - Scene (fullscreen)

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(.topDown2DRotated),
            interactionMode: vm.phase == .observing ? .tapsOnly : .none,
            onPocketTapped: { _ in /* fixed by question */ }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Overlay (FAB)

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
                // Keep the answer FAB clear of the bottom-right pocket marker.
                .padding(.bottom, Spacing.xl + 64)
                .transition(.scale.combined(with: .opacity))
            } else if vm.phase == .showingResult, !vm.testFinished {
                fab(icon: "arrow.right", title: nextButtonTitle) {
                    vm.advanceToNext()
                }
                .padding(.trailing, Spacing.lg)
                // Same location as the answer FAB: when 答题 disappears, 下一题 appears here.
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
                Text(progressText).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            divider
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.btCaption)
                Text(targetPocketText).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            divider
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill").font(.btCaption)
                Text(averageErrorText).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            if !vm.limiter.isPremium {
                divider
                Text("剩余 \(vm.limiter.remainingToday)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.btAccent)
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
}
