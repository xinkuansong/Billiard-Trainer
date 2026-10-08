import SwiftUI

/// The reference header is shared by shot pages and interactive teaching pages.
/// Callers supply capabilities and ball actions; layout, palette and telemetry stay identical.
struct DailyTemplateHeader<Title: View, Actions: View, Ball: View, Marker: View>: View {
    let size: CGSize
    let safe: CGFloat
    let foundation: DailyLayoutMetrics.Foundation
    let plan: DailyLayoutMetrics.Palette
    let targets: [String]
    let chineseEightBall: Bool
    let titleWidth: CGFloat
    let titleHeight: CGFloat
    let windowControlInsets: UIEdgeInsets
    let fps: TableFPSReadoutState
    let showsDeviceStatus: Bool
    @ViewBuilder var title: () -> Title
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var ball: (String, CGFloat, CGFloat) -> Ball
    @ViewBuilder var paletteMarker: () -> Marker

    var body: some View {
        let y = foundation.table.minY - plan.height / 2
        let grid = plan.twoRows && chineseEightBall
            ? targets.filter { $0 != "_8" } : targets
        let split = (grid.count + 1) / 2
        let statusRect = CGRect(x: size.width - max(4, safe) - windowControlInsets.right - 44 - 5 - 32,
                                y: 1.5, width: 32, height: 41)
        let paletteRect = CGRect(x: foundation.table.midX - plan.targetWidth / 2,
                                 y: foundation.table.minY - plan.height,
                                 width: plan.targetWidth + (plan.wingWidth > 0 ? 4 + plan.wingWidth : 0), height: plan.height)
        let titleRect = CGRect(x: max(4, safe) + windowControlInsets.left, y: 0,
                               width: 32 + titleWidth, height: 44)
        let statusFits = DailyDeviceStatus.fits(statusRect, in: CGRect(origin: .zero, size: size),
            obstacles: [titleRect] + (plan.fits ? [paletteRect] : []), clearance: 2)
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                title()
                Spacer(minLength: 4)
                actions()
            }
            .padding(.leading, max(4, safe) + windowControlInsets.left)
            .padding(.trailing, max(4, safe) + windowControlInsets.right)
            .frame(width: size.width, height: 44)
            if statusFits {
                DailyStatusCluster(fps: fps, showsDeviceStatus: showsDeviceStatus)
                    .position(x: statusRect.midX, y: statusRect.midY)
            }
            Group {
                if plan.twoRows {
                    VStack(spacing: 4) {
                        targetRow(Array(grid.prefix(split)), plan: plan)
                        targetRow(Array(grid.dropFirst(split)), plan: plan)
                    }
                    .background(Color.clear.accessibilityElement().accessibilityIdentifier("dailyClearance.twoRowPalette"))
                } else {
                    targetRow(targets, plan: plan)
                        .background(Color.clear.accessibilityElement().accessibilityIdentifier("dailyClearance.singleRowPalette"))
                }
            }
            .frame(width: plan.targetWidth, height: plan.height)
            .background(paletteMarker())
            .opacity(plan.fits ? 1 : 0).allowsHitTesting(plan.fits).accessibilityHidden(!plan.fits)
            .position(x: foundation.table.midX, y: y)
            if plan.fits && plan.twoRows && chineseEightBall {
                wing("_8", plan: plan)
                    .position(x: foundation.table.midX + plan.targetWidth / 2 + 4 + plan.wingWidth / 2, y: y)
            }
        }
        .foregroundStyle(.btText)
        .buttonStyle(BTHUDPressStyle())
        .frame(width: size.width, height: max(44, foundation.table.minY + 5), alignment: .topLeading)

    }

    func wing(_ key: String, plan: DailyLayoutMetrics.Palette) -> some View {
        ball(key, plan.diameter, plan.twoRows ? plan.rowHeight : 44)
            .frame(width: plan.wingWidth, height: plan.rowHeight)
            .background { paletteBackground(height: plan.rowHeight) }
    }

    func targetRow(_ targets: [String], plan: DailyLayoutMetrics.Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(targets, id: \.self) { key in
                HStack(spacing: 0) {
                    if !plan.twoRows && chineseEightBall && (key == "_8" || key == "_9") {
                        Rectangle().fill(HUDStyle.hairline).frame(width: 1, height: 18)
                            .padding(.horizontal, 2).accessibilityHidden(true)
                    }
                    ball(key, plan.diameter, plan.twoRows ? plan.rowHeight : 44).id(key)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: plan.rowHeight)
        .background { paletteBackground(height: plan.rowHeight) }
    }

    func paletteBackground(height: CGFloat) -> some View {
        Capsule().fill(HUDStyle.controlBackground)
            .overlay(Capsule().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
            .frame(height: height).allowsHitTesting(false)
    }


}

struct DailyCarpetBackground: View {
    let style: RoomStyle
    let pointsPerMetre: CGFloat

    var body: some View {
        Canvas { context, size in
            guard let texture = UIImage(named: "Carpet_\(style.rawValue).png") else {
                assertionFailure("Missing daily carpet atlas: \(style.rawValue)")
                return
            }
            let metres: CGSize
            switch style {
            case .tournament: metres = CGSize(width: 5, height: 4)
            case .walnut: metres = CGSize(width: 2.5, height: 2)
            case .eastern: metres = CGSize(width: CGFloat(BakedTrainingRoom.roomLength),
                                           height: CGFloat(BakedTrainingRoom.roomWidth))
            }
            let tile = CGSize(width: max(1, metres.width * pointsPerMetre),
                              height: max(1, metres.height * pointsPerMetre))
            let columns = Int(ceil(size.width / tile.width / 2))
            let rows = Int(ceil(size.height / tile.height / 2))
            let image = Image(uiImage: texture)
            for row in -rows...rows {
                for column in -columns...columns {
                    var cell = context
                    cell.translateBy(x: size.width / 2 + CGFloat(column) * tile.width,
                                     y: size.height / 2 + CGFloat(row) * tile.height)
                    cell.scaleBy(x: column.isMultiple(of: 2) ? 1 : -1,
                                 y: row.isMultiple(of: 2) ? 1 : -1)
                    cell.draw(image, in: CGRect(x: -tile.width / 2, y: -tile.height / 2,
                                               width: tile.width, height: tile.height))
                }
            }
        }
        .overlay(HUDStyle.controlBackground)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
