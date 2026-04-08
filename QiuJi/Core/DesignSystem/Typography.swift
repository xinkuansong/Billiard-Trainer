import SwiftUI

extension Font {
    // MARK: - 展示级（数据主角）
    static let btDisplay             = Font.system(size: 48, weight: .bold, design: .rounded)
    static let btLargeTitle          = Font.system(size: 34, weight: .bold, design: .rounded)

    // MARK: - 标题级
    static let btTitle               = Font.system(size: 22, weight: .bold, design: .rounded)
    static let btTitle2              = Font.system(size: 20, weight: .semibold)
    static let btHeadline            = Font.system(size: 17, weight: .semibold)

    // MARK: - 正文级
    static let btBody                = Font.system(size: 17, weight: .regular)
    static let btBodyMedium          = Font.system(size: 17, weight: .medium)
    static let btCallout             = Font.system(size: 16, weight: .regular)

    // MARK: - 数据展示级
    static let btStatNumber          = Font.system(size: 28, weight: .bold, design: .rounded)

    // MARK: - 辅助级
    static let btSubheadline         = Font.system(size: 15, weight: .regular)
    static let btSubheadlineMedium   = Font.system(size: 15, weight: .medium)
    static let btSubheadlineSemibold = Font.system(size: 15, weight: .semibold)
    static let btFootnote14          = Font.system(size: 14, weight: .regular)
    static let btFootnote            = Font.system(size: 13, weight: .regular)
    static let btCaption             = Font.system(size: 12, weight: .regular)
    static let btCaption2            = Font.system(size: 11, weight: .medium)
    static let btMicro               = Font.system(size: 10, weight: .medium)
}
