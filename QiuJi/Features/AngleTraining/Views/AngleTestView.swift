import SwiftUI
import SwiftData

struct AngleTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
        }
        .background(.btBG)
        .navigationTitle("角度测试")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.configure(context: modelContext); vm.startTest() }
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text("第 \(vm.questionIndex + (vm.testFinished ? 0 : 1)) / \(vm.totalQuestions) 题")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                if !vm.limiter.isPremium {
                    Text("今日剩余 \(vm.limiter.remainingToday)")
                        .font(.btCaption)
                        .foregroundStyle(.btAccent)
                }
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.btBGTertiary)
                    .overlay(alignment: .leading) {
                        let frac = CGFloat(vm.questionIndex) / CGFloat(vm.totalQuestions)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.btPrimary)
                            .frame(width: geo.size.width * frac)
                    }
            }
            .frame(height: 4)
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
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: Spacing.lg) {
            if let q = vm.currentQuestion {
                Text("目标袋口：\(q.pocket.label)（\(q.pocketType == .corner ? "角袋" : "中袋")）")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
            }

            HStack(spacing: Spacing.md) {
                TextField("0–90", text: $vm.userInput)
                    .keyboardType(.numberPad)
                    .font(.btDisplay)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .focused($inputFocused)
                Text("°")
                    .font(.btLargeTitle)
                    .foregroundStyle(.btTextSecondary)
            }

            Button(action: { inputFocused = false; vm.submitAnswer() }) {
                Text("确认")
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(vm.userInput.isEmpty)
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(spacing: Spacing.lg) {
            if let record = vm.sessionResults.last {
                HStack(spacing: Spacing.xxxl) {
                    statBubble(title: "正确", value: "\(Int(record.question.actualAngle))°", color: .btSuccess)
                    statBubble(title: "你的答案", value: "\(Int(record.userAngle))°", color: .btPrimary)
                    statBubble(title: "误差", value: "±\(Int(record.error))°", color: vm.errorRating.color)
                }

                Text(vm.errorRating.label)
                    .font(.btHeadline)
                    .foregroundStyle(vm.errorRating.color)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.lg)
                    .background(vm.errorRating.color.opacity(0.12))
                    .clipShape(Capsule())
            }

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
        }
    }

    // MARK: - Helpers

    private func statBubble(title: String, value: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.btTitle)
                .foregroundStyle(color)
            Text(title)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

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
