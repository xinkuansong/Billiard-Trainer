import SwiftUI

/// A secondary action at the end of a training settings form. The caller owns the draft.
struct BTTrainingSettingsResetSection: View {
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                Label("恢复默认设置", systemImage: "arrow.counterclockwise")
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
