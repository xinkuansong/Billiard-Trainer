import SwiftUI

// MARK: - User Preferences

enum PreferredSport: String, CaseIterable, Identifiable {
    case chinese8 = "chinese8"
    case nineBall = "nineBall"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese8: return "中式台球"
        case .nineBall: return "9球"
        case .both:     return "两者"
        }
    }
}

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var preferredSport: PreferredSport {
        didSet { UserDefaults.standard.set(preferredSport.rawValue, forKey: "preferredSport") }
    }

    @Published var weeklyGoalDays: Int {
        didSet { UserDefaults.standard.set(weeklyGoalDays, forKey: "weeklyGoalDays") }
    }

    private init() {
        let sportRaw = UserDefaults.standard.string(forKey: "preferredSport") ?? PreferredSport.chinese8.rawValue
        self.preferredSport = PreferredSport(rawValue: sportRaw) ?? .chinese8
        let days = UserDefaults.standard.integer(forKey: "weeklyGoalDays")
        self.weeklyGoalDays = days > 0 ? days : 3
    }

    var sportSummary: String { preferredSport.displayName }
    var goalSummary: String { "每周 \(weeklyGoalDays) 天" }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    sportSection
                    goalSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("偏好设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Sport Section

    private var sportSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("主打球种")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            BTTogglePillGroup(
                options: PreferredSport.allCases,
                selected: $prefs.preferredSport
            ) { $0.displayName }
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("每周训练目标")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(1...7, id: \.self) { days in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            prefs.weeklyGoalDays = days
                        }
                    } label: {
                        HStack {
                            Text("\(days) 天")
                                .font(.btBody)
                                .foregroundStyle(.btText)

                            Spacer()

                            if prefs.weeklyGoalDays == days {
                                Image(systemName: "checkmark")
                                    .font(.btSubheadlineMedium)
                                    .foregroundStyle(.btPrimary)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if days < 7 {
                        Divider().padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
    }
}

#Preview("Settings Dark") {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}
