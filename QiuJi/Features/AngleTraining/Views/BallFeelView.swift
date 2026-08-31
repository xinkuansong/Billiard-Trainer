import SwiftUI
import SceneKit

/// 浅谈球感（v14 B3：文档学页壳 + 保留 P2.1 全宽出血布局）。
struct BallFeelView: View {
    var body: some View {
        ScrollView {
            // P2.1（问题集合 v3）：水平边距由各分节自管——视角差异节全宽出血
            //（2D 图延伸至屏幕宽度），其余分节保持页级 lg 边距。
            VStack(spacing: Spacing.xxl) {
                whatIsBallFeelSection
                    .padding(.horizontal, Spacing.lg)
                visualAnchorsSection
                    .padding(.horizontal, Spacing.lg)
                trainingAdviceSection
                    .padding(.horizontal, Spacing.lg)
                perspectiveDifferenceSection
                // 学→练导流（T-P18-51）：厚度锚点学完 → 真台俯视练几何判断。大卡 1≤2。
                PracticeCTA(title: "用真台验证",
                            destination: "2D 角度训练 · 在真实台面上练厚度锚点",
                            route: .sceneAiming2D)
                    .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("浅谈球感")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Section 1: What is Ball Feel

    private var whatIsBallFeelSection: some View {
        LearnDocSectionCard(title: "什么是球感") {
            HStack {
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.btPrimary)
                Spacer()
            }

            Text("大脑的综合校正器")
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .frame(maxWidth: .infinity, alignment: .center)

            LearnDocText.body("这里说的球感，特指瞄准的球感：看一眼球形，就「知道」该打哪里。几何公式给出的是理想答案，但真实击球中还有一串公式覆盖不到的偏差——球感的本质，就是大脑把这些偏差凭经验一次性校正掉。")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                feelFactor("视角误差", "俯视图里的角度和俯身瞄球时看到的角度不一样：3D 透视会压缩纵深，同一个 30° 在站位视角看起来更「厚」。")
                feelFactor("身高与站位", "身高、俯身深度、主视眼不同，看到的两球重叠关系就不同——每个人的「半球」长得不一样。")
                feelFactor("袋口容错", "袋口不是一个点而是一段区间：距离越近、角度越正容错越大。球感包含对「这杆能松多少」的判断。")
                feelFactor("出杆习惯", "每个人的出杆都有微小的系统性偏差（偏左/偏右、抬杆），老手的球感里已经内置了对自己习惯的补偿。")
                feelFactor("台呢与器材", "台呢新旧、球的洁净度影响碰撞与滚动，手感会随球房环境微调。")
            }

            LearnDocText.body("因此球感不是天分，而是大量重复后大脑内化的校正模型。本模块与后续训练页的目标，就是用「视觉锚点 + 即时误差反馈」加速这个内化过程。")
        }
    }

    private func feelFactor(_ name: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(name)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .frame(width: 76, alignment: .leading)
            Text(desc)
                .learnDocBodyStyle()
        }
    }

    // MARK: - Section 2: Visual Anchors

