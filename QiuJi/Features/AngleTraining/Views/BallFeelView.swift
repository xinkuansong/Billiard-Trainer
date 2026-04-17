import SwiftUI

struct BallFeelView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                whatIsBallFeelSection
                visualAnchorsSection
                trainingAdviceSection
                perspectiveDifferenceSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("浅淡球感")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Section 1: What is Ball Feel

    private var whatIsBallFeelSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("什么是球感")
                .font(.btTitle)
                .foregroundStyle(.btText)

            HStack {
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.btPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("从计算到直觉")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("球感并非某种天分，而是大脑对瞄球操作规律的内化结果。初学者需要借助几何概念和计算来确定三角函数关系，而经验丰富的球手则在直觉层面已将这些关系内化为身体的直觉反应。")
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)

                Text("这种转化意味着你不再需要在大脑中进行复杂的三角函数计算，而是看到目标球和袋的位置直觉感知偏移量。")
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)

                Text("本模块旨在帮助你通过「视觉锚点」训练，建立从角度到瞄准点直觉的桥梁，让每一次瞄球都像呼吸一样自然。")
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Section 2: Visual Anchors

    private var visualAnchorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("从母球看过去")
                .font(.btTitle)
                .foregroundStyle(.btText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                ballOverlapCard(name: "全球", angle: "0°", overlapFraction: 1.0)
                ballOverlapCard(name: "半球", angle: "30°", overlapFraction: 0.5)
                ballOverlapCard(name: "3/4 球", angle: "48.6°", overlapFraction: 0.25)
                ballOverlapCard(name: "薄球", angle: "~75°", overlapFraction: 0.08)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func ballOverlapCard(name: String, angle: String, overlapFraction: CGFloat) -> some View {
        VStack(spacing: Spacing.sm) {
            overlapCanvas(overlapFraction: overlapFraction)
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            Text(name)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)
            Text(angle)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private func overlapCanvas(overlapFraction: CGFloat) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let ballR: CGFloat = min(w, h) * 0.3
            let centerY = h / 2
            let targetX = w / 2

            let separation = ballR * 2 * (1 - overlapFraction)
            let cueX = targetX - separation

            // Target ball (orange)
            let targetRect = CGRect(x: targetX - ballR, y: centerY - ballR,
                                    width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            // Cue ball (white, semi-transparent where overlapping)
            let cueRect = CGRect(x: cueX - ballR, y: centerY - ballR,
                                 width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: cueRect), with: .color(.white.opacity(0.85)))
        }
    }

    // MARK: - Section 3: Training Advice

    private var trainingAdviceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("训练建议")
                .font(.btTitle)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                trainingStep(number: 1, title: "理解原理",
                            description: "学习切入角、偏移量和假想球法的基本概念。")
                trainingStep(number: 2, title: "几何练习",
                            description: "通过纯几何角度预测训练，建立角度数感。")
                trainingStep(number: 3, title: "2D 球台",
                            description: "在俯视球台上练习角度判断，熟悉球位关系。")
                trainingStep(number: 4, title: "3D 视角",
                            description: "切换到拟位视角，缩小训练与实战的差距。")
                trainingStep(number: 5, title: "实战应用",
                            description: "将练习中建立的记忆带到球桌前。")
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func trainingStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("\(number)")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.btPrimary)
                .clipShape(Circle())

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

    // MARK: - Section 4: 2D vs 3D Perspective

    private var perspectiveDifferenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("2D 到 3D 的视角差异")
                .font(.btTitle)
                .foregroundStyle(.btText)

            VStack(spacing: Spacing.md) {
                topDownCanvas
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                    .overlay(alignment: .bottomLeading) {
                        Text("俯视角度（2D）")
                            .font(.btCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding(Spacing.sm)
                    }

                perspectiveCanvas
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                    .overlay(alignment: .bottomLeading) {
                        Text("站位视角（3D）")
                            .font(.btCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding(Spacing.sm)
                    }
            }

            HStack {
                Spacer()
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.btPrimary)
                    Text("实战中从立姿俯视球台，球与球的重叠关系会因视角而产生偏差。使用 3D 模式练习，可以缩小训练与实战的视角差距。")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var topDownCanvas: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            let ballR: CGFloat = 14
            let targetPos = CGPoint(x: w * 0.55, y: h * 0.45)
            let cuePos = CGPoint(x: w * 0.3, y: h * 0.6)
            let pocketPos = CGPoint(x: w * 0.85, y: h * 0.2)

            // Angle arc
            _ = atan2(targetPos.y - cuePos.y, targetPos.x - cuePos.x)

            var pocketLine = Path()
            pocketLine.move(to: targetPos)
            pocketLine.addLine(to: pocketPos)
            context.stroke(pocketLine, with: .color(.white.opacity(0.5)),
                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            var strikeLine = Path()
            strikeLine.move(to: cuePos)
            strikeLine.addLine(to: targetPos)
            context.stroke(strikeLine, with: .color(.cyan.opacity(0.6)),
                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // Angle label
            context.draw(Text("30°").font(.system(size: 11, weight: .medium)).foregroundColor(.yellow),
                        at: CGPoint(x: targetPos.x + 25, y: targetPos.y - 10))

            // Balls
            let targetRect = CGRect(x: targetPos.x - ballR, y: targetPos.y - ballR,
                                    width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            let cueRect = CGRect(x: cuePos.x - ballR, y: cuePos.y - ballR,
                                 width: ballR * 2, height: ballR * 2)
            context.fill(Path(ellipseIn: cueRect), with: .color(.white))

            context.fill(Path(ellipseIn: CGRect(x: pocketPos.x - 8, y: pocketPos.y - 8, width: 16, height: 16)),
                        with: .color(.black.opacity(0.7)))
        }
    }

    private var perspectiveCanvas: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Darker green for 3D perspective feel
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btTableFelt))

            // Gradient overlay for perspective depth
            let gradient = Gradient(colors: [.black.opacity(0.4), .clear])
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(gradient,
                                              startPoint: CGPoint(x: w / 2, y: h),
                                              endPoint: CGPoint(x: w / 2, y: h * 0.3)))

            // Balls with perspective scaling
            let farBallR: CGFloat = 10
            let nearBallR: CGFloat = 18

            let targetPos = CGPoint(x: w * 0.52, y: h * 0.35)
            let cuePos = CGPoint(x: w * 0.45, y: h * 0.75)

            // Target (smaller, farther)
            let targetRect = CGRect(x: targetPos.x - farBallR, y: targetPos.y - farBallR,
                                    width: farBallR * 2, height: farBallR * 2)
            context.fill(Path(ellipseIn: targetRect), with: .color(.btBallTarget))

            // Cue (larger, closer)
            let cueRect = CGRect(x: cuePos.x - nearBallR, y: cuePos.y - nearBallR,
                                 width: nearBallR * 2, height: nearBallR * 2)
            context.fill(Path(ellipseIn: cueRect), with: .color(.white))

            context.draw(Text("30°").font(.system(size: 11, weight: .medium)).foregroundColor(.yellow),
                        at: CGPoint(x: targetPos.x + 20, y: targetPos.y - 5))
        }
    }
}

#Preview("Light") {
    NavigationStack { BallFeelView() }
}

#Preview("Dark") {
    NavigationStack { BallFeelView() }
        .preferredColorScheme(.dark)
}
