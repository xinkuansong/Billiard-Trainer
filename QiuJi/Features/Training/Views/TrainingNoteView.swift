import SwiftUI

struct TrainingNoteView: View {
    @Binding var note: String
    let onSkip: () -> Void
    let onComplete: () -> Void
    // TODO: [P1-U02] Wire up "隐藏备注" toggle — requires TrainingSessionSummary model change to persist hideNote flag

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEditorFocused: Bool

    private let softLimit = 500

    var body: some View {
        VStack(spacing: 0) {
            hintSection
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

            editorSection
                .padding(.horizontal, Spacing.lg)

            Spacer(minLength: 0)

            if !note.isEmpty {
                characterCountHint
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xs)
            }

            bottomBar
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
        }
        .background(Color.btBG.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onAppear { isEditorFocused = true }
    }

    // MARK: - Hint Section

    private var hintSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("1、您可以输入一些今天的训练感悟")
            Text("2、还可以记录需要注意的技术要点")
        }
        .font(.btFootnote)
        .foregroundStyle(.btTextSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editor

    private var editorSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note)
                .font(.btBody)
                .foregroundStyle(.btText)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)

            if note.isEmpty {
                Text("在此开始记录...")
                    .font(.btBody)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.top, 8)
                    .padding(.leading, Spacing.xs)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Character Count

    private var characterCountHint: some View {
        HStack {
            Spacer()
            Text(note.count > softLimit
                ? "\(note.count) 字 · 建议精简至 \(softLimit) 字以内"
                : "\(note.count) 字")
                .font(.btCaption)
                .foregroundStyle(note.count > softLimit ? .btWarning : .btTextTertiary)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button(action: onSkip) {
                Text("跳过")
                    .font(.btCallout)
                    .fontWeight(.medium)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            Button(action: onComplete) {
                Text("完成")
                    .font(.btCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xxxl)
                    .padding(.vertical, Spacing.lg)
                    .background(Color.btPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.btPrimary.opacity(0.15),
                        radius: 8, y: 4
                    )
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty - Light") {
    NavigationStack {
        TrainingNoteView(
            note: .constant(""),
            onSkip: {},
            onComplete: {}
        )
        .navigationTitle("训练心得")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("With Text") {
    NavigationStack {
        TrainingNoteView(
            note: .constant("今天专注练习了直线球和斜角球，发现瞄准点偏左的问题，需要调整站位。低杆的发力还需要更稳定。"),
            onSkip: {},
            onComplete: {}
        )
        .navigationTitle("训练心得")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Empty - Dark") {
    NavigationStack {
        TrainingNoteView(
            note: .constant(""),
            onSkip: {},
            onComplete: {}
        )
        .navigationTitle("训练心得")
        .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