    private var visualAnchorsSection: some View {
        LearnDocSectionCard(title: "从母球看过去") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                ballOverlapCard(
                    name: AngleSceneCalculator.fullBall.name,
                    angle: "0°",
                    overlapFraction: CGFloat(AngleSceneCalculator.fullBall.overlap)
                )
                ballOverlapCard(
                    name: AngleSceneCalculator.halfBall.name,
                    angle: "30°",
                    overlapFraction: CGFloat(AngleSceneCalculator.halfBall.overlap)
                )
                ballOverlapCard(
                    name: AngleSceneCalculator.threeQuarterBall.name,
                    angle: String(format: "%.1f°", AngleSceneCalculator.threeQuarterBall.cutAngleDegrees),
                    overlapFraction: CGFloat(AngleSceneCalculator.threeQuarterBall.overlap)
                )
                ballOverlapCard(name: "薄球", angle: "~75°", overlapFraction: 0.08)
            }
        }
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
        // 真台特写（T-P18-46）：从母球视角的两球重叠，真实台呢底 + 真球面。
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        return BTTableFigure(orientation: .landscape,
                             closeup: (center: .zero, halfHeight: r * 1.6)) { proj in
            let d = proj.ballDiameter
            let sep = d * (1 - overlapFraction)
            BTFigureBall(number: 1, diameter: d, showsShadow: false)
                .position(x: proj.size.width / 2 + sep / 2, y: proj.size.height / 2)
            BTFigureBall(diameter: d, showsShadow: false)
                .position(x: proj.size.width / 2 - sep / 2, y: proj.size.height / 2)
        }
    }

    // MARK: - Section 3: Training Advice

    private var trainingAdviceSection: some View {
        LearnDocSectionCard(title: "训练建议") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                trainingStep(number: 1, title: "理解原理",
                            description: "学习切球角、偏移量和假想球法的基本概念。")
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
                LearnDocText.body(description)
            }
        }
    }

    // MARK: - Section 4: 2D vs 3D Perspective

    /// P2.1（问题集合 v3）+ v14 B3：全宽出血带保留——2D 图延伸至屏幕宽度；
    /// 标题/正文用与 `LearnDocSectionCard` 同级 token，**不**套节卡以免破坏出血。
    private var perspectiveDifferenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("2D 到 3D 的视角差异")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.md) {
                topDownCanvas
                    .aspectRatio(Self.tableOuterAspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)
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
                    .frame(height: 130)
                    .frame(maxWidth: .infinity)
                    .clipped()
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

            LearnDocText.body("上下两图是同一杆 30° 切球：俯视图（2D）里角度一目了然；俯身到出杆高度（3D）后，透视把纵深压缩，两球的重叠关系看起来明显更「厚」。这段视角差正是训练要校正的对象——先在 2D 建立几何判断，再到 3D 视角复核同一杆球，逐步让两个视角在大脑里对上号。")
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.lg)
        .background(.btBGSecondary)
    }

    /// 球桌外框宽高比（横放，真源 = `CameraRig` 实测外框半幅）：全台取景下按此比例
    /// 设定视图宽高，球桌恰好横向占满图宽（仅留 `rotatedFitMargin` 安全余量）。
    private static let tableOuterAspect: CGFloat = 1.4055 / 0.7995

    private var topDownCanvas: some View {
        BallFeelTopDownFigure()
    }

    /// 站位视角（条 3.2 重做）：真实 SceneKit 场景从出杆高度渲染同一杆 30° 球——
    /// 与 2D 图同一世界布局、同一张桌、真实透视，替代旧简笔画。
    private var perspectiveCanvas: some View {
        Group {
            if let img = BallFeelPerspectiveRenderer.snapshot() {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
        }
    }
}

// MARK: - 站位视角真台渲染（条 3.2）

/// 离屏渲染「30° 切球」的第一人称站位视角：同 `BallFeelTopDownFigure` 的世界布局，
/// 相机放在母球后方出杆高度、看向目标球。首渲后内存缓存。
@MainActor
private enum BallFeelPerspectiveRenderer {
    static let shotLayout: (cue: CGPoint, target: CGPoint) = {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let targetW = CGPoint(x: 0.35, y: -0.10)
        let pocketW3 = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)[1]
        let pocketW = CGPoint(x: CGFloat(pocketW3.x), y: CGFloat(pocketW3.z))
        let len = hypot(pocketW.x - targetW.x, pocketW.y - targetW.y)
        let potDir = CGPoint(x: (pocketW.x - targetW.x) / len,
                             y: (pocketW.y - targetW.y) / len)
        let ghostW = CGPoint(x: targetW.x - 2 * r * potDir.x,
                             y: targetW.y - 2 * r * potDir.y)
        let a: CGFloat = 30 * .pi / 180
        let aimDir = CGPoint(x: potDir.x * cos(a) - potDir.y * sin(a),
                             y: potDir.x * sin(a) + potDir.y * cos(a))
        let cueW = CGPoint(x: ghostW.x - aimDir.x * 0.5, y: ghostW.y - aimDir.y * 0.5)
        return (cueW, targetW)
    }()

    private static var cached: UIImage?

    static func snapshot() -> UIImage? {
        if let cached { return cached }
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        scene.background.contents = UIColor.black
        scene.hideCueStick()

        let (cueW, targetW) = shotLayout
        let sY = scene.surfaceY
        scene.applyBallLayout(
            cueBallPosition: SCNVector3(Float(cueW.x), sY, Float(cueW.y)),
            targetBallNumber: 1,
            targetPosition: SCNVector3(Float(targetW.x), sY, Float(targetW.y)))

        // 相机：母球后方 0.45m、台面上方 0.30m（≈ 俯身出杆的眼位），看向目标球。
        let dir = CGPoint(x: targetW.x - cueW.x, y: targetW.y - cueW.y)
        let dLen = max(hypot(dir.x, dir.y), 0.001)
        let u = CGPoint(x: dir.x / dLen, y: dir.y / dLen)
        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zNear = 0.01
        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(Float(cueW.x - u.x * 0.45),
                                      sY + 0.30,
                                      Float(cueW.y - u.y * 0.45))
        scene.rootNode.addChildNode(camNode)
        camNode.look(at: SCNVector3(Float(targetW.x), sY + AngleSceneCalculator.ballRadius,
                                    Float(targetW.y)))

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camNode
        renderer.autoenablesDefaultLighting = false
        let image = renderer.snapshot(atTime: 0,
                                      with: CGSize(width: 1200, height: 400),
                                      antialiasingMode: .multisampling4X)
        camNode.removeFromParentNode()
        cached = image
        return image
    }
}

