import SwiftUI

enum DrillLevel: String, Codable, CaseIterable {
    case L0, L1, L2, L3, L4

    var displayName: String {
        switch self {
        case .L0: return "入门"
        case .L1: return "初级"
        case .L2: return "中级"
        case .L3: return "高级"
        case .L4: return "专家"
        }
    }
}

struct BTLevelBadge: View {
    let level: DrillLevel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(level.rawValue) \(level.displayName)")
            .font(.btCaption2)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(textColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }

    private var textColor: Color {
        if colorScheme == .dark {
            return darkTextColor
        }
        switch level {
        case .L0: return .white
        case .L1: return Color(red: 0, green: 0x7A / 255.0, blue: 1)
        case .L2: return Color(red: 0xD4 / 255.0, green: 0x94 / 255.0, blue: 0x1A / 255.0)
        case .L3: return Color(red: 0xE6 / 255.0, green: 0x51 / 255.0, blue: 0)
        case .L4: return Color(red: 0xC6 / 255.0, green: 0x28 / 255.0, blue: 0x28 / 255.0)
        }
    }

    private var darkTextColor: Color {
        switch level {
        case .L0: return Color(red: 0x25 / 255.0, green: 0xA2 / 255.0, blue: 0x5A / 255.0)
        case .L1: return Color(red: 0x0A / 255.0, green: 0x84 / 255.0, blue: 0xFF / 255.0)
        case .L2: return Color(red: 0xF0 / 255.0, green: 0xAD / 255.0, blue: 0x30 / 255.0)
        case .L3: return Color(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0)
        case .L4: return Color(red: 0xEF / 255.0, green: 0x53 / 255.0, blue: 0x50 / 255.0)
        }
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return darkTextColor.opacity(0.15)
        }
        switch level {
        case .L0: return .btPrimary
        case .L1: return Color(red: 0, green: 0x7A / 255.0, blue: 1).opacity(0.15)
        case .L2: return Color(red: 0xD4 / 255.0, green: 0x94 / 255.0, blue: 0x1A / 255.0).opacity(0.15)
        case .L3: return Color(red: 0xE6 / 255.0, green: 0x51 / 255.0, blue: 0).opacity(0.15)
        case .L4: return Color(red: 0xC6 / 255.0, green: 0x28 / 255.0, blue: 0x28 / 255.0).opacity(0.15)
        }
    }
}

#Preview("Levels Light") {
    HStack(spacing: Spacing.sm) {
        ForEach(DrillLevel.allCases, id: \.self) { level in
            BTLevelBadge(level: level)
        }
    }
    .padding()
    .background(.btBG)
}

#Preview("Levels Dark") {
    HStack(spacing: Spacing.sm) {
        ForEach(DrillLevel.allCases, id: \.self) { level in
            BTLevelBadge(level: level)
        }
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
