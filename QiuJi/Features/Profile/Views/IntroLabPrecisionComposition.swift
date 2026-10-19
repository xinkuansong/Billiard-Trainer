#if DEBUG
import SwiftUI

/// A measured training view: the only readings are supplied by the live fixture.
struct IntroLabPrecisionComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String

    private static func headingHeight(size: CGSize, titleSize: CGFloat, bodySize: CGFloat) -> CGFloat {
        let available = max(1, size.width - 48)
        let lines = ceil(3 * titleSize / available) + ceil(7 * titleSize / available)
        return 24 + lines * titleSize * 1.3 + 24
    }

    private static func footerHeight(size: CGSize, bodySize: CGFloat) -> CGFloat {
        let available = max(1, size.width - 48)
        let lines = ceil(11 * bodySize / available) + ceil(13 * bodySize / available)
        return 24 + bodySize * 4.5 + 20 + lines * bodySize * 1.5 + 24
    }

    static func sceneRect(size: CGSize, wide: Bool, accessibility: Bool, titleSize: CGFloat, bodySize: CGFloat) -> CGRect {
        if size.width >= 780 && !accessibility {
            let left = max(320, size.width * 0.40)
            return CGRect(x: left, y: 24, width: max(1, size.width - left), height: max(1, size.height - 48))
        }
        let top = headingHeight(size: size, titleSize: titleSize, bodySize: bodySize)
        let bottom = footerHeight(size: size, bodySize: bodySize)
        return CGRect(x: 16, y: top, width: max(1, size.width - 32), height: max(1, size.height - top - bottom))
    }

    var body: some View {
        let split = size.width >= 780 && !accessibility
        let rect = Self.sceneRect(size: size, wide: wide, accessibility: accessibility, titleSize: titleSize, bodySize: bodySize)
        ZStack(alignment: .topLeading) {
            if split {
                VStack(alignment: .leading, spacing: 24) {
                    chapter
                    heading
                    explanation
                    Spacer(minLength: 24)
                    readings
                }
                .padding(.horizontal, 32).padding(.vertical, 40)
                .frame(width: rect.minX, height: size.height, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    heading
                }
                .padding(.horizontal, 24).padding(.top, 24)
                .frame(width: size.width, alignment: .leading)
                VStack(alignment: .leading, spacing: 20) {
                    readings
                    explanation
                }
                .padding(.horizontal, 24).padding(.top, 24)
                .frame(width: size.width, alignment: .leading)
                .offset(y: rect.maxY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var chapter: some View {
        Text("01 / 瞄准")
            .font(.system(size: bodySize, weight: .medium, design: .monospaced))
            .foregroundStyle(Color("introLabSignal"))
    }

    private var heading: some View {
        Text("进球，\n从看准开始。")
            .font(.system(size: titleSize, weight: .bold))
            .lineSpacing(titleSize * 0.12)
            .foregroundStyle(Color("introLabWhite"))
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

    private var readings: some View {
        HStack(alignment: .top, spacing: 24) {
            reading("切角", value: cutAngle)
            reading("球距", value: distance)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color("introLabSignal").opacity(0.45)).frame(height: 1)
        }
    }

    private func reading(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: bodySize)).foregroundStyle(Color("introLabMuted"))
            Text(value).font(.system(size: bodySize * 1.35, weight: .medium, design: .monospaced))
                .monospacedDigit().foregroundStyle(Color("introLabWhite"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