// MARK: - Top-down real-table figure

/// 真台俯视对比图（T-P18-46）：真实 USDZ 台底图 + §1.2 线语言
/// （瞄准线白实线 / 进球线绑球色 / 假想球绿圈），几何按真实球径与 30° 切角解算。
private struct BallFeelTopDownFigure: View {
    private struct Layout {
        let target: CGPoint
        let pocket: CGPoint
        let ghost: CGPoint
        let cue: CGPoint
        let d: CGFloat
    }

    var body: some View {
        BTTableFigure(orientation: .landscape) { proj in
            let l = layout(proj)
            ZStack {
                Path { p in p.move(to: l.target); p.addLine(to: l.pocket) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))
                Path { p in p.move(to: l.cue); p.addLine(to: l.ghost) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                BTGhostCircle(diameter: l.d).position(l.ghost)
                BTFigureBall(number: 1, diameter: l.d).position(l.target)
                BTFigureBall(diameter: l.d).position(l.cue)

                BTFigureTag(text: "30°")
                    .position(x: l.ghost.x + l.d * 1.3, y: l.ghost.y - l.d * 0.9)
            }
        }
    }

    private func layout(_ proj: TableFigureProjection) -> Layout {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let targetW = CGPoint(x: 0.35, y: -0.10)
        let pocketW3 = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)[1]
        let pocketW = CGPoint(x: CGFloat(pocketW3.x), y: CGFloat(pocketW3.z))
        let len = hypot(pocketW.x - targetW.x, pocketW.y - targetW.y)
        let potDir = CGPoint(x: (pocketW.x - targetW.x) / len,
                             y: (pocketW.y - targetW.y) / len)
        let ghostW = CGPoint(x: targetW.x - 2 * r * potDir.x,
                             y: targetW.y - 2 * r * potDir.y)
        // 30° 切角的母球位（进球方向绕假想球旋 30°）。
        let a: CGFloat = 30 * .pi / 180
        let cosA: CGFloat = cos(a)
        let sinA: CGFloat = sin(a)
        let aimDir = CGPoint(x: potDir.x * cosA - potDir.y * sinA,
                             y: potDir.x * sinA + potDir.y * cosA)
        let cueW = CGPoint(x: ghostW.x - aimDir.x * 0.5, y: ghostW.y - aimDir.y * 0.5)

        return Layout(target: proj.point(x: targetW.x, z: targetW.y),
                      pocket: proj.point(x: pocketW.x, z: pocketW.y),
                      ghost: proj.point(x: ghostW.x, z: ghostW.y),
                      cue: proj.point(x: cueW.x, z: cueW.y),
                      d: proj.ballDiameter)
    }
}

#Preview("Light") {
    NavigationStack { BallFeelView() }
}

#Preview("Dark") {
    NavigationStack { BallFeelView() }
        .preferredColorScheme(.dark)
}
