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
                .frame(height: 220)
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
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Table background
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let targetCenter = CGPoint(x: w * 0.5, y: h * 0.45)
            let pocketPos = CGPoint(x: w * 0.85, y: h * 0.15)
            let cueBallPos = CGPoint(x: w * 0.2, y: h * 0.8)
            let ballR: CGFloat = 14

            // Pocket line (target → pocket) - white dashed
            let pocketDir = normalize(CGPoint(x: pocketPos.x - targetCenter.x, y: pocketPos.y - targetCenter.y))
            let ghostCenter = CGPoint(x: targetCenter.x - 2 * ballR * pocketDir.x,
                                      y: targetCenter.y - 2 * ballR * pocketDir.y)

            var pocketLine = Path()
            pocketLine.move(to: targetCenter)
            pocketLine.addLine(to: pocketPos)
            context.stroke(pocketLine, with: .color(.white.opacity(0.7)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

            // Strike line (cue → ghost) - blue dashed
            var strikeLine = Path()
            strikeLine.move(to: cueBallPos)
            strikeLine.addLine(to: ghostCenter)
            context.stroke(strikeLine, with: .color(.cyan.opacity(0.7)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

            // Angle arc at target ball
            let pocketAngle = atan2(pocketPos.y - targetCenter.y, pocketPos.x - targetCenter.x)
            let strikeAngle = atan2(ghostCenter.y - targetCenter.y, ghostCenter.x - targetCenter.x)
            var arcPath = Path()
            arcPath.addArc(center: targetCenter, radius: 30,
                          startAngle: .radians(pocketAngle),
                          endAngle: .radians(strikeAngle),
                          clockwise: pocketAngle > strikeAngle)
            context.stroke(arcPath, with: .color(.yellow), lineWidth: 2)

            // α label
            let midAngle = (pocketAngle + strikeAngle) / 2
            let labelPos = CGPoint(x: targetCenter.x + 42 * cos(midAngle),
                                   y: targetCenter.y + 42 * sin(midAngle))
            context.draw(Text("α").font(.system(size: 14, weight: .bold)).foregroundColor(.yellow),
                        at: labelPos)

            // Ghost ball (translucent yellow)
            let ghostRect = CGRect(x: ghostCenter.x - ballR, y: ghostCenter.y - ballR,
                                   width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: ghostRect), with: .color(.yellow.opacity(0.3)))
            context.stroke(Path(ellipseIn: ghostRect), with: .color(.yellow.opacity(0.6)), lineWidth: 1)

            // Target ball (orange)
            let targetRect = CGRect(x: targetCenter.x - ballR, y: targetCenter.y - ballR,
                                    width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            // Cue ball (white)
            let cueRect = CGRect(x: cueBallPos.x - ballR, y: cueBallPos.y - ballR,
                                 width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: cueRect), with: .color(.white))

            // Pocket
            let pocketR: CGFloat = 10
            let pocketRect = CGRect(x: pocketPos.x - pocketR, y: pocketPos.y - pocketR,
                                    width: pocketR * 2, height: pocketR * 2)
            context.fill(Path(ellipseIn: pocketRect), with: .color(.black.opacity(0.8)))

            // Labels
            context.draw(Text("母球").font(.system(size: 10)).foregroundColor(.white.opacity(0.8)),
                        at: CGPoint(x: cueBallPos.x, y: cueBallPos.y + ballR + 12))
            context.draw(Text("目标球").font(.system(size: 10)).foregroundColor(.white.opacity(0.8)),
                        at: CGPoint(x: targetCenter.x, y: targetCenter.y + ballR + 12))
            context.draw(Text("袋口").font(.system(size: 10)).foregroundColor(.white.opacity(0.8)),
                        at: CGPoint(x: pocketPos.x, y: pocketPos.y + pocketR + 12))
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
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let centerX = w * 0.5
            let centerY = h * 0.5
            let ballR: CGFloat = 20

            // Target ball
            let targetRect = CGRect(x: centerX - ballR, y: centerY - ballR,
                                    width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            // Ghost ball offset by R (for 30° case, d/R = 1.0)
            let ghostX = centerX - ballR * 2
            let ghostRect = CGRect(x: ghostX - ballR, y: centerY - ballR,
                                   width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: ghostRect), with: .color(.yellow.opacity(0.3)))
            context.stroke(Path(ellipseIn: ghostRect), with: .color(.yellow.opacity(0.6)), lineWidth: 1.5)

            // d arrow
            var dLine = Path()
            dLine.move(to: CGPoint(x: centerX, y: centerY - ballR - 10))
            dLine.addLine(to: CGPoint(x: ghostX, y: centerY - ballR - 10))
            context.stroke(dLine, with: .color(.cyan), lineWidth: 1.5)

            context.draw(Text("d/R = 1.0").font(.system(size: 11, weight: .medium)).foregroundColor(.cyan),
                        at: CGPoint(x: (centerX + ghostX) / 2, y: centerY - ballR - 22))

            // Label
            context.draw(Text("sin(30°) = 0.5 → d = R").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.8)),
                        at: CGPoint(x: w * 0.5, y: h - 16))
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
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let ballR: CGFloat = min(w, h) * 0.28
            let centerY = h / 2
            let targetX = w / 2

            // Target ball (orange)
            let targetRect = CGRect(x: targetX - ballR, y: centerY - ballR,
                                    width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            // Cue/ghost ball offset by overlap
            let separation = ballR * 2 * (1 - overlapFraction)
            let ghostX = targetX - separation
            let ghostRect = CGRect(x: ghostX - ballR, y: centerY - ballR,
                                   width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: ghostRect), with: .color(.white.opacity(0.85)))
        }
    }

    // MARK: - Helpers

    private func normalize(_ p: CGPoint) -> CGPoint {
        let len = sqrt(p.x * p.x + p.y * p.y)
        guard len > 0.0001 else { return .zero }
        return CGPoint(x: p.x / len, y: p.y / len)
    }
}

#Preview("Light") {
    NavigationStack { AimingPrincipleView() }
}

#Preview("Dark") {
    NavigationStack { AimingPrincipleView() }
        .preferredColorScheme(.dark)
}
