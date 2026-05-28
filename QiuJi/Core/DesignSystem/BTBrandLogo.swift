import SwiftUI

/// 品牌 Logo Mark（snail-QJ，类 Q 形扁平矢量）。
///
/// 来源：`18.qiuji_icon_design` spec 02 / selected-logo（`brand.logo-mark.snail-qj-c12`）。
/// 资产 `BrandLogoMark`（Light `#1A6B3C` / Dark `#25A25A`，透明底，保留矢量）。
///
/// 与 App Icon 的关系：App Icon 是 3D 写实球员（Home Screen / App Store）；
/// 本 Logo Mark 是 App 内扁平标识（Onboarding / Login / About / ShareCard）。二者视觉同源、形式不同。
struct BTBrandLogo: View {
    enum Style {
        /// 仅图形，透明背景。用于角标、最小尺寸。
        case markOnly
        /// 图形嵌入 22.37% squircle 圆角方块底。用于 hero 大尺寸。
        case onTile
        /// 图形嵌入圆形底。用于头像类场景。
        case onDisc
    }

    var size: CGFloat = 80
    var style: Style = .onTile

    private var mark: some View {
        Image("BrandLogoMark")
            .resizable()
            .scaledToFit()
    }

    var body: some View {
        Group {
            switch style {
            case .markOnly:
                mark
            case .onTile:
                tile(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            case .onDisc:
                tile(Circle())
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("球迹")
    }

    private func tile<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color.btBGTertiary)
            .overlay {
                mark.padding(size * 0.16)
            }
    }
}

#Preview("Brand Logo") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            BTBrandLogo(size: 96, style: .markOnly)
            BTBrandLogo(size: 96, style: .onTile)
            BTBrandLogo(size: 96, style: .onDisc)
        }
        HStack(spacing: 16) {
            BTBrandLogo(size: 24, style: .onTile)
            BTBrandLogo(size: 40, style: .onTile)
            BTBrandLogo(size: 64, style: .onTile)
        }
    }
    .padding()
    .background(.btBG)
}
