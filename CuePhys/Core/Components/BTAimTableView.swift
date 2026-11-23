import SwiftUI

/// 拟真 2D 台面插图组件：在纯 SwiftUI 下还原与 SceneKit 台面一致的观感
/// （木纹库边 + 皮革袋口 + 颗星 + 台呢光影渐变），用于角度训练的学习文档插图
/// 与几何角度训练页。轻量、可放进可滚动页面，并向调用方暴露「台呢有效区」矩形，
/// 便于在上面叠加瞄准线、角度弧、标签与 `BTRealisticBall`。
struct BTAimTableView<Overlay: View>: View {

    enum Style {
        /// 完整球桌：木纹库边 + 皮革袋口 + 颗星。
        case fullTable
        /// 仅台呢（含光影渐变），用于小卡片插图。
        case feltOnly
    }

    var style: Style = .fullTable
    var showsDiamonds: Bool = true
    var showsCenterLine: Bool = false
    /// 接收台呢有效区（本地坐标系下的 CGRect），调用方据此摆放球与线。
    @ViewBuilder var overlay: (CGRect) -> Overlay

    init(style: Style = .fullTable,
         showsDiamonds: Bool = true,
         showsCenterLine: Bool = false,
         @ViewBuilder overlay: @escaping (CGRect) -> Overlay = { _ in EmptyView() }) {
        self.style = style
        self.showsDiamonds = showsDiamonds
        self.showsCenterLine = showsCenterLine
        self.overlay = overlay
    }

    // MARK: - Palette

    private let woodLight = Color(hex: 0x6B4A2F)
    private let woodDark = Color(hex: 0x32200F)
    private let feltDark = Color(hex: 0x14512C)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let railWidth = style == .fullTable
                ? min(size.width, size.height) * 0.07
                : 0
            let feltRect = CGRect(
                x: railWidth, y: railWidth,
                width: max(0, size.width - railWidth * 2),
                height: max(0, size.height - railWidth * 2)
            )
            let feltCorner = max(2, railWidth * 0.35)

