import SwiftUI

/// 集中管理项目内 SF Symbol 字符串常量。
///
/// 目的：
/// 1. **避免散落字面量** — 当前项目中 50+ 处散落的 `Image(systemName: "xxx")` 字符串迁移到此处后，
///    重设计时只需改一处。
/// 2. **支持自定义资产** — `bt.*` 前缀预留给未来引入的自定义 SF Symbol 包；
///    当前所有自定义图标走 SwiftUI 视图（`BTLogoMark` / `BTTrainingIcon` / `BTDrillCategoryIcon`）。
/// 3. **语义不当占位检测** — `figure.pool.swim`（游泳）等不应再被引入，本枚举不暴露这些。
///
/// ### 使用约定
///
/// - 增量迁移：新增 View 优先使用 `BTIcon.xxx`；现有 View 在常规重构时再批量替换。
/// - 业务语义优先：相同视觉但不同语义的图标拆开命名（如 `BTIcon.completeSeal` 与 `BTIcon.successCheck`）。
/// - 永远不要把品牌图形（Logo / Tab / Drill 分类）放在这里 — 它们是 SwiftUI 视图，不是字符串。
enum BTIcon {

    // MARK: - Navigation

    static let chevronLeft  = "chevron.left"
    static let chevronRight = "chevron.right"
    static let chevronDown  = "chevron.down"
    static let chevronUp    = "chevron.up"
    static let close        = "xmark"
    static let closeFilled  = "xmark.circle.fill"
    static let arrowRight   = "arrow.right"
    static let arrowLeftRight = "arrow.left.arrow.right"

    // MARK: - Search & Filter

    static let search       = "magnifyingglass"
    static let filter       = "line.3.horizontal.decrease"
    static let menu         = "ellipsis"
    static let menuCircle   = "ellipsis.circle"

    // MARK: - Status

    static let checkmark        = "checkmark"
    static let checkmarkCircle  = "checkmark.circle.fill"
    static let completeSeal     = "checkmark.seal.fill"
    static let successShield    = "checkmark.shield.fill"
    static let warningTriangle  = "exclamationmark.triangle.fill"
    static let info             = "info.circle.fill"

    // MARK: - Editing

    static let plus             = "plus"
    static let plusCircle       = "plus.circle"
    static let plusCircleFilled = "plus.circle.fill"
    static let minus            = "minus"
    static let trash            = "trash"
    static let pencil           = "pencil"
    static let editPad          = "square.and.pencil"
    static let copy             = "doc.on.doc"

    // MARK: - Sharing & External

    static let share        = "square.and.arrow.up"
    static let qrcode       = "qrcode"
    static let envelope     = "envelope.fill"
    static let messageBubble = "message.fill"

    // MARK: - Time & Calendar

    static let timer        = "timer"
    static let clockHistory = "clock.arrow.circlepath"
    static let clockPause   = "clock.badge.xmark"
    static let calendar     = "calendar"
    static let calendarPlus = "calendar.badge.plus"
    static let moonZzz      = "moon.zzz"

    // MARK: - Media Playback

    static let play         = "play.fill"
    static let pause        = "pause.fill"
    static let playCircle   = "play.circle"
    static let pauseCircle  = "pause.circle"
    static let playCircleFilled = "play.circle.fill"
    static let playSlashed  = "play.slash.fill"
    static let stopCircle   = "stop.circle"
    static let forward      = "forward.fill"
    static let replay       = "arrow.counterclockwise"

    // MARK: - User & Profile

    static let person           = "person.fill"
    static let personCircle     = "person.circle"
    static let personGroup      = "person.2"
    static let appleLogo        = "applelogo"
    static let phone            = "phone.fill"
    static let lock             = "lock.fill"
    static let crown            = "crown.fill"
    static let star             = "star.fill"
    static let heart            = "heart"
    static let heartFilled      = "heart.fill"
    static let heartSlashed     = "heart.slash"
    static let trophy           = "trophy.fill"
    static let gear             = "gearshape.fill"

