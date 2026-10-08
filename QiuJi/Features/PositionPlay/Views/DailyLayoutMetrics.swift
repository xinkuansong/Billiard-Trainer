import SwiftUI

/// Daily Clearance's existing visual language, expressed in logical points.
/// Reference preferences and capacity budgets; physical extents come from the scene.
enum DailyLayoutMetrics {
    static let headerHeight: CGFloat = 44
    static let controlColumnWidth: CGFloat = 60
    static let topButtonDiameter: CGFloat = 48
    static let rulerWidth: CGFloat = 32
    static let rulerHeight = ShotStageMetrics.dailyPowerBarHeight
    static let tableLift = Spacing.sm

    /// The camera stack occupies an outer 44pt lane plus the 4pt inter-column gap.
    static let cameraLaneWidth: CGFloat = 48
    /// Existing title/mode alignment into the trailing safe area, capped at 24pt.
    static let headerTrailingExtension: CGFloat = 24

    static let regularBallDiameter: CGFloat = 30
    static let compactBallDiameter: CGFloat = 25
    struct Controls {
        /// Bootstrap only. The daily host measures the instrument before outer
        /// padding; fractional font heights differ between display scales.
        static let initialInstrumentHeight: CGFloat = 259
        static let defaultVerticalPadding = Spacing.sm
        // Break entry (48 + 2 + 12), ruler label/insets (6 + 12 + 12),
        // and two inter-group gaps (2 * 6). Ruler and actions are separate.
        static let leftNonRulerHeight: CGFloat = 104
        static let stackedActionsHeight: CGFloat = 92
        static let horizontalActionsHeight: CGFloat = 44
        static let stackedHeadroom: CGFloat = 2
        let horizontalActions: Bool
        let minimumRequiredHeight: CGFloat
        let verticalPadding: CGFloat
        let fitsWithoutPadding: Bool

        init(stageHeight: CGFloat, instrumentHeight: CGFloat, displayScale: CGFloat,
             topGrowth: CGFloat = 0, auxiliaryGrowth: CGFloat = 0) {
            let height = stageHeight.isFinite ? max(0, stageHeight) : 0
            let instrument = instrumentHeight.isFinite && instrumentHeight > 0
                ? instrumentHeight : Self.initialInstrumentHeight
            let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
            // Preserve the established 358pt presentation boundary. This is
            // the left column's full content ledger, not a device breakpoint.
            horizontalActions = height < rulerHeight + Self.leftNonRulerHeight
                + Self.stackedActionsHeight + topGrowth + 2 * auxiliaryGrowth
                + 2 * Self.defaultVerticalPadding + Self.stackedHeadroom
            let leftMinimum = rulerHeight + Self.leftNonRulerHeight
                + topGrowth + (horizontalActions ? Self.horizontalActionsHeight + auxiliaryGrowth
                    : Self.stackedActionsHeight + 2 * auxiliaryGrowth)
            let rightMinimum = instrument + Spacing.xs + controlColumnWidth
            minimumRequiredHeight = max(leftMinimum, rightMinimum)
            fitsWithoutPadding = height >= minimumRequiredHeight
            // Round down so a fractional font metric cannot push a column
            // beyond its proposal by a display pixel. No UI scale is applied.
            let availablePadding = max(0, height - minimumRequiredHeight) / 2
            verticalPadding = min(Self.defaultVerticalPadding, floor(availablePadding * scale) / scale)
        }
    }

    /// Compares actual proportional table capacity, in page-local logical points.
    /// The dock moves actions beside the instruments, retaining vertical 144pt travel.
    /// No device name or aspect-ratio breakpoint selects the arrangement.
    struct Space {
        let foundation: Foundation?
        let docked: Bool
        let stage: CGRect
        let left: CGRect
        let right: CGRect
        let columnWidth: CGFloat
        let topDiameter: CGFloat
        let auxiliarySize: CGFloat
        let strikeSize: CGFloat
        let sideTableWidth: CGFloat
        let dockTableWidth: CGFloat
        let controls: Controls
        let playingCapacity: CGFloat
        var isLimited: Bool {
            if let foundation { return !foundation.fits }
            return (!docked && !controls.fitsWithoutPadding) || playingCapacity < SpinPad.minimumExtent
        }

