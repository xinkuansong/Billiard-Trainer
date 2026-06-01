import SwiftUI

struct AimingPrincipleView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                cutAngleSection
                coreFormulaSection
                ghostBallSection
                thicknessSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("瞄准原理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Section 1: What is Cut Angle

    private var cutAngleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("什么是切球角")
                .font(.btTitle)
                .foregroundStyle(.btText)

            cutAngleCanvas
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            Text("切球角是指母球击球方向与目标球进球方向之间的夹角。范围：0° 到 90°。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var cutAngleCanvas: some View {
        BTAimTableView(style: .feltOnly) { felt in
            AimingFigure(felt: felt)
        }
    }

    // MARK: - Section 2: Core Formula

    private var coreFormulaSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("核心公式")
                .font(.btTitle)
                .foregroundStyle(.btText)

            HStack {
                Spacer()
                Text("d = 2R × sin(α)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.btPrimaryMuted)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                formulaRow("d", "横移量（幽灵球中心偏移目标球中心的距离）")
                formulaRow("R", "球半径（中八 28.575mm）")
                formulaRow("α", "切球角（0°–90°）")
                formulaRow("d/R", "= 2sin(α)，无量纲比")
            }

            Divider()

            formulaExampleCanvas
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            Text("30° 示例：sin(30°) = 0.5，d = 2R × 0.5 = R，即幽灵球中心偏移一个球半径。")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)

            Divider()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("派生公式")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Text("接触点偏移 = R × sin(α)")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.btTextSecondary)
                Text("仅描述目标球表面接触点位置，不是瞄准主公式。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func formulaRow(_ symbol: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(symbol)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.btPrimary)
                .frame(width: 30, alignment: .trailing)
            Text(desc)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private var formulaExampleCanvas: some View {
        BTAimTableView(style: .feltOnly) { felt in
            FormulaFigure(felt: felt)
        }
    }

    // MARK: - Section 3: Ghost Ball Method

    private var ghostBallSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("假想球法（Ghost Ball）")
                .font(.btTitle)
                .foregroundStyle(.btText)

            ghostBallStep(number: 1, title: "确定进球线",
                         description: "连接目标球中心与袋口中心点。")

            ghostBallStep(number: 2, title: "放置假想球",
                         description: "在进球线反方向放置一个与母球等大的圆。幽灵球中心 = 目标球中心 − 2R × 进球方向。")

            ghostBallStep(number: 3, title: "瞄准球心",
                         description: "母球只需朝向假想球的圆心方向出杆即可。接触瞬间，白球与目标球连心线与进球线重合。")
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func ghostBallStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("步骤 \(number)")
                .font(.btCaption2)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btPrimary)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(description)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
        }
    }

    // MARK: - Section 4: Thickness Concept

    private var thicknessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("厚薄球概念")
                .font(.btTitle)
                .foregroundStyle(.btText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                thicknessCard(name: "全球", angle: "0°", offset: "0%", dOverR: "0", overlapFraction: 1.0)
                thicknessCard(name: "3/4 球", angle: "14.5°", offset: "25%", dOverR: "0.50", overlapFraction: 0.75)
                thicknessCard(name: "半球", angle: "30°", offset: "50%", dOverR: "1.0", overlapFraction: 0.5)
                thicknessCard(name: "极薄球", angle: "90°", offset: "100%", dOverR: "2.0", overlapFraction: 0.0)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func thicknessCard(name: String, angle: String, offset: String, dOverR: String, overlapFraction: CGFloat) -> some View {
        VStack(spacing: Spacing.sm) {
            thicknessCanvas(overlapFraction: overlapFraction)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            Text(name)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            Text("\(angle) | d/R \(dOverR)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private func thicknessCanvas(overlapFraction: CGFloat) -> some View {
        BTAimTableView(style: .feltOnly) { felt in
            let d = min(felt.width, felt.height) * 0.62
            let separation = d * (1 - overlapFraction)
            // 目标球（橙）居右，白球居左错位重叠：α 越大错位越多（越"薄"）。
            BTRealisticBall(kind: .target, diameter: d, showsContactShadow: false)
                .position(x: felt.midX + separation / 2, y: felt.midY)
            BTRealisticBall(kind: .cue, diameter: d, showsContactShadow: false)
                .position(x: felt.midX - separation / 2, y: felt.midY)
        }
    }
}

// MARK: - Aiming geometry figures

/// 切球角全景：在拟真台面上画出母球 / 目标球 / 假想球 / 进球线 / 击球线 / α 弧。
private struct AimingFigure: View {
    let felt: CGRect

    var body: some View {
        let w = felt.width
        let h = felt.height
        let d = min(w, h) * 0.15
        let r = d / 2

        let target = CGPoint(x: felt.minX + w * 0.46, y: felt.minY + h * 0.52)
        let pocket = CGPoint(x: felt.maxX - d * 0.5, y: felt.minY + d * 0.5)   // 右上角袋示意
        let dir = unitVector(from: target, to: pocket)
        let ghost = CGPoint(x: target.x - 2 * r * dir.x, y: target.y - 2 * r * dir.y)
        let cue = CGPoint(x: felt.minX + w * 0.24, y: felt.minY + h * 0.86)

        let pocketAngle = atan2(pocket.y - target.y, pocket.x - target.x)
        let strikeAngle = atan2(ghost.y - target.y, ghost.x - target.x)
        let arcR = r * 1.7

        ZStack {
            BTPocketMark(diameter: d * 0.95).position(pocket)

            // 进球线：目标球 → 袋口
            Path { p in p.move(to: target); p.addLine(to: pocket) }
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))

            // 击球线：母球 → 假想球
            Path { p in p.move(to: cue); p.addLine(to: ghost) }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))

            // α 弧
            Path { p in
                p.addArc(center: target, radius: arcR,
                         startAngle: .radians(pocketAngle),
                         endAngle: .radians(strikeAngle),
                         clockwise: pocketAngle > strikeAngle)
            }
            .stroke(Color.yellow, lineWidth: 3)

            BTRealisticBall(kind: .ghost, diameter: d).position(ghost)
            BTRealisticBall(kind: .target, diameter: d).position(target)
            BTRealisticBall(kind: .cue, diameter: d).position(cue)

            tag("α", color: .yellow)
                .position(x: target.x + (arcR + 14) * cos((pocketAngle + strikeAngle) / 2),
                          y: target.y + (arcR + 14) * sin((pocketAngle + strikeAngle) / 2))
            tag("母球").position(x: cue.x, y: cue.y + r + 11)
            tag("目标球").position(x: target.x, y: target.y + r + 13)
            tag("袋口").position(x: pocket.x - 18, y: pocket.y + 16)
        }
    }

    private func tag(_ text: String, color: Color = .white) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.black.opacity(0.4), in: Capsule())
    }
}

