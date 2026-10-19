#if DEBUG
import SwiftUI

/// Foreground only. The parent owns the paper background and the single renderer.
struct IntroLabEditorialComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String

    private var split: Bool { wide && size.width >= 780 && !accessibility }
    private var inset: CGFloat { split ? 32 : 24 }
    private var scene: CGRect {
        Self.sceneRect(size: size, wide: wide, accessibility: accessibility,
                       titleSize: titleSize, bodySize: bodySize)
    }

    static func sceneRect(size: CGSize, wide: Bool, accessibility: Bool,
                          titleSize: CGFloat, bodySize: CGFloat) -> CGRect {
        let split = wide && size.width >= 780 && !accessibility
        if split {
            let x = size.width * 0.44
            return CGRect(x: x, y: 28, width: max(1, size.width - x - 32),
                          height: max(1, size.height - 56))
        }
        // At accessibility sizes the outer scroll container supplies extra height.
        let header = accessibility ? titleSize * 5.2 + 66 : titleSize * 3.1 + 44
        let footer = bodySize * (accessibility ? 5.2 : 3.4) + 34
        return CGRect(x: 0, y: header, width: max(1, size.width - 24),
                      height: max(1, size.height - header - footer))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if split {
                VStack(alignment: .leading, spacing: 24) {
                    chapter
                    title
                    Rectangle().fill(Color("introLabInk").opacity(0.25)).frame(height: 1)
                    explanation
                    Spacer(minLength: 0)
                }
                .padding(.top, 28)
                .frame(width: size.width * 0.44 - 64, height: size.height - 28, alignment: .topLeading)
                .offset(x: inset)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if accessibility {
                        chapter
                        title
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            Text("01")
                                .font(.system(size: titleSize * 1.8, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color("introLabEditorialGreen"))
                                .accessibilityHidden(true)
                            title
                        }
                    }
                }
                .frame(width: size.width - inset * 2, alignment: .leading)
                .offset(x: inset, y: 12)
                explanation
                    .frame(width: size.width - inset * 2, alignment: .leading)
                    .offset(x: inset, y: scene.maxY + 18)
            }
        }
        .foregroundStyle(Color("introLabInk"))
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var chapter: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("01").font(.system(size: titleSize * 1.8, weight: .bold)).monospacedDigit()
            Text("瞄准").font(.system(size: bodySize, weight: .medium))
        }
        .foregroundStyle(Color("introLabEditorialGreen"))
        .accessibilityLabel("第一章，瞄准")
    }

    private var title: some View {
        Text("进球，\n从看准开始。")
            .font(.system(size: titleSize, weight: .bold))
            .lineSpacing(titleSize * 0.08)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("introLab.title")
            .accessibilityAddTraits(.isHeader)
    }

    private var explanation: some View {
        Text("看清进球线与瞄准点，\n把角度判断练得更有把握。")
            .accessibilityIdentifier("introLab.explanation")
            .font(.system(size: bodySize))
            .lineSpacing(bodySize * 0.25)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color("introLabInk").opacity(0.78))
    }
}
#endif