        init(size: CGSize, trailingSafeArea: CGFloat, halfLength: Double, halfWidth: Double,
             instrumentHeight: CGFloat, displayScale: CGFloat, allowsDock: Bool = true,
             foundation: Foundation? = nil) {
            self.foundation = foundation
            if let foundation {
                docked = false
                stage = foundation.stage; left = foundation.left; right = foundation.right
                columnWidth = 60; topDiameter = foundation.topDiameter
                auxiliarySize = foundation.auxiliarySize; strikeSize = 60
                sideTableWidth = foundation.table.width; dockTableWidth = 0
                playingCapacity = min(foundation.table.width, foundation.table.height)
                controls = Controls(stageHeight: foundation.left.height, instrumentHeight: instrumentHeight, displayScale: displayScale)
                return
            }
            let base = Container(size: size, trailingSafeArea: trailingSafeArea)
            let bodyHeight = max(0, size.height - headerHeight)
            // Only spend spare height inside the existing column. A reference Pro
            // at 358pt has zero growth; extra height stops buying larger buttons at 8pt.
            let growth = min(8, max(0, (bodyHeight - 358) / 2))
            topDiameter = topButtonDiameter + growth
            auxiliarySize = 44 + growth / 2
            let naturalInstrument = (instrumentHeight.isFinite && instrumentHeight > 0
                ? instrumentHeight : Controls.initialInstrumentHeight) + growth
            let dockHeight = naturalInstrument + 2 * Spacing.sm
            let dockStage = CGSize(width: max(1, size.width - 2 * Spacing.sm),
                                   height: max(1, bodyHeight - dockHeight - 2 * Spacing.sm))
            func tableWidth(_ proposal: CGSize) -> CGFloat {
                guard let scale = CameraRig.landscapeOrthographicScale(viewSize: proposal,
                    halfLength: halfLength, halfWidth: halfWidth) else { return 0 }
                return CGFloat(halfLength / scale) * proposal.height
            }
            sideTableWidth = tableWidth(base.stageSize)
            dockTableWidth = tableWidth(dockStage)
            // Two distinct action/instrument groups and the right outer camera lane.
            let dockStrikeSize: CGFloat = 72
            let dockMinimumWidth = (controlColumnWidth + auxiliarySize + Spacing.sm)
                + (controlColumnWidth + dockStrikeSize + Spacing.sm)
                + 2 * cameraLaneWidth + 3 * Spacing.sm
            docked = allowsDock && size.width >= dockMinimumWidth && dockStage.height >= SpinPad.minimumExtent
                && dockTableWidth > sideTableWidth + 1 / max(1, displayScale)
            columnWidth = controlColumnWidth
            strikeSize = docked ? dockStrikeSize : controlColumnWidth
            let baseControls = Controls(stageHeight: bodyHeight, instrumentHeight: naturalInstrument,
                displayScale: displayScale, topGrowth: growth, auxiliaryGrowth: growth / 2)
            let tableHeight = sideTableWidth * CGFloat(halfWidth / halfLength)
            let railSlack = max(0, (base.stageSize.height - tableHeight) / 2 - tableLift)
            // Do not reclaim the 2pt stacking headroom: doing so flips the
            // reference Pro to horizontal auxiliary actions after asset measurement.
            let stackBoundary = rulerHeight + Controls.leftNonRulerHeight + Controls.stackedActionsHeight
                + growth * 2 + 2 * Controls.defaultVerticalPadding + Controls.stackedHeadroom
            let protectedHeight = max(baseControls.minimumRequiredHeight + 2 * baseControls.verticalPadding,
                baseControls.horizontalActions ? 0 : stackBoundary)
            let controlSlack = max(0, (bodyHeight - protectedHeight) / 2)
            let sideShift = min(railSlack, controlSlack)
            controls = Controls(stageHeight: bodyHeight - (docked ? 0 : 2 * sideShift),
                instrumentHeight: naturalInstrument, displayScale: displayScale,
                topGrowth: growth, auxiliaryGrowth: growth / 2)
            if docked {
                // Spend only the height needed to fit the wider table. The remaining
                // gap separates play from hands; never stretch rulers to fill it.
                let fitHeight = dockStage.width * CGFloat(halfWidth / halfLength)
                let stageHeight = min(dockStage.height, fitHeight)
                stage = CGRect(x: Spacing.sm, y: headerHeight, width: dockStage.width, height: stageHeight)
                let groupWidth = columnWidth + auxiliarySize + Spacing.sm
                let y = size.height - dockHeight
                left = CGRect(x: Spacing.sm + cameraLaneWidth, y: y, width: groupWidth, height: dockHeight)
                right = CGRect(x: size.width - Spacing.sm - cameraLaneWidth - columnWidth - strikeSize - Spacing.sm,
                    y: y, width: columnWidth + strikeSize + Spacing.sm, height: dockHeight)
            } else {
                stage = CGRect(x: controlColumnWidth + 2 * Spacing.xs + base.sideInset,
                    y: headerHeight - tableLift, width: base.stageSize.width, height: base.stageSize.height)
                left = CGRect(x: Spacing.xs + base.sideInset, y: headerHeight + sideShift,
                              width: columnWidth, height: bodyHeight - 2 * sideShift)
                right = CGRect(x: size.width - Spacing.xs - base.sideInset - columnWidth, y: headerHeight + sideShift,
                               width: columnWidth, height: bodyHeight - 2 * sideShift)
            }
            let playing = ShotTableLayout.landscapePlayingRect(in: stage.size,
                halfLength: halfLength, halfWidth: halfWidth)
            playingCapacity = min(playing.width, playing.height)
        }
    }