/// d = 2R·sin(α) 的 30° 示例：目标球 + 假想球（错位一个半径），并标注横移量 d。
private struct FormulaFigure: View {
    let felt: CGRect

    var body: some View {
        let d = min(felt.width, felt.height) * 0.38
        let r = d / 2
        let cy = felt.midY - 4
        let targetX = felt.midX + r * 0.55
        let ghostX = targetX - r            // d/R = 1 → 偏移一个半径

        ZStack {
            // d 横移量标注
            Path { p in
                p.move(to: CGPoint(x: ghostX, y: cy - r - 14))
                p.addLine(to: CGPoint(x: targetX, y: cy - r - 14))
            }
            .stroke(Color.cyan, lineWidth: 1.6)

            Text("d / R = 1.0")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.cyan)
                .position(x: (ghostX + targetX) / 2, y: cy - r - 26)

            BTRealisticBall(kind: .ghost, diameter: d).position(x: ghostX, y: cy)
            BTRealisticBall(kind: .target, diameter: d).position(x: targetX, y: cy)

            Text("sin(30°) = 0.5 → d = R")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .position(x: felt.midX, y: felt.maxY - 14)
        }
    }
}

private func unitVector(from a: CGPoint, to b: CGPoint) -> CGPoint {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len = sqrt(dx * dx + dy * dy)
    guard len > 0.0001 else { return .zero }
    return CGPoint(x: dx / len, y: dy / len)
}

#Preview("Light") {
    NavigationStack { AimingPrincipleView() }
}

#Preview("Dark") {
    NavigationStack { AimingPrincipleView() }
        .preferredColorScheme(.dark)
}
