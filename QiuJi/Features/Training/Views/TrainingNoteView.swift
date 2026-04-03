import SwiftUI

struct TrainingNoteView: View {
    @Binding var note: String
    let drillCount: Int
    let elapsedSeconds: Int
    let onSkip: () -> Void
    let onComplete: () -> Void

    private let softLimit = 500

    private var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                statsRow
                noteInputSection
                actionButtons
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("训练心得")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.btPrimary)

            Text("记录训练心得")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("记录本次训练的感受和收获\n帮助下次训练更有方向")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: Spacing.lg) {
            statBadge(icon: "clock", value: formattedTime, label: "训练时长")
            statBadge(icon: "list.bullet", value: "\(drillCount)", label: "训练项目")
        }
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(value)
                    .font(.btHeadline)
            }
            .foregroundStyle(.btText)

            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Note Input

    private var noteInputSection: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $note)
                    .font(.btBody)
                    .foregroundStyle(.btText)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)

                if note.isEmpty {
                    Text("今天的训练感觉如何？有哪些收获或需要改进的地方...")
                        .font(.btBody)
                        .foregroundStyle(.btTextTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.md)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(Color.btSeparator, lineWidth: 0.5)
            )

            if !note.isEmpty {
                Text(note.count > softLimit
                    ? "已输入 \(note.count) 字 · 建议精简至 \(softLimit) 字以内"
                    : "已输入 \(note.count) 字")
                    .font(.btCaption)
                    .foregroundStyle(note.count > softLimit ? .btWarning : .btTextTertiary)
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            Button(action: onComplete) {
                Label("保存心得", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(BTButtonStyle.primary)
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: onSkip) {
                Text("跳过")
            }
            .buttonStyle(BTButtonStyle.text)
        }
        .padding(.top, Spacing.md)
    }
}

// MARK: - Previews

#Preview("Empty") {
    NavigationStack {
        TrainingNoteView(
            note: .constant(""),
            drillCount: 3,
            elapsedSeconds: 1234,
            onSkip: {},
            onComplete: {}
        )
    }
}

#Preview("With Text") {
    NavigationStack {
        TrainingNoteView(
            note: .constant("今天专注练习了直线球和斜角球，发现瞄准点偏左的问题，需要调整站位。低杆的发力还需要更稳定。"),
            drillCount: 5,
            elapsedSeconds: 2700,
            onSkip: {},
            onComplete: {}
        )
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        TrainingNoteView(
            note: .constant(""),
            drillCount: 2,
            elapsedSeconds: 900,
            onSkip: {},
            onComplete: {}
        )
    }
    .preferredColorScheme(.dark)
}