    /// C26 foundation. All rectangles are page-local points, never screen pixels.
    /// The stage includes the renderer's symmetric fitting margin; table is the
    /// visible physical outer bound, excluding the cue and transparent padding.
    struct Foundation {
        let rotated: Bool
        let table: CGRect
        let stage: CGRect
        let left: CGRect
        let right: CGRect
        let rulerLength: CGFloat
        let topDiameter: CGFloat
        let auxiliarySize: CGFloat
        let gap: CGFloat
        let horizontalActions: Bool
        let fits: Bool

        init(size: CGSize, leadingSafeArea: CGFloat, trailingSafeArea: CGFloat,
             halfLength: Double, halfWidth: Double, instrumentHeight: CGFloat,
             palette: FoundationReservation? = nil) {
            let width = size.width.isFinite ? max(0, size.width) : 0
            let height = size.height.isFinite ? max(0, size.height) : 0
            rotated = height > width
            // Approved 48/56 and 44/48 tiers. Growth uses the height of a complete
            // regular control stack plus the header and its breathing room.
            let roomy = height >= headerHeight + 352
            topDiameter = roomy ? 56 : 48
            auxiliarySize = roomy ? 48 : 44
            let regularStack = topDiameter + 14 + 4 + 174 + 4 + 2 * auxiliarySize + 4
            rulerLength = height >= headerHeight + regularStack ? 144 : 120
            gap = rulerLength == 120 ? 4 : 8
            let stack = regularStack - (144 - rulerLength)
            horizontalActions = height < headerHeight + stack
            let leftHeight = stack - (horizontalActions ? auxiliarySize + 4 : 0)
            let rightHeight = max(0, instrumentHeight) + (topDiameter - 48)
                - (144 - rulerLength) - 2 + 4 + 60
            let groupHeight = max(leftHeight, rightHeight)
            let side = max(Spacing.xs, leadingSafeArea, trailingSafeArea)
            let usableWidth = max(1, width - 2 * (side + controlColumnWidth + gap))
            let horizontalHalf = CGFloat(rotated ? halfWidth : halfLength)
            let verticalHalf = CGFloat(rotated ? halfLength : halfWidth)
            let ratio = max(0.01, horizontalHalf / max(0.01, verticalHalf))
            // Portrait has a separate palette below navigation. Landscape can
            // share the navigation band; neither arrangement moves the palette
            // away from the visible rail to force it into a single header row.
            let top = palette.map { $0.sharesNavigation ? headerHeight : headerHeight + 4 + $0.height }
                ?? (rotated ? 2 * headerHeight + 38 : headerHeight)
            let availableHeight = max(1, height - top)
            let tableWidth = min(usableWidth, availableHeight * ratio)
            let tableHeight = tableWidth / ratio
            table = CGRect(x: (width - tableWidth) / 2,
                y: top + (availableHeight - tableHeight) / 2, width: tableWidth, height: tableHeight)
            let margin = CGFloat(CameraRig.rotatedFitMargin)
            stage = CGRect(x: table.midX - tableWidth * margin / 2,
                y: table.midY - tableHeight * margin / 2,
                width: tableWidth * margin, height: tableHeight * margin)
            // Centre the complete action group; clamp it within the already
            // safe-area-adjusted page. Do not reserve the bottom inset twice.
            let preferredTop = table.midY - groupHeight / 2
            let y = max(headerHeight, min(preferredTop, height - groupHeight))
            let axisDistance = controlColumnWidth / 2 + gap
            left = CGRect(x: table.minX - axisDistance - 30, y: y, width: 60, height: groupHeight)
            right = CGRect(x: table.maxX + axisDistance - 30, y: y, width: 60, height: groupHeight)
            fits = (palette?.fits ?? true) && groupHeight + headerHeight <= height
                && min(tableWidth, tableHeight) >= SpinPad.minimumExtent
                && left.minX >= side - 0.01 && right.maxX <= width - side + 0.01
        }
    }

