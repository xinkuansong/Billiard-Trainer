import SwiftUI

/// Shared explanatory copy in training forms; inherits the caller's font and color.
struct BTTrainingSettingsNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: "info.circle").accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A secondary action at the end of a training settings form. The caller owns the draft.
struct BTTrainingSettingsResetSection: View {
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
                    .font(.btBody)
                    .foregroundStyle(.btPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("training.resetDefaults")
            .accessibilityHint("恢复本页设置，开始练习后生效")
        }
    }
}

#Preview("Light") { Form { BTTrainingSettingsResetSection {} }.preferredColorScheme(.light) }
#Preview("Dark") { Form { BTTrainingSettingsResetSection {} }.preferredColorScheme(.dark) }
