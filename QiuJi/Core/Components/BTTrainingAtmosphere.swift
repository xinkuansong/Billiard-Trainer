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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var keepsWeeklySubjectScale = false

    // The 1774×887 photograph contains a 262px-wide ball. Keep its visible
    // diameter near the phone composition (64pt maximum on wide weekly cards).
    private static let weeklyPhotoWidth: CGFloat = 64 * 1774 / 262

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = TrainingDaypart.displayed(at: context.date)
            GeometryReader { geometry in
                photograph(part.assetName, size: geometry.size)
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

    @ViewBuilder
    private func photograph(_ asset: String, size: CGSize) -> some View {
        let photoWidth = max(Self.weeklyPhotoWidth, size.height * 2)
        if keepsWeeklySubjectScale, horizontalSizeClass == .regular, size.width > photoWidth {
            let extensionWidth = size.width - photoWidth
            let stripWidth = photoWidth / 2
            let stripCount = Int(ceil(extensionWidth / stripWidth))
            // Only the empty left half is reflected. Adjacent strips meet at
            // the same source pixels; the ball, cue and shadow stay one photo.
            ZStack(alignment: .topLeading) {
                ForEach(0..<stripCount, id: \.self) { index in
                    Image(asset)
                        .resizable()
                        .frame(width: photoWidth, height: photoWidth / 2)
                        .frame(width: stripWidth, alignment: .leading)
                        .clipped()
                        .scaleEffect(x: index.isMultiple(of: 2) ? -1 : 1, y: 1)
                        .offset(x: extensionWidth - CGFloat(index + 1) * stripWidth)
                }
                Image(asset)
                    .resizable()
                    .frame(width: photoWidth, height: photoWidth / 2)
                    .offset(x: extensionWidth)
            }
            .frame(width: size.width, height: photoWidth / 2, alignment: .topLeading)
            .frame(height: size.height)
        } else {
            Image(asset)
                .resizable()
                .scaledToFill()
        }
    }
}

struct BTProfileGameBall: View {
    @ObservedObject private var preferences = UserPreferences.shared
    let sport: PreferredSport
    var isPremium = false

    static func assetName(for game: DailyClearanceGame) -> String {
        game == .chineseEightBall ? "profileBall8" : "profileBall9"
    }

    static func assetName(for sport: PreferredSport, fallback: DailyClearanceGame) -> String {
        switch sport {
        case .chinese8: return "profileBall8"
        case .nineBall, .zhuifen: return "profileBall9"
        case .both, .other: return assetName(for: fallback)
        }
    }

    var body: some View {
        let asset = Self.assetName(for: sport, fallback: preferences.dailyClearanceGame)
        // Calibrate the crown/ball contact in a 60pt coordinate space, then
        // enlarge Pro artwork to match the selected mockup's avatar-relative size.
        let sourceBottom: CGFloat = asset == "profileBall8" ? 239 : 241
        let ballSize: CGFloat = isPremium ? 46 : 60
        let ballTop = sourceBottom / 256 * (60 - ballSize)
        let crownWidth: CGFloat = 37.1
        // Match the original crown's lower rim corners to each ball silhouette.
        // Coordinates use the 1320x880 source crop, preserving its aspect ratio.
        let contactRow: CGFloat = asset == "profileBall8" ? 59 : 55
        let crownTop = ballTop + contactRow / 256 * ballSize - 840 / 1320 * crownWidth

        ZStack(alignment: .topLeading) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: ballSize, height: ballSize)
                // The crown wraps the upper cap; hide cap pixels above its
                // solid front face instead of showing them between the points.
                .mask { Rectangle().padding(.top, isPremium ? 7 : 0) }
                .offset(x: (60 - ballSize) / 2, y: ballTop)
            if isPremium {
                BTProfileCrown(width: crownWidth)
                    .offset(x: (60 - crownWidth) / 2, y: crownTop)
            }
        }
        .frame(width: 60, height: 60, alignment: .topLeading)
        // Optical overflow stays inside the account card's 16pt padding.
        // Keep the row's reserved width so long names cannot displace the ball.
        .scaleEffect(isPremium ? 1.28 : 1)
        // Center the naturally taller crown without shrinking either original.
        .offset(y: isPremium ? 2.5 : 0)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(asset == "profileBall8" ? "黑八" : "九球")
        .accessibilityValue(isPremium ? "Pro 已解锁" : "普通用户")
        .accessibilityIdentifier("profile.gameBall")
    }
}

/// One upright, photographic crown shared by the profile and Pro entry points.
struct BTProfileCrown: View {
    static let aspectHeight: CGFloat = 128 / 192
    var width: CGFloat

    var body: some View {
        Image("profileCrown")
            .resizable()
            // Original-photo pixels, prefiltered for icon sizes; avoid sparkling edges.
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width, height: width * Self.aspectHeight)
            .saturation(0.72)
            .brightness(-0.08)
            .accessibilityHidden(true)
    }
}

#Preview("Profile Balls / Light") {
    HStack {
        BTProfileGameBall(sport: .chinese8, isPremium: true)
        BTProfileGameBall(sport: .nineBall, isPremium: true)
    }.padding().background(Color.btBGSecondary)
}
#Preview("Profile Balls / Dark") {
    HStack {
        BTProfileGameBall(sport: .chinese8, isPremium: true)
        BTProfileGameBall(sport: .nineBall, isPremium: true)
    }.padding().background(Color.btBGSecondary).preferredColorScheme(.dark)
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
