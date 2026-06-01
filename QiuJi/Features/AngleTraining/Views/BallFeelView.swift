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
        .navigationTitle("浅谈球感")
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
        BTAimTableView(style: .feltOnly) { felt in
            let d = min(felt.width, felt.height) * 0.64
            let separation = d * (1 - overlapFraction)
            BTRealisticBall(kind: .target, diameter: d, showsContactShadow: false)
                .position(x: felt.midX + separation / 2, y: felt.midY)
            BTRealisticBall(kind: .cue, diameter: d, showsContactShadow: false)
                .position(x: felt.midX - separation / 2, y: felt.midY)
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
        BTAimTableView(style: .feltOnly) { felt in
            let d = min(felt.width, felt.height) * 0.22
            let target = CGPoint(x: felt.minX + felt.width * 0.56, y: felt.minY + felt.height * 0.48)
            let cue = CGPoint(x: felt.minX + felt.width * 0.30, y: felt.minY + felt.height * 0.70)
            let pocket = CGPoint(x: felt.maxX - d * 0.5, y: felt.minY + d * 0.5)

            BTPocketMark(diameter: d * 0.9).position(pocket)

            Path { p in p.move(to: target); p.addLine(to: pocket) }
                .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.6, dash: [5, 3]))
            Path { p in p.move(to: cue); p.addLine(to: target) }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.6, dash: [5, 3]))

            Text("30°")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.black.opacity(0.4), in: Capsule())
                .position(x: target.x + 26, y: target.y - 12)

            BTRealisticBall(kind: .target, diameter: d).position(target)
            BTRealisticBall(kind: .cue, diameter: d).position(cue)
        }
    }

    private var perspectiveCanvas: some View {
        BTAimTableView(style: .feltOnly) { felt in
            // 透视压暗：近端（底部）更暗，模拟站位低视角看台面的纵深。
            LinearGradient(colors: [.clear, .black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)

            let farD = min(felt.width, felt.height) * 0.22
            let nearD = min(felt.width, felt.height) * 0.42
            let target = CGPoint(x: felt.minX + felt.width * 0.52, y: felt.minY + felt.height * 0.34)
            let cue = CGPoint(x: felt.minX + felt.width * 0.46, y: felt.minY + felt.height * 0.74)

            BTRealisticBall(kind: .target, diameter: farD, showsContactShadow: false).position(target)
            BTRealisticBall(kind: .cue, diameter: nearD).position(cue)

            Text("30°")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.black.opacity(0.4), in: Capsule())
                .position(x: target.x + 24, y: target.y - 6)
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
