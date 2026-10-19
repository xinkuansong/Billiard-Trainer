import SwiftUI

struct IntroBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("IntroBackgroundDark").resizable()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct IntroHeader: View {
    var skipTitle = "跳过"
    var skipID = "intro.skip"
    var skip: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Text("CuePhys：台球训练").font(.btHeadline).foregroundStyle(.btPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(skipTitle, action: skip).font(.btFootnote14)
                .foregroundStyle(.btTextSecondary).frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier(skipID)
        }.padding(.horizontal, 28).padding(.top, 8)
    }
}

struct IntroProgress: View {
    let count: Int
    let selection: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule().fill(index == selection ? Color.btPrimary : Color.btSeparator)
                    .frame(width: index == selection ? 26 : 14, height: 3)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("第 \(selection + 1) 页，共 \(count) 页")
    }
}

struct IntroPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.btBodyMedium).foregroundStyle(Color.btBG)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.btPrimary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle()).opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct IntroWelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("BrandLogoMark").resizable().scaledToFit().frame(width: 128, height: 128)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.md) {
                Text("CuePhys：台球训练").font(.btChapterNumber).foregroundStyle(.btPrimary)
                    .multilineTextAlignment(.center)
                Text("让每一杆，都更有把握。").font(.btBody).foregroundStyle(.btText).opacity(0.9)
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IntroBackground()).preferredColorScheme(.dark)
        .accessibilityIdentifier("intro.welcome")
    }
}

/// Only the illustrations use the reference coordinate system. Text/buttons reflow natively.
struct IntroArtwork: View {
    let page: Int
    private static let heights: [CGFloat] = [344.9376, 441.0893, 412, 308.7152, 426.1588, 421.1]
    static func aspectRatio(_ page: Int) -> CGFloat { 370 / heights[page] }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 370
            ZStack(alignment: .topLeading) {
                illustration
            }
            .frame(width: 370, height: Self.heights[page], alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(Self.aspectRatio(page), contentMode: .fit)
        // Cropped images retain source bounds; the accessible shape follows the fitted viewport.
        .contentShape(.accessibility, Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["30度瞄准线、进球线与假想球", "不同高低杆的分离路线", "右塞、中杆略高的击球点", "母球连续走位路线", "同一球形的2D与3D视角，完整球库与袋口", "训练计划、详细安排和训练记录示例"][page])
        .accessibilityIdentifier("onboarding.image.\(page)")
    }

    @ViewBuilder private var illustration: some View {
        switch page {
        case 0: crop("IntroAim", width: 370, height: 344.9376, imageWidth: 370, imageHeight: 400.9982, y: -56.0606)
        case 1: crop("IntroSeparation", width: 370, height: 441.0893, imageWidth: 370, imageHeight: 441.0893)
        case 2:
            Image("IntroSpin").resizable().scaledToFill().frame(width: 370, height: 412).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
            Image("IntroSpinPad").resizable().frame(width: 54, height: 54).offset(x: 232, y: 231)
        case 3:
            crop("IntroPosition", width: 370, height: 308.7152, imageWidth: 370, imageHeight: 337.3529, y: -28.6378)
            Image("IntroSpinPad").resizable().frame(width: 54, height: 54).offset(x: 284, y: 173.3576)
        case 4:
            crop("IntroClearance3D", width: 370, height: 231.3588, imageWidth: 370, imageHeight: 252.0353, y: -20.6762).offset(y: 194.8)
            crop("IntroClearance2D", width: 370, height: 219.5333, imageWidth: 370, imageHeight: 219.5333)
        default:
            // New user-supplied dark captures. Crop only the outside black margins.
            crop("IntroPlan", width: 346, height: 177.3, imageWidth: 375.9, imageHeight: 188.5738, x: -15, y: -9.4).offset(x: 2, y: -32)
            crop("IntroSchedule", width: 338, height: 159.8, imageWidth: 411.7, imageHeight: 167.3, x: -28.7, y: -7.5).offset(x: 30, y: 139)
            crop("IntroRecord", width: 346, height: 124, imageWidth: 375.9, imageHeight: 126, x: -15, y: -2).offset(x: 2, y: 297.1)
        }
    }

    private func crop(_ name: String, width: CGFloat, height: CGFloat, imageWidth: CGFloat,
                      imageHeight: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        Color.clear.frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                Image(name).resizable().frame(width: imageWidth, height: imageHeight).offset(x: x, y: y)
            }.clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { IntroWelcomeView() }

/// Button and swipe navigation share the same page state and retain each page's scroll position.
struct IntroPager<Content: View>: View {
    @GestureState private var dragActive = false
    let selection: Int
    let count: Int
    let onSwipeForward: () -> Void
    let onSwipeBack: () -> Void
    var onDragActivity: (Bool) -> Void = { _ in }
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        GeometryReader { viewport in
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { page in
                    content(page)
                        .frame(width: viewport.size.width, height: viewport.size.height)
                        .allowsHitTesting(page == selection)
                        .accessibilityHidden(page != selection)
                }
            }
            .offset(x: -CGFloat(selection) * viewport.size.width)
        }
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .updating($dragActive) { _, active, _ in active = true }
                .onChanged { _ in onDragActivity(true) }
                .onEnded { value in
                    // A simultaneous drag can also end a child Button press. Keep
                    // selection suppressed until this touch event has been delivered.
                    DispatchQueue.main.async { onDragActivity(false) }
                    // Require a deliberate horizontal swipe. Vertical scrolling and the
                    // birthday wheels continue to receive their native gestures.
                    let movement = value.translation
                    guard abs(movement.width) >= 60,
                          abs(movement.width) > abs(movement.height) * 1.5 else { return }
                    if movement.width < 0 { onSwipeForward() }
                    else { onSwipeBack() }
                }
        )
        .onChange(of: dragActive) { _, active in
            // GestureState also resets when the system cancels a gesture.
            if !active { DispatchQueue.main.async { onDragActivity(false) } }
        }
    }
}

struct IntroBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("返回", systemImage: "chevron.left")
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
    }
}
