import SwiftUI
import UIKit

/// Bundle still-life. Tab bands keep a color wash; plan / practice / template
/// cards show the photo (v46 D-v46-1) plus an optional neutral scrim for type.
struct BTAtmosphereLayer: View {
    enum Crop: Equatable {
        case list
        case hero
    }

    let imageName: String
    let pair: CoverPalette.Pair
    var crop: Crop = .list
    var showsBottomScrim: Bool = false
    var showsColorWash: Bool = true
    var showsNeutralScrim: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        imageName: String,
        pair: CoverPalette.Pair,
        crop: Crop = .list,
        showsBottomScrim: Bool = false,
        showsColorWash: Bool = true,
        showsNeutralScrim: Bool = false
    ) {
        self.imageName = imageName
        self.pair = pair
        self.crop = crop
        self.showsBottomScrim = showsBottomScrim
        self.showsColorWash = showsColorWash
        self.showsNeutralScrim = showsNeutralScrim
    }

    init(
        image: AtmosphereImage,
        pair: CoverPalette.Pair,
        crop: Crop = .list,
        showsBottomScrim: Bool = false,
        showsColorWash: Bool = true,
        showsNeutralScrim: Bool = false
    ) {
        self.init(
            imageName: image.imageName,
            pair: pair,
            crop: crop,
            showsBottomScrim: showsBottomScrim,
            showsColorWash: showsColorWash,
            showsNeutralScrim: showsNeutralScrim
        )
    }

    init(
        key: AtmosphereKey,
        pair: CoverPalette.Pair,
        crop: Crop = .list,
        showsBottomScrim: Bool = false
    ) {
        self.init(
            imageName: key.imageName,
            pair: pair,
            crop: crop,
            showsBottomScrim: showsBottomScrim,
            showsColorWash: true,
            showsNeutralScrim: false
        )
    }

    init(
        key: AtmosphereKey,
        style: CoverPalette.PlanStyle,
        crop: Crop = .list,
        showsBottomScrim: Bool = false
    ) {
        self.init(
            key: key,
            pair: CoverPalette.Pair(top: style.top, bottom: style.bottom),
            crop: crop,
            showsBottomScrim: showsBottomScrim
        )
    }

    var body: some View {
        ZStack {
            if let photo = UIImage(named: imageName) {
                photoLayer(photo)
                if showsColorWash {
                    colorWash
                }
                if showsNeutralScrim {
                    Color.black.opacity(neutralScrimOpacity)
                }
            } else {
                fallbackGradient
            }

            if showsBottomScrim {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [pair.top, pair.bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colorWash: some View {
        LinearGradient(
            colors: [pair.top, pair.bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(0.58)
    }

    /// v56 W6: the installed photography deliberately keeps several studio-white
    /// and charcoal families. A single 12% veil made the bright assets flare and
    /// crushed the darkest ones, so normalization is limited to neutral exposure
    /// buckets. No hue wash and no source image replacement is performed.
    private var neutralScrimOpacity: Double {
        let base = BTAtmosphereToneProfile.scrimOpacity(for: imageName)
        return min(base + (colorScheme == .dark ? 0.02 : 0), 0.30)
    }

    private func photoLayer(_ image: UIImage) -> some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: cropAlignment
                )
                .clipped()
        }
    }

    private var cropAlignment: Alignment {
        switch crop {
        case .list: return .center
        case .hero: return .top
        }
    }
}

enum BTAtmosphereToneProfile {
    private static let highKey: Set<String> = [
        "coverPlanBeginner",
        "coverPracticeQuickRef",
        "coverTemplate01",
        "coverTemplate06",
    ]

    private static let bright: Set<String> = [
        "coverPracticeBallExtraction",
        "coverPracticeComposer",
        "coverPracticeFreePlay",
        "coverPracticeShotSim",
        "coverPracticeSolver",
        "coverPracticeSpinAndEnglish",
        "coverPracticeT06",
    ]

    private static let dark: Set<String> = [
        "coverPlanCueball",
        "coverPlanFullskill",
        "coverPlanSeparation",
        "coverPracticeAngleDynamic",
        "coverPracticeGeometricQuiz",
        "coverPracticePlanThree",
        "coverTemplate03",
        "coverTemplate04",
        "coverTemplate07",
        "coverTemplate09",
        "coverTemplate11",
    ]

    static func scrimOpacity(for imageName: String) -> Double {
        if highKey.contains(imageName) { return 0.24 }
        if bright.contains(imageName) { return 0.16 }
        if dark.contains(imageName) { return 0.08 }
        return 0.12
    }
}
