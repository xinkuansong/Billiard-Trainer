#if DEBUG
import SwiftUI

/// Foreground only. The parent owns the one persistent SceneKit renderer.
struct IntroLabCinematicComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String

    static func sceneRect(
        size: CGSize, wide: Bool, accessibility: Bool,
        titleSize: CGFloat, bodySize: CGFloat
    ) -> CGRect {
        CGRect(origin: .zero, size: CGSize(width: max(1, size.width), height: max(1, size.height)))
    }

    private var gutter: CGFloat { wide && !accessibility ? 40 : 24 }
    private var copyWidth: CGFloat {
        let available = max(1, size.width - gutter * 2)
        // A wide view keeps the centre/right projection clear; large text uses full width.
        return wide && !accessibility ? min(available, size.width * 0.43) : available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            copy
                .frame(width: copyWidth, alignment: .leading)
                .padding(.horizontal, gutter)
                .padding(.top, wide && !accessibility ? 32 : 20)
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Capsule().fill(Color("introLabGreen")).frame(width: 20, height: 2)
                    .accessibilityHidden(true)
                Text("01 / 瞄准")
                    .font(.system(size: bodySize, weight: .medium))
                    .foregroundStyle(Color("introLabGreen"))
            }
            Text("进球，\n从看准开始。")
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(Color("introLabWhite"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("introLab.title")
                .accessibilityAddTraits(.isHeader)
            Text("看清进球线与瞄准点，\n把角度判断练得更有把握。")
            .accessibilityIdentifier("introLab.explanation")
                .font(.system(size: bodySize))
                .foregroundStyle(Color("introLabMuted"))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // This scrim follows the intrinsic text height, never the scene height.
            // The lower and trailing fades end directly around the copy block.
            LinearGradient(
                stops: [
                    .init(color: Color("introLabBackground").opacity(0.96), location: 0),
                    .init(color: Color("introLabBackground").opacity(0.88), location: 0.72),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: Color("introLabWhite"), location: 0),
                        .init(color: Color("introLabWhite"), location: 0.84),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
            .padding(.leading, -gutter)
            .padding(.trailing, -16)
            .padding(.top, -40)
            .padding(.bottom, -28)
            .accessibilityHidden(true)
        }
    }
}

#Preview("Cinematic foreground · Dark") {
    IntroLabCinematicComposition(size: CGSize(width: 393, height: 620), wide: false,
        accessibility: false, titleSize: 35, bodySize: 15, cutAngle: "—", distance: "—")
        .background(Color("introLabBackground")).preferredColorScheme(.dark)
}
#Preview("Cinematic foreground · Light") {
    IntroLabCinematicComposition(size: CGSize(width: 1024, height: 620), wide: true,
        accessibility: false, titleSize: 35, bodySize: 15, cutAngle: "—", distance: "—")
        .background(Color("introLabBackground")).preferredColorScheme(.light)
}
#endif
