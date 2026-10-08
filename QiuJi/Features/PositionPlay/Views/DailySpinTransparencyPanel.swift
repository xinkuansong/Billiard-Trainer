import SwiftUI

/// Daily HUD only: keep the 252pt reference card while content still fits.
/// Large text gets its own row; short windows scroll the reading area, never the table.
struct DailySpinTransparencyPanel: View {
    @Binding var transparency: Double
    var availableSize: CGSize
    var onClose: () -> Void
    @State private var naturalContentHeight: CGFloat?

    private var width: CGFloat { min(252, max(44, availableSize.width)) }
    private var contentHeight: CGFloat { max(44, availableSize.height - 2 * Spacing.xs) }

    var body: some View {
        Group {
            if let naturalContentHeight, naturalContentHeight > contentHeight {
                VStack(spacing: 0) {
                    HStack { Spacer(); done }
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            title.fixedSize(horizontal: false, vertical: true)
                            percentage.fixedSize(horizontal: false, vertical: true)
                            sliderAndLabels
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("dailyClearance.spinTransparencyScroll")
                }
                .frame(height: contentHeight)
            } else {
                naturalContent
            }
        }
        .background {
            // Measure with unconstrained height and the same available width.
            // A maxHeight frame around ViewThatFits would itself stretch the glass.
            naturalContent
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: DailyTransparencyHeightKey.self,
                                           value: proxy.size.height)
                })
                .hidden()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .onPreferenceChange(DailyTransparencyHeightKey.self) { height in
            if height.isFinite, height > 0, height != naturalContentHeight {
                naturalContentHeight = height
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(width: width)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .modifier(DailyPanelSurface())
        // The entire visible card owns blank-space taps. A gesture on a separate
        // clear background does not establish this boundary for the card itself.
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyClearance.spinTransparencyPanel")
    }

    private var naturalContent: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                referenceHeader
                VStack(spacing: 0) {
                    title.fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: Spacing.xs) {
                        percentage.fixedSize()
                        Spacer(minLength: 0)
                        done
                    }
                }
            }
            sliderAndLabels
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var referenceHeader: some View {
        HStack(spacing: Spacing.xs) {
            // Intrinsic widths let ViewThatFits reject a compressed title.
            title.fixedSize()
            Spacer(minLength: 0)
            percentage.fixedSize()
            done
        }
    }

    private var title: some View {
        Text("打点盘透明度").font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("dailyClearance.spinTransparencyTitle")
    }

    private var percentage: some View {
        Text("\(Int((transparency * 100).rounded()))%")
            .font(.subheadline).monospacedDigit()
            .foregroundStyle(.white)
            .accessibilityIdentifier("dailyClearance.spinTransparencyPercent")
    }

    private var done: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.btBody)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: Circle(), normal: .clear) }
                .contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle())
        .accessibilityLabel("完成透明度设置")
        .accessibilityIdentifier("dailyClearance.spinTransparencyDone")
    }

    private var sliderAndLabels: some View {
        VStack(spacing: 0) {
            Slider(value: $transparency, in: 0...1) { Text("打点盘透明度") }
                .tint(.white)
                .accessibilityValue("\(Int((transparency * 100).rounded()))%")
                .accessibilityIdentifier("dailyClearance.spinTransparencySlider")
            HStack {
                Text("不透明")
                    .accessibilityIdentifier("dailyClearance.spinTransparencyOpaqueLabel")
                Spacer(minLength: 0)
                Text("全透明")
                    .accessibilityIdentifier("dailyClearance.spinTransparencyTransparentLabel")
            }
            .font(.caption)
            .foregroundStyle(.white)
        }
        .frame(minHeight: 56)
    }
}

private struct DailyTransparencyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Daily text panels use material; the aiming disc and instruments keep their
/// independent transparency. Reduce Transparency affects this text surface only.
struct DailyPanelSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: BTRadius.md)
        content.background {
            if reduceTransparency { shape.fill(Color(white: 0.22)) }
            else { shape.fill(.regularMaterial) }
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
        // Include the material in the scene's dark HUD environment. Setting
        // this on the caller's content alone leaves this background in Light.
        .environment(\.colorScheme, .dark)
    }
}
