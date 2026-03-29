import SwiftUI

enum DrillLevel: String, Codable, CaseIterable {
    case L0, L1, L2, L3, L4

    var color: Color {
        switch self {
        case .L0: return .btTextSecondary
        case .L1: return .btPrimary
        case .L2: return .blue
        case .L3: return .purple
        case .L4: return .btAccent
        }
    }

    var displayName: String {
        switch self {
        case .L0: return "入门"
        case .L1: return "初级"
        case .L2: return "中级"
        case .L3: return "高级"
        case .L4: return "专业"
        }
    }
}

struct BTLevelBadge: View {
    let level: DrillLevel

    var body: some View {
        Text(level.rawValue)
            .font(.btCaption2)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(level.color.opacity(0.15))
            .foregroundStyle(level.color)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }
}

#Preview("Levels") {
    HStack(spacing: Spacing.sm) {
        ForEach(DrillLevel.allCases, id: \.self) { level in
            BTLevelBadge(level: level)
        }
    }
    .padding()
    .background(.btBG)
}
