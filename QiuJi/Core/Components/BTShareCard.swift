import SwiftUI

// MARK: - Supporting Types

struct TrainingSessionSummary {
    let date: Date
    let planName: String
    let durationMinutes: Int
    let completedDrills: Int
    let totalSets: Int
    let overallSuccessRate: Double
    let drills: [DrillResult]
    /// 训练心得（`TrainingSession.note`）。为空时分享图不渲染心得段。
    var note: String = ""

    struct DrillResult: Identifiable {
        let id = UUID()
        let name: String
        let setsCount: Int
        let madeBalls: Int
        let targetBalls: Int
        /// 用于取烘焙缩略图（`Resources/DrillThumbnails/<id>.png`）；为空时不渲染缩略图。
        var drillId: String = ""
        /// 逐组明细。为空时分享图退化为聚合行，不编造数据。
        var sets: [SetResult] = []

        struct SetResult: Identifiable {
            let id: Int
            let madeBalls: Int
            let targetBalls: Int

            /// `nil` 表示这一组没有可判定的目标球数（例如走位类未登记 target），
            /// 与「成功率 0%」是两回事，调用方不得混为一谈。
            var rate: Double? {
                guard targetBalls > 0 else { return nil }
                return Double(madeBalls) / Double(targetBalls)
            }
        }

        var successRate: Double {
            guard targetBalls > 0 else { return 0 }
            return Double(madeBalls) / Double(targetBalls)
        }

        /// 逐组里是否有任何登记过的数字。全是 `0/0` 时网格没有信息量，
        /// 分享图应退化为聚合行，而不是铺一屏无意义的格子。
        var hasRecordedSetData: Bool {
            sets.contains { $0.targetBalls > 0 || $0.madeBalls > 0 }
        }
    }

    var totalBallsMade: Int {
        drills.reduce(0) { $0 + $1.madeBalls }
    }

    var totalBallsTarget: Int {
        drills.reduce(0) { $0 + $1.targetBalls }
    }

    /// 本次训练是否有可判定的成功率。全部 target 为 0 时为 `false`，
    /// 此时百分比应显示为「—」而非 0%（未定义 ≠ 0）。
    var hasScoredBalls: Bool { totalBallsTarget > 0 }

    /// 逐组成功率，仅统计 target > 0 的组。
    var scoredSetRates: [Double] {
        drills.flatMap(\.sets).compactMap(\.rate)
    }

    var bestSet: DrillResult.SetResult? {
        drills.flatMap(\.sets)
            .filter { $0.rate != nil }
            .max { ($0.rate ?? 0) < ($1.rate ?? 0) }
    }

    /// 组间波动（各组成功率的总体标准差）。少于 2 个可判定组时为 `nil`。
    var setRateStdDev: Double? {
        let rates = scoredSetRates
        guard rates.count >= 2 else { return nil }
        let mean = rates.reduce(0, +) / Double(rates.count)
        let variance = rates.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rates.count)
        return variance.squareRoot()
    }
}

enum ShareCardTheme: String, CaseIterable, Identifiable {
    /// Warm paper. Default — previous four presets were all dark, so the
    /// share page looked like it had no background choice (DR-079).
    case paper = "浅色"
    /// F-TS-09: named by base tone (charcoal), matching nightBlue / deepPurple convention.
    case defaultGreen = "炭灰"
    case blackWhite = "黑白"
    case nightBlue = "暗夜蓝"
    case deepPurple = "深紫"

    var id: String { rawValue }

    var isLight: Bool { self == .paper }

    var backgroundColor: Color {
        switch self {
        case .paper: return Color(red: 0xF7 / 255.0, green: 0xF6 / 255.0, blue: 0xF2 / 255.0)
        case .defaultGreen: return Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
        case .nightBlue: return Color(red: 0x0D / 255.0, green: 0x1B / 255.0, blue: 0x2A / 255.0)
        case .blackWhite: return Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
        case .deepPurple: return Color(red: 0x1A / 255.0, green: 0x14 / 255.0, blue: 0x2A / 255.0)
        }
    }

    var accentColor: Color {
        switch self {
        case .paper, .defaultGreen: return .btPrimary
        case .nightBlue: return Color(red: 0x4A / 255.0, green: 0x9E / 255.0, blue: 0xFF / 255.0)
        case .blackWhite: return .white
        case .deepPurple: return Color(red: 0xBB / 255.0, green: 0x86 / 255.0, blue: 0xFC / 255.0)
        }
    }