    /// Frozen C47 vertical reservation: C51 grows the palette inside spare space,
    /// without feeding its new visual size back into table or instrument geometry.
    struct FoundationReservation {
        let diameter: CGFloat
        let targetWidth: CGFloat
        let wingWidth: CGFloat
        let twoRows: Bool
        let sharesNavigation: Bool
        let fits: Bool
        var rowHeight: CGFloat { diameter + 4 }
        var height: CGFloat { twoRows ? 2 * rowHeight + 4 : rowHeight }
        var totalWidth: CGFloat { targetWidth + 2 * (wingWidth + 4) }

        init(width: CGFloat, targetCount: Int, chineseEightBall: Bool,
             titleWidth: CGFloat, actionWidth: CGFloat, prefersSeparateRow: Bool,
             separateWidth: CGFloat? = nil) {
            let width = width.isFinite ? max(0, width) : 0
            let count = max(0, targetCount)
            let separators: CGFloat = chineseEightBall ? 10 : 0
            let tiers: [CGFloat] = [34, 30, 25]
            func targets(_ d: CGFloat) -> CGFloat { CGFloat(count) * (d + 2) + separators + 8 }
            func shared(_ d: CGFloat) -> Bool {
                targets(d) + 2 * max(titleWidth + d + 14 + 4, actionWidth + 4) <= width
            }
            let sharedDiameter = prefersSeparateRow ? nil : tiers.first(where: shared)
            let fullDiameter = tiers.first { targets($0) + 2 * ($0 + 14) <= min(width, separateWidth ?? width) }
            let selected = sharedDiameter ?? fullDiameter
            diameter = selected ?? 25
            twoRows = selected == nil
            sharesNavigation = sharedDiameter != nil
            wingWidth = diameter + 10
            // Exclude black eight from the seven aligned colour pairs.
            let gridCount = chineseEightBall ? max(0, count - 1) : count
            targetWidth = twoRows ? CGFloat((gridCount + 1) / 2) * (diameter + 2) + 8 : targets(diameter)
            fits = targetWidth + 2 * (wingWidth + 4) <= width
        }
    }

    /// C51, page-local points. Resolve against the fixed table baseline and real
    /// navigation/side obstacles; visual growth never resizes the scene.
    struct Palette {
        static let maximumDiameter: CGFloat = 36
        let diameter: CGFloat
        let twoRows: Bool
        let targetWidth: CGFloat
        let wingWidth: CGFloat
        let fits: Bool
        var rowHeight: CGFloat { diameter + 4 }
        var height: CGFloat { twoRows ? 2 * rowHeight + 4 : rowHeight }

        init(size: CGSize, sideInset: CGFloat, table: CGRect, targetCount: Int,
             chineseEightBall: Bool, obstacles: [CGRect]) {
            let count = max(0, targetCount)
            let separators: CGFloat = chineseEightBall ? 10 : 0
            func targetWidth(_ d: CGFloat, rows: Bool) -> CGFloat {
                rows ? CGFloat((max(0, count - (chineseEightBall ? 1 : 0)) + 1) / 2) * (d + 2) + 8
                    : CGFloat(count) * (d + 2) + separators + 8
            }
            func fits(_ d: CGFloat, rows: Bool) -> Bool {
                let w = targetWidth(d, rows: rows)
                let h = rows ? 2 * (d + 4) + 4 : d + 4
                // Include actual vertical hit area; neighbouring slots stay disjoint.
                let hitHeight = rows ? h : max(44, h)
                let rect = CGRect(x: table.midX - w / 2,
                    y: table.minY - h / 2 - hitHeight / 2, width: w, height: hitHeight)
                let wing = CGRect(x: rect.maxX + 4, y: table.minY - h / 2 - (d + 4) / 2,
                    width: d + 10, height: d + 4)
                let bounds = rows && chineseEightBall ? rect.union(wing) : rect
                return bounds.minX >= sideInset && bounds.maxX <= size.width - sideInset
                    && bounds.minY >= 0 && !obstacles.contains { $0.insetBy(dx: -2, dy: 0).intersects(bounds) }
            }
            let tiers: [CGFloat] = [Self.maximumDiameter, 34, 30, 25]
            let single = tiers.first { fits($0, rows: false) }
            // Orientation is a product constraint, not a device-name breakpoint.
            let double = single == nil && size.height > size.width
                ? tiers.first { fits($0, rows: true) } : nil
            twoRows = double != nil
            diameter = single ?? double ?? 25
            self.targetWidth = targetWidth(diameter, rows: twoRows)
            wingWidth = twoRows && chineseEightBall ? diameter + 10 : 0
            self.fits = single != nil || double != nil
        }
    }