    // MARK: - Charts & Stats

    static let chartBar         = "chart.bar"
    static let chartBarFilled   = "chart.bar.fill"
    static let chartLine        = "chart.line.uptrend.xyaxis"
    static let target           = "target"
    static let scope            = "scope"
    static let angle            = "angle"

    // MARK: - Empty States

    static let tray         = "tray"
    static let emptyDoc     = "doc.text"

    // MARK: - Angle Training

    static let ruler        = "ruler.fill"
    static let grid2x2      = "square.grid.2x2.fill"
    static let rotate3D     = "rotate.3d.fill"
    static let tableCells   = "tablecells.fill"
    static let handDraw     = "hand.draw.fill"
    static let brain        = "brain.head.profile.fill"
    static let lightbulb    = "lightbulb.fill"

    // MARK: - Reserved for Future Custom Symbols
    // 当前所有自定义图标通过 SwiftUI 视图实现（BTLogoMark / BTTrainingIcon /
    // BTDrillCategoryIcon），如未来引入 .symbol 自定义包，命名空间预留 "bt." 前缀。
    // 例如：static let btTraining = "bt.training"
}

// MARK: - BTIconBadge（统一图标徽标）

/// 全 App 统一的"图标入口徽标"：单色图形 + 淡色圆底。
///
/// 取代之前各处散落、色相失控的彩色圆底（Profile 红/蓝/紫/灰、侧栏橙等）。
///
/// ### 颜色纪律（来自 UR-20260601-IconSystem）
/// - `.primary`（默认）：品牌绿单色 + 淡绿圆底 —— 绝大多数列表入口、FeatureCard。
/// - `.accent`：金色 —— **仅用于商业化/强调**（订阅、Pro、成就），全屏最多一处。
/// - `.neutral`：中性灰 —— 次要、停用、占位类入口。
///
/// 视觉范式对齐 `AngleHomeView.FeatureCard`（已验证为全 App 最干净的图标处理）。
struct BTIconBadge: View {
    enum Tint {
        case primary
        case accent
        case neutral

        var foreground: Color {
            switch self {
            case .primary: return .btPrimary
            case .accent:  return .btAccent
            case .neutral: return .btTextSecondary
            }
        }

        func background(_ scheme: ColorScheme) -> Color {
            let opacity = scheme == .dark ? 0.18 : 0.12
            switch self {
            case .primary: return Color.btPrimary.opacity(opacity)
            case .accent:  return Color.btAccent.opacity(opacity)
            case .neutral: return Color.btTextSecondary.opacity(scheme == .dark ? 0.22 : 0.12)
            }
        }
    }

    let systemName: String
    /// 圆底直径。列表行常用 32；FeatureCard 常用 48。
    var size: CGFloat = 32
    /// 图形字号相对圆底直径的比例（默认 0.5，即 32 → 16pt）。
    var glyphRatio: CGFloat = 0.5
    var weight: Font.Weight = .semibold
    var tint: Tint = .primary

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * glyphRatio, weight: weight))
            .foregroundStyle(tint.foreground)
            .frame(width: size, height: size)
            .background(tint.background(scheme))
            .clipShape(Circle())
    }
}

#Preview("BTIconBadge") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            BTIconBadge(systemName: BTIcon.heartFilled)
            BTIconBadge(systemName: BTIcon.person)
            BTIconBadge(systemName: BTIcon.target)
            BTIconBadge(systemName: BTIcon.crown, tint: .accent)
            BTIconBadge(systemName: BTIcon.gear, tint: .neutral)
        }
        HStack(spacing: 16) {
            BTIconBadge(systemName: BTIcon.scope, size: 48, glyphRatio: 0.46, weight: .medium)
            BTIconBadge(systemName: BTIcon.ruler, size: 48, glyphRatio: 0.46, weight: .medium)
            BTIconBadge(systemName: BTIcon.crown, size: 48, glyphRatio: 0.46, weight: .medium, tint: .accent)
        }
    }
    .padding()
    .background(.btBG)
}
