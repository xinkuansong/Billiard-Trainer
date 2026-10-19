#if DEBUG
import SwiftUI

/// Training idea, unoccluded real scene, then one learning-value card.
struct IntroLabTrainingComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String

    private var split: Bool { wide && size.width >= 780 && !accessibility }
    private var scene: CGRect {
        Self.sceneRect(size: size, wide: wide, accessibility: accessibility,
                       titleSize: titleSize, bodySize: bodySize)
    }

    static func sceneRect(size: CGSize, wide: Bool, accessibility: Bool,
                          titleSize: CGFloat, bodySize: CGFloat) -> CGRect {
        if wide && size.width >= 780 && !accessibility {
            let x = size.width * 0.43
            return CGRect(x: x, y: 24, width: max(1, size.width - x - 24),
                          height: max(1, size.height - 48))
        }
        let top = accessibility ? titleSize * 4.6 + bodySize * 1.4 + 42 : titleSize * 2.5 + bodySize * 1.4 + 40
        let card = bodySize * (accessibility ? 6.6 : 4.6) + 48
        return CGRect(x: 24, y: top, width: max(1, size.width - 48),
                      height: max(1, size.height - top - card - 18))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if split {
                VStack(alignment: .leading, spacing: 24) {
                    headline
                    Spacer(minLength: 24)
                    valueCard
                }
                .frame(width: size.width * 0.43 - 56, height: size.height - 48, alignment: .topLeading)
                .offset(x: 24, y: 24)
            } else {
                headline
                    .frame(width: size.width - 48, alignment: .leading)
                    .offset(x: 24, y: 12)
                valueCard
                    .frame(width: size.width - 48, alignment: .leading)
                    .offset(x: 24, y: scene.maxY + 18)
            }
        }
        .foregroundStyle(Color("introLabWhite"))
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("01 / 瞄准")
                .font(.system(size: bodySize, weight: .medium)).monospacedDigit()
                .foregroundStyle(Color("introLabGreen"))
            Text("进球，\n从看准开始。")
                .font(.system(size: titleSize, weight: .bold))
                .lineSpacing(titleSize * 0.08)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("introLab.title")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("把判断练成把握")
                .font(.system(size: bodySize, weight: .semibold))
                .foregroundStyle(Color("introLabGreen"))
            Text("看清进球线与瞄准点，\n把角度判断练得更有把握。")
            .accessibilityIdentifier("introLab.explanation")
                .font(.system(size: bodySize))
                .lineSpacing(bodySize * 0.25)
                .foregroundStyle(Color("introLabWhite").opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("introLabPanel"), in: RoundedRectangle(cornerRadius: 16))
    }
}
#endif