    /// Four camera actions stay left of the power column and use its measured full shell centre.
    struct CameraLane {
        let offset: CGSize
        let isOuter = false
        init(column: CGRect, rulerHeight: CGFloat, powerShell: CGRect, stackHeight: CGFloat) {
            let gap: CGFloat = rulerHeight < 144 ? 4 : 8
            offset = CGSize(width: column.width / 2 - 22 - gap - 44,
                             height: powerShell.midY - stackHeight / 2)
        }
    }

    struct Header {
        enum Style: Equatable {
            case regular, compact
            var diameter: CGFloat { self == .regular ? regularBallDiameter : compactBallDiameter }
            var modeSegmentWidth: CGFloat { self == .regular ? 44 : 30 }
            var titleShift: CGFloat { self == .regular ? 12 : 2 }
        }
        enum Presentation: Equatable { case fullRow, scrolling, limited }

        /// Two points is the existing minimum separation between ball faces.
        /// Keep at least this much between distinct interactive header groups.
        static let minimumGap: CGFloat = 2
        static let overflowSlotWidth: CGFloat = 44
        /// The regular baseline offers 58pt to its 60pt title. Preserve that
        /// existing 2pt fit, but never buy further capacity by shrinking text.
        static let baselineTitleFitAllowance: CGFloat = 2
        let style: Style
        let presentation: Presentation
        let titleShift: CGFloat
        let paletteWidth: CGFloat
        let leadingWidth: CGFloat
        let targetViewportWidth: CGFloat
        let showsTitle: Bool

        static func paletteWidth(targetCount: Int, separators: CGFloat, style: Style) -> CGFloat {
            // Cue + targets + noninteractive mirrored cue wing, including shell padding.
            CGFloat(max(0, targetCount) + 2) * (style.diameter + 2) + 8 * Spacing.xs + separators
        }

        static func minimumWidth(targetCount: Int, separators: CGFloat, style: Style,
                                 titleWidth: CGFloat, leadingAllowance: CGFloat,
                                 trailingExtension: CGFloat) -> CGFloat {
            let shift = min(style.titleShift, max(0, leadingAllowance))
            // Return hit slot is 44; its -12 title spacing is part of the baseline.
            // The cue's first hit begins 4pt inside its shell. The mirrored wing
            // is decorative, so the trailing controls may use that empty space.
            let visibleLeft = 44 - 12 + titleWidth + minimumGap - shift - Spacing.xs
            let baselineLeft = 44 - 12 + titleWidth + Spacing.xs - shift - baselineTitleFitAllowance
            let left = style == .regular ? max(visibleLeft, baselineLeft) : visibleLeft
            let rightEnvelope = 2 * style.modeSegmentWidth + 6 + 44 + 1 // capsule stroke
            let right = rightEnvelope + minimumGap - trailingExtension - (style.diameter + 2) - 16
            return paletteWidth(targetCount: targetCount, separators: separators, style: style)
                + 2 * max(left, right, 0)
        }