            ZStack {
                if style == .fullTable {
                    woodRail(size: size)
                }

                feltSurface(rect: feltRect, corner: feltCorner)

                if showsCenterLine {
                    centerLine(in: feltRect)
                }

                if style == .fullTable {
                    if showsDiamonds {
                        diamonds(size: size, railWidth: railWidth, feltRect: feltRect)
                    }
                    pockets(feltRect: feltRect, railWidth: railWidth)
                }

                overlay(feltRect)
            }
        }
    }

    // MARK: - Wood rail

    private func woodRail(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.05, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [woodLight, woodDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            // 木纹细条（横向微弱明暗）
            RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.05, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear, .black.opacity(0.10), .clear, .white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            // 内缘暗角
            RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.05, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: - Felt

    private func feltSurface(rect: CGRect, corner: CGFloat) -> some View {
        // feltOnly 走干净克制路线（教学插图，避免抢焦点）：近平的台呢 + 极淡边缘压暗；
        // fullTable 才用更强的中心打光层次。
        let clean = style == .feltOnly
        return ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.btTableFelt)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: clean
                            ? [.white.opacity(0.05), .clear, feltDark.opacity(0.22)]
                            : [.white.opacity(0.10), .clear, feltDark.opacity(0.55)],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(rect.width, rect.height) * (clean ? 0.72 : 0.62)
                    )
                )
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.black.opacity(clean ? 0.12 : 0.28), lineWidth: 1)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func centerLine(in rect: CGRect) -> some View {
        Path { p in
            if rect.width >= rect.height {
                p.move(to: CGPoint(x: rect.midX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            } else {
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    }

    // MARK: - Diamonds (sights)

    private func diamonds(size: CGSize, railWidth: CGFloat, feltRect: CGRect) -> some View {
        let dotR = railWidth * 0.16
        let midRail = railWidth / 2
        let longHorizontal = feltRect.width >= feltRect.height
        // 长库放 1/4、3/4（中点留给中袋），短库放 1/3、2/3。
        let longFracs: [CGFloat] = [0.25, 0.75]
        let shortFracs: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]
        let topBottomFracs = longHorizontal ? longFracs : shortFracs
        let leftRightFracs = longHorizontal ? shortFracs : longFracs

        return ZStack {
            ForEach(Array(topBottomFracs.enumerated()), id: \.offset) { _, f in
                dot(r: dotR).position(x: feltRect.minX + feltRect.width * f, y: midRail)
                dot(r: dotR).position(x: feltRect.minX + feltRect.width * f, y: size.height - midRail)
            }
            ForEach(Array(leftRightFracs.enumerated()), id: \.offset) { _, f in
                dot(r: dotR).position(x: midRail, y: feltRect.minY + feltRect.height * f)
                dot(r: dotR).position(x: size.width - midRail, y: feltRect.minY + feltRect.height * f)
            }
        }
    }

    private func dot(r: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: 0xF2ECDC))
            .frame(width: r * 2, height: r * 2)
            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Pockets

    private func pockets(feltRect: CGRect, railWidth: CGFloat) -> some View {
        let cornerR = railWidth * 0.62
        let sideR = railWidth * 0.55
        let longHorizontal = feltRect.width >= feltRect.height

        var centers: [(CGPoint, CGFloat)] = [
            (CGPoint(x: feltRect.minX, y: feltRect.minY), cornerR),
            (CGPoint(x: feltRect.maxX, y: feltRect.minY), cornerR),
            (CGPoint(x: feltRect.minX, y: feltRect.maxY), cornerR),
            (CGPoint(x: feltRect.maxX, y: feltRect.maxY), cornerR),
        ]
        if longHorizontal {
            centers.append((CGPoint(x: feltRect.midX, y: feltRect.minY), sideR))
            centers.append((CGPoint(x: feltRect.midX, y: feltRect.maxY), sideR))
        } else {
            centers.append((CGPoint(x: feltRect.minX, y: feltRect.midY), sideR))
            centers.append((CGPoint(x: feltRect.maxX, y: feltRect.midY), sideR))
        }

        return ZStack {
            ForEach(Array(centers.enumerated()), id: \.offset) { _, item in
                pocket(r: item.1).position(item.0)
            }
        }
    }

    private func pocket(r: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black, Color(hex: 0x1A1A1A)],
                        center: .center, startRadius: 0, endRadius: r
                    )
                )
            Circle()
                .strokeBorder(Color(hex: 0x4A3320), lineWidth: max(1, r * 0.16))
        }
        .frame(width: r * 2, height: r * 2)
    }
}

// MARK: - Pocket marker

/// 干净的袋口标记（用于 feltOnly 教学插图：示意"目标袋口"而不画整圈皮革库角）。
struct BTPocketMark: View {
    var diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [.black, Color(hex: 0x202020)],
                               center: .center, startRadius: 0, endRadius: diameter / 2)
            )
            Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: max(0.5, diameter * 0.05))
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Preview

#Preview("Full table") {
    BTAimTableView(style: .fullTable, showsCenterLine: true) { felt in
        BTRealisticBall(kind: .cue, diameter: felt.width * 0.08)
            .position(x: felt.minX + felt.width * 0.3, y: felt.minY + felt.height * 0.7)
        BTRealisticBall(kind: .target, diameter: felt.width * 0.08)
            .position(x: felt.minX + felt.width * 0.6, y: felt.minY + felt.height * 0.4)
    }
    .aspectRatio(1.7, contentMode: .fit)
    .padding()
    .background(Color.btBG)
}

#Preview("Felt only") {
    BTAimTableView(style: .feltOnly) { felt in
        BTRealisticBall(kind: .target, diameter: felt.height * 0.5, showsContactShadow: false)
            .position(x: felt.midX, y: felt.midY)
    }
    .frame(width: 160, height: 90)
    .padding()
    .background(Color.btBG)
}
