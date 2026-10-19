#if DEBUG
import SwiftUI

/// Quiet typography above an unframed, edge-to-edge native scene.
struct IntroLabMinimalComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String

    private static func headerHeight(size: CGSize, accessibility: Bool, titleSize: CGFloat, bodySize: CGFloat) -> CGFloat {
        if size.width >= 780 && !accessibility {
            return max(titleSize * 2.65, bodySize * 3.2) + 64
        }
        // Reserve extra lines when glyph growth makes the explicit second line wrap.
        let available = max(1, size.width - 48)
        let titleLines = ceil(3 * titleSize / available) + ceil(7 * titleSize / available)
        let bodyLines = ceil(11 * bodySize / available) + ceil(13 * bodySize / available)
        return 32 + titleLines * titleSize * 1.3 + 20 + bodyLines * bodySize * 1.5 + 32
    }

    static func sceneRect(size: CGSize, wide: Bool, accessibility: Bool, titleSize: CGFloat, bodySize: CGFloat) -> CGRect {
        let top = headerHeight(size: size, accessibility: accessibility, titleSize: titleSize, bodySize: bodySize)
        return CGRect(x: 0, y: top, width: max(1, size.width), height: max(1, size.height - top))
    }

    var body: some View {
        let split = size.width >= 780 && !accessibility
        let header = Self.headerHeight(size: size, accessibility: accessibility, titleSize: titleSize, bodySize: bodySize)
        Group {
            if split {
                HStack(alignment: .center, spacing: 40) {
                    heading.multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    explanation.multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 48)
                .frame(width: size.width, height: header)
            } else {
                VStack(spacing: 20) {
                    heading
                    explanation
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .frame(width: size.width, height: header, alignment: .top)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var heading: some View {
        Text("进球，\n从看准开始。")
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundStyle(Color("introLabWhite"))
            .lineSpacing(titleSize * 0.12)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("introLab.title")
    }

    private var explanation: some View {
        Text("看清进球线与瞄准点，\n把角度判断练得更有把握。")
            .accessibilityIdentifier("introLab.explanation")
            .font(.system(size: bodySize))
            .lineSpacing(bodySize * 0.3)
            .foregroundStyle(Color("introLabMuted"))
            .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