        init(width: CGFloat, targetCount: Int, separators: CGFloat,
             regularTitleWidth: CGFloat, compactTitleWidth: CGFloat,
             leadingAllowance: CGFloat, trailingExtension: CGFloat) {
            let availableWidth = width.isFinite ? max(0, width) : 0
            let regularFits = availableWidth >= Self.minimumWidth(targetCount: targetCount, separators: separators,
                style: .regular, titleWidth: regularTitleWidth, leadingAllowance: leadingAllowance,
                trailingExtension: trailingExtension)
            let compactFits = availableWidth >= Self.minimumWidth(targetCount: targetCount, separators: separators,
                style: .compact, titleWidth: compactTitleWidth, leadingAllowance: leadingAllowance,
                trailingExtension: trailingExtension)
            style = regularFits ? .regular : .compact
            titleShift = min(style.titleShift, max(0, leadingAllowance))
            paletteWidth = Self.paletteWidth(targetCount: targetCount, separators: separators, style: style)
            let cueWidth = Self.overflowSlotWidth + 2 * Spacing.xs
            let actionsWidth: CGFloat = 2 * Style.compact.modeSegmentWidth + 6 + 44
            let desiredLeading = 44 - 12 + compactTitleWidth + Spacing.xs
            let minimumTargets = Self.overflowSlotWidth + 2 * Spacing.xs
            let available = max(0, availableWidth + trailingExtension)
            showsTitle = available >= desiredLeading + cueWidth + actionsWidth + 3 * Spacing.xs + minimumTargets
            leadingWidth = showsTitle ? desiredLeading : 44
            targetViewportWidth = max(0, available - leadingWidth - cueWidth - actionsWidth - 3 * Spacing.xs)
            presentation = regularFits || compactFits ? .fullRow
                : (targetViewportWidth >= minimumTargets ? .scrolling : .limited)
        }
    }

    /// The complete card stays inside the unzoomed playing rect in stage-local
    /// points. Only its disc yields space; 44pt keys and the 8pt padding remain.
    /// Larger tables stop at the reference size, including iPad windows.
    struct SpinPad {
        static let minimumExtent = 3 * SpinPadLayout.keyHit + 2 * SpinPadLayout.horizontalPadding
        let extent: CGFloat
        let fits: Bool

        init(playingRect: CGRect, displayScale: CGFloat, maximumExtent: CGFloat = SpinPadLayout.fixedCardExtent) {
            let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
            let capacity = playingRect.width.isFinite && playingRect.height.isFinite
                ? max(0, min(playingRect.width, playingRect.height)) : 0
            let available = floor(capacity * scale) / scale
            fits = available >= Self.minimumExtent
            let limit = maximumExtent.isFinite && maximumExtent >= Self.minimumExtent
                ? maximumExtent : SpinPadLayout.fixedCardExtent
            extent = min(limit, max(Self.minimumExtent, available))
        }
    }

    /// Settings stay below More; the spin card stays at the reference table centre.
    /// Use the compact reference width only when the top-right panel and card
    /// occupy the same vertical band and the full width would cover the card.
    struct Panels {
        static let settingsMaximumWidth: CGFloat = 252
        static let top: CGFloat = 46
        let settingsWidth: CGFloat
        let settingsTrailingPadding: CGFloat
        let settingsLeading: CGFloat

        init(pageWidth: CGFloat, trailingSafeArea: CGFloat, spinFrame: CGRect) {
            settingsTrailingPadding = max(4, trailingSafeArea)
            let right = max(0, pageWidth - settingsTrailingPadding)
            let fullLeft = right - Self.settingsMaximumWidth
            let sharesTopBand = spinFrame.minY < Self.top + 108 && spinFrame.maxY > Self.top
            let compact = sharesTopBand && fullLeft < spinFrame.maxX
            settingsWidth = min(compact ? 202 : Self.settingsMaximumWidth,
                                max(44, pageWidth - 2 * settingsTrailingPadding))
            settingsLeading = right - settingsWidth
        }

        /// Reserve the visible strike action; long content scrolls within this height.
        func settingsHeight(pageHeight: CGFloat, strikeFrame: CGRect?) -> CGFloat {
            let available = max(0, pageHeight - Self.top - 8)
            guard let strikeFrame, !strikeFrame.isNull, !strikeFrame.isInfinite,
                  strikeFrame.width > 0, strikeFrame.height > 0,
                  strikeFrame.minX < settingsLeading + settingsWidth,
                  strikeFrame.maxX > settingsLeading else { return available }
            return min(available, max(0, strikeFrame.minY - Self.top - 8))
        }
    }

    struct Container {
        let headerShift: CGFloat
        let sideInset: CGFloat
        let stageSize: CGSize

        /// Input is the SwiftUI content proposal, not the entire screen/window.
        /// stageSize is stage-local pt; the renderer still consumes measured
        /// global stage bounds so safe area and the visual lift are applied once.
        init(size: CGSize, trailingSafeArea: CGFloat) {
            headerShift = min(headerTrailingExtension, max(0, trailingSafeArea))
            sideInset = max(0, cameraLaneWidth - trailingSafeArea)
            let width = size.width - 2 * controlColumnWidth - 4 * Spacing.xs - 2 * sideInset
            stageSize = CGSize(width: max(width, 1), height: max(size.height - headerHeight, 1))
        }
    }
}
