import SwiftUI

struct TrainingNoteView: View {
    @Binding var note: String
    let onSkip: () -> Void
    let onComplete: () -> Void
    /// Post-training flow calls this「跳过」; editing an existing note calls it「取消」.
    var skipTitle: String = "跳过"
    var showsCompletionActions: Bool = true
    var onSaveDraft: (() -> Void)? = nil
    // TODO: [P1-U02] Wire up "隐藏备注" toggle — requires TrainingSessionSummary model change to persist hideNote flag

    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditorFocused = false

    private let softLimit = 500

    var body: some View {
        VStack(spacing: 0) {
            hintSection
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
            editorSection
                .padding(.horizontal, Spacing.lg)
                .frame(maxHeight: .infinity)

            if !note.isEmpty {
                characterCountHint
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !isEditorFocused, let onSaveDraft {
                HStack {
                    Spacer()
                    Button("保存", action: onSaveDraft)
                        .buttonStyle(BTButtonStyle.primary)
                        .frame(width: 120)
                        .accessibilityIdentifier("trainingNote.save")
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }

            if showsCompletionActions && !isEditorFocused {
                bottomBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xs)
            }
        }
        .background(Color.btBG.ignoresSafeArea())
        .animation(BTMotion.easeFast, value: note.isEmpty)
        .onAppear { isEditorFocused = true }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditorFocused {
                HStack {
                    Spacer()
                    Button { isEditorFocused = false } label: {
                        Image(systemName: BTKeyboardDismissMetrics.symbolName)
                            .font(.system(size: BTKeyboardDismissMetrics.symbolSize, weight: .semibold))
                            .foregroundStyle(Color.btPrimary)
                            .frame(width: BTKeyboardDismissMetrics.buttonWidth,
                                   height: BTKeyboardDismissMetrics.buttonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("收起键盘")
                    .accessibilityIdentifier("trainingNote.dismissKeyboard")
                }
                .padding(.horizontal, Spacing.lg)
                .background(Color.btBG)
            }
        }
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
            BTNumberedNoteEditor(text: $note, isFocused: $isEditorFocused,
                                 identifier: "trainingNote.editor")

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

    // MARK: - Character Count (F-TS-10)

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

    // MARK: - Bottom Bar (F-TR-10)

    private var bottomBar: some View {
        HStack {
            Button(skipTitle, action: onSkip)
                .buttonStyle(BTButtonStyle.text)

            Spacer()

            Button("完成", action: onComplete)
                .buttonStyle(BTButtonStyle.primary)
                .frame(width: 120)
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


/// Session editing is transactional: returning or dismissing discards local edits.
struct TrainingNoteDraftView: View {
    @State private var draft: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    init(note: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        _draft = State(initialValue: note)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            TrainingNoteView(note: $draft, onSkip: onCancel, onComplete: {},
                             showsCompletionActions: false,
                             onSaveDraft: { onSave(draft) })
                .navigationTitle("训练心得")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("返回训练", action: onCancel)
                            .accessibilityIdentifier("trainingNote.returnToTraining")
                    }
                }
        }
    }
}