    /// Ink on paper / white on dark. All card copy must go through these,
    /// not hardcoded `.white`, or a light theme becomes unreadable.
    var primaryText: Color {
        isLight ? Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0) : .white
    }

    var secondaryText: Color { primaryText.opacity(isLight ? 0.62 : 0.55) }
    var tertiaryText: Color { primaryText.opacity(isLight ? 0.48 : 0.50) }
    var mutedText: Color { primaryText.opacity(isLight ? 0.40 : 0.45) }
    var surfaceFill: Color { (isLight ? Color.black : Color.white).opacity(isLight ? 0.045 : 0.05) }
    var trackFill: Color { (isLight ? Color.black : Color.white).opacity(isLight ? 0.08 : 0.08) }
    var hairline: Color { (isLight ? Color.black : Color.white).opacity(isLight ? 0.10 : 0.10) }
    var footerFill: Color { Color.black.opacity(isLight ? 0.05 : 0.20) }
    var qrPlate: Color { isLight ? .white : .white.opacity(0.9) }
    var qrGlyph: Color { .black.opacity(isLight ? 0.55 : 0.40) }
    var lowRate: Color { isLight ? Color(red: 0.42, green: 0.42, blue: 0.44) : .white.opacity(0.60) }

    /// Swatch fill is the actual card background so light vs dark is obvious.
    var previewColor: Color { backgroundColor }
}

enum ShareCardFont: String, CaseIterable {
    case system = "跟随系统"
    case rounded = "圆角字体"

    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        }
    }
}

/// 分享图专用字阶。**不复用** App 的 `.bt*` 字体 token：导出图必须在任何系统
/// 动态字体档位下都排版一致，因此这里全部写死 pt 值。
private enum ShareType {
    static let brandTitle: CGFloat = 15
    static let brandMeta: CGFloat = 11
    static let hero: CGFloat = 26
    static let heroSub: CGFloat = 13
    static let metricValue: CGFloat = 26
    static let metricLabel: CGFloat = 11
    static let sectionTitle: CGFloat = 12
    static let drillName: CGFloat = 15
    static let drillScore: CGFloat = 14
    static let barLabel: CGFloat = 12
    static let chipValue: CGFloat = 15
    static let chipLabel: CGFloat = 11
    static let setCell: CGFloat = 10
    static let body: CGFloat = 13
    static let footerTitle: CGFloat = 13
    static let footerMeta: CGFloat = 10
}

// MARK: - BTShareCard

/// 长图版训练分享卡：宽度固定、高度随内容自适应。
///
/// - Important: 卡内**不得**出现贪婪的 `Spacer()` / `maxHeight: .infinity`。
///   历史上正是根部的 `Spacer(minLength: 0)` 让 `ImageRenderer` 在只给宽度时
///   高度失控（见 `ShareCardImageRendererRootCauseDiagTests`），当时的止血手段
///   是把高度钉死成 480pt，代价是长内容被压扁、短内容留大片空白。
struct BTShareCard: View {
    let session: TrainingSessionSummary
    let theme: ShareCardTheme
    var fontChoice: ShareCardFont = .system
    var hideSuccessRate: Bool = false
    // F-TS-04 / W2-2: hideBallTable dead API removed — no ball-table region to toggle.

