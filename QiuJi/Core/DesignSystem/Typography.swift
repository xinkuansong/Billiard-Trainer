import SwiftUI

/// 全局字体 Token。
///
/// 设计取向：克制 + 数据为主角。
/// 基线参考：角度训练首页（34 → 17 → 13 的紧凑层级），其它页面向其靠拢。
///
/// 字号原则：
/// - 根 Tab 页面标题使用 `btLargeTitle`；卡片标题使用 `btHeadline` / `btTitleMedium`。
/// - 列表行主标题优先 `btHeadline` 或 `btBodyMedium`，避免 `btTitle2` 滥用。
/// - 展示级（`btDisplay` / `btDisplaySmall` / `btChapterNumber`）仅在「单屏核心数据」或「编辑式排版」中出现。
/// - 副标题用 `btSubheadline` / `btFootnote14`，避免 `btCaption` 当正文使用。
extension Font {
    // MARK: - 展示级（单屏核心数据 / 编辑式排版）
    static let btDisplay             = Font.system(size: 44, weight: .bold, design: .rounded)
    static let btDisplaySmall        = Font.system(size: 30, weight: .bold, design: .rounded)
    static let btLargeTitle          = Font.system(size: 32, weight: .bold, design: .rounded)
    /// Practice-home cover glyph watermark (v7 C20 / v27 W2 DR-044 / DR-056).
    /// Size = `CoverPalette.Glyph.gridAbsoluteSize` (37); weight black; rounded.
    static let btCoverWatermark = Font.system(
        size: CoverPalette.Glyph.gridAbsoluteSize,
        weight: .black,
        design: .rounded
    )

    /// Scalable cover watermark — same weight/design as `btCoverWatermark` (plan posters / hero).
    static func btCoverWatermark(size: CGFloat) -> Font {
        Font.system(size: size, weight: .black, design: .rounded)
    }
    /// Hero SF Symbol without forcing bold (v7 C21 — `BTDailyLimitGate` crown). Source: `size: 32`.
    static let btHeroSymbol          = Font.system(size: 32)
    static let btChapterNumber       = Font.system(size: 26, weight: .bold, design: .rounded)

    // MARK: - 标题级
    static let btTitle               = Font.system(size: 20, weight: .bold, design: .rounded)
    static let btTitle2              = Font.system(size: 18, weight: .semibold)
    static let btTitleMedium         = Font.system(size: 17, weight: .semibold)
    static let btHeadline            = Font.system(size: 17, weight: .semibold)

    // MARK: - 正文级
    static let btBody                = Font.system(size: 17, weight: .regular)
    static let btBodyMedium          = Font.system(size: 17, weight: .medium)
    static let btCallout             = Font.system(size: 16, weight: .regular)

    // MARK: - 数据展示级（卡片内小型数字）
    static let btStatNumber          = Font.system(size: 24, weight: .bold, design: .rounded)

    // MARK: - 辅助级
    static let btSubheadline         = Font.system(size: 15, weight: .regular)
    static let btSubheadlineMedium   = Font.system(size: 15, weight: .medium)
    static let btSubheadlineSemibold = Font.system(size: 15, weight: .semibold)
    /// Rounded CTA label (v7 C21 — `BTDailyLimitGate` unlock button). Source: `size: 15, weight: .semibold, design: .rounded`.
    static let btCTALabelRounded     = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let btFootnote14          = Font.system(size: 14, weight: .regular)
    static let btFootnote            = Font.system(size: 13, weight: .regular)
    static let btCaption             = Font.system(size: 12, weight: .regular)
    static let btCaption2            = Font.system(size: 11, weight: .medium)
    static let btMicro               = Font.system(size: 10, weight: .medium)
}
