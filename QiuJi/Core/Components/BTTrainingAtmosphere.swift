import SwiftUI

enum TrainingDaypart: String, CaseIterable {
    case morning, day, evening

    static func resolve(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Self {
        switch calendar.component(.hour, from: date) {
        case 6..<11: return .morning
        case 11..<18: return .day
        default: return .evening
        }
    }

    // Keep the approved felt and spherical silhouette consistent at every time of day.
    var assetName: String { "trainingWeekly" }

    var shadeOpacity: Double {
        switch self {
        case .morning: return 0
        case .day: return 0.03
        case .evening: return 0.08
        }
    }

    static func displayed(at date: Date) -> Self {
        #if DEBUG
        // Read-only preview override; never changes the user's clock or preferences.
        if let value = ProcessInfo.processInfo.environment["QIUJI_DAYPART"],
           let part = Self(rawValue: value) { return part }
        #endif
        return resolve(at: date)
    }
}

enum TrainingPhotoStyle {
    static let foreground = Color("btTrainingIvory")
    static let completed = foreground
    static let ink = Color("btTrainingInk")
}

/// Only the photographic layer updates each minute, leaving native controls intact.
struct BTTrainingAtmosphere: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = TrainingDaypart.displayed(at: context.date)
            GeometryReader { geometry in
                Image(part.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(TrainingPhotoStyle.ink.opacity(part.shadeOpacity))
                    .id(part)
                    .transition(.opacity)
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: TrainingPhotoStyle.ink.opacity(0.22), location: 0),
                            .init(color: TrainingPhotoStyle.ink.opacity(0.10), location: 0.53),
                            .init(color: .clear, location: 0.75)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
                    .overlay {
                        LinearGradient(colors: [.clear, TrainingPhotoStyle.ink.opacity(0.22)],
                                       startPoint: .center, endPoint: .bottom)
                    }
                    .animation(reduceMotion || scenePhase != .active ? nil : .easeInOut(duration: 0.6), value: part)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BTProfileGameBall: View {
    @ObservedObject private var preferences = UserPreferences.shared

    static func assetName(for game: DailyClearanceGame) -> String {
        game == .chineseEightBall ? "profileBall8" : "profileBall9"
    }

    var body: some View {
        Image(Self.assetName(for: preferences.dailyClearanceGame))
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("Photo / Light") { BTTrainingAtmosphere().frame(height: 220) }
#Preview("Photo / Dark") { BTTrainingAtmosphere().frame(height: 220).preferredColorScheme(.dark) }

/// One coherent photo supplies both ball and felt, without altering layout.
struct BTProfileHeaderBackdrop: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        GeometryReader { geometry in
            Image(preferences.dailyClearanceGame == .chineseEightBall ? "profilePhoto8" : "profilePhoto9")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay {
                    LinearGradient(stops: [
                        .init(color: TrainingPhotoStyle.ink.opacity(0.68), location: 0),
                        .init(color: TrainingPhotoStyle.ink.opacity(0.42), location: 0.52),
                        .init(color: .clear, location: 0.74)
                    ], startPoint: .leading, endPoint: .trailing)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
