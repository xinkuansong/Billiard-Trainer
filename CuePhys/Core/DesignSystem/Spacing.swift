import CoreGraphics

enum Spacing {
    static let xs:    CGFloat = 4
    static let sm:    CGFloat = 8
    static let md:    CGFloat = 12
    static let lg:    CGFloat = 16
    static let xl:    CGFloat = 20
    static let xxl:   CGFloat = 24
    static let xxxl:  CGFloat = 32
    static let xxxxl: CGFloat = 48
}

enum BTRadius {
    /// Micro chip / PRO 角标等细圆角（F-CL-08：原字面量 4，新增以保渲染不变）。
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let full: CGFloat = 999
}