    /// 逐组网格的总预算：总组数超过此值时，每个 drill 只画前 `foldedSetsPerDrill` 组，
    /// 其余折叠成「+N 组」。用于给导出图高度封顶。
    static let setGridBudget = 36
    static let foldedSetsPerDrill = 12
    /// 单张图最多画多少张 drill 卡片，超出折叠成一行汇总。
    static let maxDrillCards = 8
    static let setsPerGridRow = 6
    /// 心得最多显示的行数：分享图是「摘要」不是「存档」，长心得不应把图撑到无界。
    static let noteLineLimit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            brandHeader
            heroSection
            if showsOverview {
                overviewSection
            }
            if !session.drills.isEmpty {
                drillSection
            }
            if !session.note.isEmpty {
                noteSection
            }
            brandFooter
        }
        .padding(Spacing.xl)
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(spacing: Spacing.md) {
            BTBrandLogo(size: 36, style: .onTile)

            VStack(alignment: .leading, spacing: 2) {
                Text("QiuJi 球迹")
                    .font(.system(size: ShareType.brandTitle, weight: .semibold, design: fontDesign))
                    .foregroundStyle(theme.primaryText)
                Text(headerMeta)
                    .font(.system(size: ShareType.brandMeta, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var headerMeta: String {
        let date = Self.dateLabel(session.date)
        let range = Self.timeRangeLabel(start: session.date, durationMinutes: session.durationMinutes)
        return "\(date) · \(range)"
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                Text(session.planName)
                    .font(.system(size: ShareType.hero, weight: .bold, design: fontDesign))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)

                Text(heroSubtitle)
                    .font(.system(size: ShareType.heroSub, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.secondaryText)
            }

            metricsRow
        }
    }

    /// 只说「练了什么」，数量交给下面的四大数字，避免同一组数字出现两次。
    private var heroSubtitle: String {
        "共 \(session.completedDrills) 项训练"
    }

    private struct Metric: Identifiable {
        let id = UUID()
        let value: String
        let label: String
        var color: Color?
    }

    private var metrics: [Metric] {
        var items: [Metric] = [
            // F-TS-11: 不足一分钟的训练不得读成「0 分钟」。
            Metric(value: session.durationMinutes < 1 ? "<1" : "\(session.durationMinutes)", label: "分钟"),
            Metric(value: "\(session.totalSets)", label: "组数"),
            Metric(value: "\(session.totalBallsMade)", label: "进球"),
        ]
        if !hideSuccessRate {
            items.append(
                Metric(
                    value: session.hasScoredBalls ? Self.percentLabel(session.overallSuccessRate) : "—",
                    label: "成功率",
                    color: session.hasScoredBalls ? rateColor(session.overallSuccessRate) : theme.tertiaryText
                )
            )
        }
        return items
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(theme.hairline)
                        .frame(width: 1, height: 28)
                }
                VStack(spacing: 3) {
                    Text(metric.value)
                        .font(.system(size: ShareType.metricValue, weight: .bold, design: fontDesign))
                        .foregroundStyle(metric.color ?? theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(metric.label)
                        .font(.system(size: ShareType.metricLabel, weight: .regular, design: fontDesign))
                        .foregroundStyle(theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.lg)
        .background(theme.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Overview

    /// 只有在「多个 drill 可对比」或「有可判定的逐组数据」时才出现，
    /// 避免为了填版面而展示与 Hero 重复的数字。
    private var showsOverview: Bool {
        guard !hideSuccessRate else { return false }
        if session.drills.count >= 2 && session.hasScoredBalls { return true }
        return session.bestSet != nil || session.setRateStdDev != nil
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("成绩概览")

            if session.drills.count >= 2 && session.hasScoredBalls {
                VStack(spacing: Spacing.sm) {
                    ForEach(session.drills.prefix(Self.maxDrillCards)) { drill in
                        rateBar(drill)
                    }
                }
            }

            if !derivedChips.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(derivedChips) { chip in
                        derivedChip(chip)
                    }
                }
            }
        }
    }

    private func rateBar(_ drill: TrainingSessionSummary.DrillResult) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(drill.name)
                .font(.system(size: ShareType.barLabel, weight: .regular, design: fontDesign))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.trackFill)
                    Capsule()
                        .fill(rateColor(drill.successRate))
                        .frame(width: max(2, geo.size.width * drill.successRate.clampedUnit))
                }
            }
            .frame(height: 6)

            Text(drill.targetBalls > 0 ? Self.percentLabel(drill.successRate) : "—")
                .font(.system(size: ShareType.barLabel, weight: .semibold, design: fontDesign))
                .foregroundStyle(theme.primaryText.opacity(0.85))
                .frame(width: 40, alignment: .trailing)
        }
    }

    private struct Chip: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    private var derivedChips: [Chip] {
        var chips: [Chip] = []
        if let best = session.bestSet {
            chips.append(Chip(value: "\(best.madeBalls)/\(best.targetBalls)", label: "最佳一组"))
        }
        if let spread = session.setRateStdDev {
            chips.append(Chip(value: "±\(Int((spread * 100).rounded()))%", label: "组间波动"))
        }
        return chips
    }

    private func derivedChip(_ chip: Chip) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(chip.value)
                .font(.system(size: ShareType.chipValue, weight: .bold, design: fontDesign))
                .foregroundStyle(theme.primaryText)
            Text(chip.label)
                .font(.system(size: ShareType.chipLabel, weight: .regular, design: fontDesign))
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(theme.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    // MARK: - Drill Section

    private var visibleDrills: [TrainingSessionSummary.DrillResult] {
        Array(session.drills.prefix(Self.maxDrillCards))
    }

    private var hiddenDrillCount: Int {
        max(0, session.drills.count - Self.maxDrillCards)
    }

    /// 总组数超预算时，每个 drill 的逐组网格上限；`nil` 表示全画。
    private var setsLimitPerDrill: Int? {
        let total = session.drills.reduce(0) { $0 + $1.sets.count }
        return total > Self.setGridBudget ? Self.foldedSetsPerDrill : nil
    }

    private var drillSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("训练明细")

            VStack(spacing: Spacing.md) {
                ForEach(visibleDrills) { drill in
                    drillCard(drill)
                }
            }

            if hiddenDrillCount > 0 {
                Text("还有 \(hiddenDrillCount) 项未展示")
                    .font(.system(size: ShareType.chipLabel, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.mutedText)
            }
        }
    }

    private func drillCard(_ drill: TrainingSessionSummary.DrillResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                if !drill.drillId.isEmpty {
                    BTBakedDrillTable(drillId: drill.drillId, contentMode: .fill)
                        .frame(width: 72, height: 40)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.name)
                        .font(.system(size: ShareType.drillName, weight: .semibold, design: fontDesign))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text("\(drill.setsCount) 组")
                        .font(.system(size: ShareType.chipLabel, weight: .regular, design: fontDesign))
                        .foregroundStyle(theme.tertiaryText)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(drill.madeBalls)/\(drill.targetBalls)")
                        .font(.system(size: ShareType.drillScore, weight: .semibold, design: fontDesign))
                        .foregroundStyle(theme.primaryText)
                    if !hideSuccessRate {
                        Text(drill.targetBalls > 0 ? Self.percentLabel(drill.successRate) : "—")
                            .font(.system(size: ShareType.drillScore, weight: .bold, design: fontDesign))
                            .foregroundStyle(
                                drill.targetBalls > 0 ? rateColor(drill.successRate) : theme.tertiaryText
                            )
                    }
                }
            }

            if drill.hasRecordedSetData {
                setGrid(drill.sets)
            }
        }
        .padding(Spacing.md + 2)
        .background(theme.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func setGrid(_ sets: [TrainingSessionSummary.DrillResult.SetResult]) -> some View {
        let limit = setsLimitPerDrill
        let shown = limit.map { Array(sets.prefix($0)) } ?? sets
        let hidden = sets.count - shown.count
        let rows = stride(from: 0, to: shown.count, by: Self.setsPerGridRow).map { start in
            Array(shown[start..<min(start + Self.setsPerGridRow, shown.count)])
        }

        return VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Spacing.xs + 2) {
                    ForEach(row) { item in
                        setCell(item)
                    }
                    // 末行补空位，保证各行格子等宽对齐。
                    if row.count < Self.setsPerGridRow {
                        ForEach(0..<(Self.setsPerGridRow - row.count), id: \.self) { _ in
                            Color.clear.frame(height: 26).frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            if hidden > 0 {
                Text("+\(hidden) 组")
                    .font(.system(size: ShareType.setCell, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.mutedText)
            }
        }
    }

    private func setCell(_ item: TrainingSessionSummary.DrillResult.SetResult) -> some View {
        Text("\(item.madeBalls)/\(item.targetBalls)")
            .font(.system(size: ShareType.setCell, weight: .semibold, design: fontDesign))
            .foregroundStyle(theme.primaryText.opacity(item.rate == nil ? 0.45 : 0.95))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(setCellFill(item))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }

    /// 底色深浅表达该组成功率；没有可判定 target 的组保持中性灰，不伪装成 0%。
    /// 「隐藏成功率」时底色一并中性化——深浅本身就是一种成功率读数。
    private func setCellFill(_ item: TrainingSessionSummary.DrillResult.SetResult) -> Color {
        guard !hideSuccessRate, let rate = item.rate else { return theme.trackFill }
        return theme.accentColor.opacity(0.18 + 0.55 * rate.clampedUnit)
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("训练心得")

            HStack(alignment: .top, spacing: Spacing.md) {
                Capsule()
                    .fill(theme.accentColor.opacity(0.7))
                    .frame(width: 3)
                Text(session.note)
                    .font(.system(size: ShareType.body, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.primaryText.opacity(0.85))
                    .lineSpacing(5)
                    .lineLimit(Self.noteLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.md + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Brand Footer

    private var brandFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("QiuJi 球迹")
                    .font(.system(size: ShareType.footerTitle, weight: .bold, design: fontDesign))
                    .foregroundStyle(theme.primaryText)
                Text("台球训练记录 App")
                    .font(.system(size: ShareType.footerMeta, weight: .regular, design: fontDesign))
                    .foregroundStyle(theme.tertiaryText)
            }
            Spacer(minLength: Spacing.md)
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.qrPlate)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.hairline, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(theme.qrGlyph)
                )
        }
        .padding(Spacing.lg)
        .background(theme.footerFill)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Shared Pieces

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Capsule()
                .fill(theme.accentColor)
                .frame(width: 3, height: 12)
            Text(text)
                .font(.system(size: ShareType.sectionTitle, weight: .semibold, design: fontDesign))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.9 {
            return Color(red: 0x25 / 255.0, green: 0xA2 / 255.0, blue: 0x5A / 255.0)
        } else if rate >= 0.7 {
            return theme.accentColor
        } else {
            return theme.lowRate
        }
    }

    private var fontDesign: Font.Design {
        fontChoice.fontDesign
    }

    static func percentLabel(_ rate: Double) -> String {
        "\(Int((rate * 100).rounded()))%"
    }

    /// F-TS-11: sub-minute sessions must not read as「0 分钟」.
    static func durationLabel(minutes: Int) -> String {
        if minutes < 1 { return "不足 1 分钟" }
        return "\(minutes) 分钟"
    }

    static func dateLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日"
        return fmt.string(from: date)
    }

    static func timeRangeLabel(start: Date, durationMinutes: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        let end = Calendar.current.date(byAdding: .minute, value: max(0, durationMinutes), to: start) ?? start
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }
}

