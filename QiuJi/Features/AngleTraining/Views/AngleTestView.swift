import SwiftUI
import SwiftData

struct AngleTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm: AngleTestViewModel
    @FocusState private var inputFocused: Bool
    @State private var showSubscription = false

    init(limiter: AngleUsageLimiter) {
        _vm = StateObject(wrappedValue: AngleTestViewModel(limiter: limiter))
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    if vm.testFinished {
                        summarySection
                    } else {
                        tableSection
                        if vm.showResult { resultSection } else { inputSection }
                    }
                }
                .padding(Spacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                if vm.showResult && !vm.testFinished {
                    bottomActionButton
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(.btBG)
                }
            }
        }
        .background(.btBG)
        .navigationTitle("角度测试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { vm.configure(context: modelContext); vm.startTest() }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text("第 \(vm.questionIndex + (vm.testFinished ? 0 : 1)) 题")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Spacer()
                Text("共 \(vm.totalQuestions) 题")
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(Color.btBGTertiary)
                    .overlay(alignment: .leading) {
                        let frac = CGFloat(vm.questionIndex) / CGFloat(vm.totalQuestions)
                        Capsule()
                            .fill(Color.btPrimary)
                            .frame(width: geo.size.width * frac)
                    }
            }
            .frame(height: 6)
            if !vm.limiter.isPremium {
                HStack {
                    Spacer()
                    Text("今日剩余 \(vm.limiter.remainingToday)")
                        .font(.btCaption)
                        .foregroundStyle(.btAccent)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.btBGSecondary)
    }

    // MARK: - Table

    private var tableSection: some View {
        BTAngleTestTable(question: vm.currentQuestion,
                         showResult: vm.showResult,
                         userAngle: vm.sessionResults.last?.userAngle)
            .padding(Spacing.md)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("请估算切入角度")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            if let q = vm.currentQuestion {
                Text("目标袋口：\(q.pocket.label)（\(q.pocketType == .corner ? "角袋" : "中袋")）")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
            }

            HStack(spacing: Spacing.xs) {
                TextField("0", text: $vm.userInput)
                    .keyboardType(.numberPad)
                    .font(.btLargeTitle)
                    .multilineTextAlignment(.center)
                    .focused($inputFocused)
                Text("°")
                    .font(.btTitle.weight(.regular))
                    .foregroundStyle(.btTextSecondary)
            }
            .frame(width: 180, height: 64)
            .background(.btBGSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(Color.btPrimary, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))

            Text("范围: 5° - 85°")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            Button(action: { inputFocused = false; vm.submitAnswer() }) {
                Text("确认")
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(vm.userInput.isEmpty)
            .frame(width: 200)
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.lg) {
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
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("你答了 ") + Text("\(Int(record.userAngle))°").bold() +
                        Text("，实际是 ") + Text("\(Int(record.question.actualAngle))°")
                            .bold().foregroundColor(.btPrimary)
                        Text("误差 \(Int(record.error))°")
                            .font(.btTitle)
                            .foregroundStyle(vm.errorRating.color)
                    }
                    .font(.btBody)
                    .foregroundStyle(.btText)

                    Divider()

                    Text("提示：容差 ±3° 内为精准。注意观察目标球与袋口的连线，再反推击球点。")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .lineSpacing(4)
                }
            }
            .padding(Spacing.xl)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
                    radius: 8, x: 0, y: 2)

            HStack {
                Text("当前正确率")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                let correct = vm.sessionResults.filter { $0.error <= 3 }.count
                Text("\(correct)/\(vm.sessionResults.count)")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                let pct = vm.sessionResults.isEmpty ? 0 : Double(correct) / Double(vm.sessionResults.count) * 100
                Text(String(format: "%.0f%%", pct))
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

        }
    }

    private var bottomActionButton: some View {
        Group {
            if vm.questionIndex + 1 < vm.totalQuestions, !vm.limiter.isLimitReached {
                Button("下一题") { vm.advanceToNext() }
                    .buttonStyle(BTButtonStyle.primary)
            } else {
                Button("查看总结") { vm.advanceToNext() }
                    .buttonStyle(BTButtonStyle.primary)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.btSuccess)

            Text("测试完成")
                .font(.btTitle)
                .foregroundStyle(.btText)

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
                        .foregroundStyle(.btText)
                    Text("解锁会员，无限练习")
                        .font(.btCallout)
                        .foregroundStyle(.btTextSecondary)
                    Button { showSubscription = true } label: {
                        Label("解锁全部内容", systemImage: "crown.fill")
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .padding(.horizontal, Spacing.xxxxl)
                }
                .padding(.top, Spacing.lg)
            }

            Button("返回") { dismiss() }
                .buttonStyle(BTButtonStyle.secondary)
        }
        .padding(.top, Spacing.xl)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: - Helpers

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.btTitle2)
                .foregroundStyle(.btText)
            Text(title)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

#Preview("Light") {
    NavigationStack {
        AngleTestView(limiter: AngleUsageLimiter())
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    }
}

#Preview("Dark") {
    NavigationStack {
        AngleTestView(limiter: AngleUsageLimiter())
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    }
    .preferredColorScheme(.dark)
}