private extension Double {
    var clampedUnit: Double { Swift.min(1, Swift.max(0, self)) }
}

// MARK: - Preview

private let sampleSession = TrainingSessionSummary(
    date: Date(),
    planName: "力量训练 Day 1",
    durationMinutes: 48,
    completedDrills: 3,
    totalSets: 12,
    overallSuccessRate: 0.72,
    drills: [
        .init(
            name: "定点红球进袋", setsCount: 4, madeBalls: 31, targetBalls: 40,
            drillId: "drill_c001",
            sets: (1...4).map { .init(id: $0, madeBalls: [9, 8, 7, 7][$0 - 1], targetBalls: 10) }
        ),
        .init(
            name: "斯诺克直线进袋", setsCount: 3, madeBalls: 28, targetBalls: 30,
            drillId: "drill_c002",
            sets: (1...3).map { .init(id: $0, madeBalls: [10, 9, 9][$0 - 1], targetBalls: 10) }
        ),
        .init(
            name: "走位练习 A", setsCount: 5, madeBalls: 28, targetBalls: 50,
            drillId: "drill_c003",
            sets: (1...5).map { .init(id: $0, madeBalls: [4, 6, 5, 7, 6][$0 - 1], targetBalls: 10) }
        ),
    ],
    note: "今天手感一般，长台准度掉得厉害。后半段调整了站位，右手腕放松之后稳定了一些，明天继续练直线。"
)

#Preview("BTShareCard Themes") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            ForEach(ShareCardTheme.allCases) { theme in
                BTShareCard(session: sampleSession, theme: theme)
                    .frame(width: 375)
            }
        }
        .padding(Spacing.xxl)
    }
    .background(Color.btBG)
}

#Preview("BTShareCard Rounded Font") {
    ScrollView {
        BTShareCard(session: sampleSession, theme: .defaultGreen, fontChoice: .rounded)
            .frame(width: 375)
            .padding(Spacing.xxl)
    }
    .background(Color.btBG)
}

#Preview("BTShareCard Single Drill / Many Sets") {
    ScrollView {
        BTShareCard(
            session: TrainingSessionSummary(
                date: Date(),
                planName: "初级蛇彩走位",
                durationMinutes: 12,
                completedDrills: 1,
                totalSets: 17,
                overallSuccessRate: 0,
                drills: [
                    .init(
                        name: "初级蛇彩走位", setsCount: 17, madeBalls: 0, targetBalls: 0,
                        drillId: "drill_c069",
                        sets: (1...17).map { .init(id: $0, madeBalls: 0, targetBalls: 0) }
                    ),
                ]
            ),
            theme: .defaultGreen
        )
        .frame(width: 375)
        .padding(Spacing.xxl)
    }
    .background(Color.btBG)
}
