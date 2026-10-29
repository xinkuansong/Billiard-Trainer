import SwiftUI
import SceneKit

/// 浅谈凭感觉瞄准：保留厚薄参照与全宽视角对照，落到可核对的练习。
struct BallFeelView: View {
    var body: some View {
        ScrollView {
            // P2.1（问题集合 v3）：水平边距由各分节自管——视角差异节全宽出血
            //（2D 图延伸至屏幕宽度），其余分节保持页级 lg 边距。
            VStack(spacing: Spacing.xxl) {
                whatIsBallFeelSection
                    .padding(.horizontal, Spacing.lg).learnDocumentWidth()
                visualAnchorsSection
                    .padding(.horizontal, Spacing.lg).learnDocumentWidth()
                correctionExperienceSection
                    .padding(.horizontal, Spacing.lg).learnDocumentWidth()
                perspectiveDifferenceSection
                trainingAdviceSection
                    .padding(.horizontal, Spacing.lg).learnDocumentWidth()
                // 学→练导流（T-P18-51）：厚度锚点学完 → 真台俯视练几何判断。大卡 1≤2。
                PracticeCTA(title: "用真台验证",
                            destination: "2D 角度训练 · 在真实台面上练厚度锚点",
                            route: .sceneAiming2D)
                    .padding(.horizontal, Spacing.lg).learnDocumentWidth()
            }
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .learnReadingNavigation(title: "浅谈凭感觉瞄准")
    }

    // MARK: - Section 1: What is Ball Feel

    private var whatIsBallFeelSection: some View {
        LearnDocSectionCard(title: "一句「凭感觉」，省略了什么") {
            HStack {
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.btPrimary)
                Spacer()
            }

            LearnDocText.body("问一位打球熟练的人「这一杆怎么瞄」，你可能得到一句很简单的回答：「凭感觉。」他看一眼球形，俯身、运杆，便把球打了出去。自己照着试，却总觉得差一点：有时能进，有时不能，换个位置就更没把握了。")
            LearnDocText.body("这句「凭感觉」省略了很多东西。眼前的厚薄关系是否熟悉，站到出杆位置后该看哪里，这种力度和杆法是否需要修正，都可能包含在那个很快的判断里。球员未必每次都把它们逐项想一遍，但以往打过的球、做过的调整，已经成了判断的参照。")
            LearnDocText.body("我们要练的，就是让这种判断逐渐可靠起来。后面的瞄准原理、瞄准方法、瞄准修正，以及旋转与加塞，都能帮助你理解和积累这份经验。")
        }
    }

    private var correctionExperienceSection: some View {
        LearnDocSectionCard(title: "熟悉的感觉，也包含修正") {
            LearnDocText.body("基本的几何瞄准给了你一个起点。实际击球时，球与球之间的摩擦可能改变目标球的离开方向；加左右塞时，还会涉及母球的挤偏和弧线。这些影响，会让实际需要的瞄准与最初的几何参照出现差别。")
            LearnDocText.body("因此，熟悉一个球形，还要知道自己熟悉的是哪一种打法。同样的位置，原先用一种力度打得很有把握，为了走下一颗换了力度或加了塞，原来的瞄准感觉就未必能直接照用。")
            LearnDocText.body("「瞄准修正」会解释这些偏差从哪里来，「旋转与加塞」则帮助你理解打点、旋转与母球运动的联系。学这些内容，是为了在换打法时知道应该留意什么。至于具体需要怎样调整，还要通过相应的练习去认识，不能把一个固定的让点用在所有球上。")
            LearnDocText.body("换了球桌、球的清洁程度或器材，原先熟悉的结果也可能变化。袋口容许的偏差有大有小，偶尔进一颗球，还不足以说明判断已经稳定。出杆若总偏向一侧，也应先检查动作，不要把迁就偏差当成必须保留的感觉。")
            LearnDocText.body("练得熟了，你可能看见这一类球，就知道用这套打法该怎样瞄。这个快速判断里，既有对厚薄的辨认，也有已经熟悉的修正经验。")
        }
    }

    // MARK: - Section 2: Visual Anchors

    private var visualAnchorsSection: some View {
        LearnDocSectionCard(title: "感觉需要有参照") {
            LearnDocText.body("刚接触一种球形时，直接问自己「感觉该瞄哪里」，往往很难得到明确的答案。先找清目标球的进球方向，再判断母球应该怎样碰上它，才有可以核对的依据。「瞄准原理」中的进球线、接触点和假想球，就是用来理解这层关系的。")
            LearnDocText.body("例如，一种厚薄关系练熟以后，再遇到相近的球形，你就可以比较：这一杆比熟悉的球厚一些，还是薄一些？下面是沿瞄准方向观察时的等比例重叠示意，可作为最初的参照；真实站位下的远近和透视，还需要另外熟悉。")
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
                ballOverlapCard(name: "薄球", angle: "75°", overlapFraction: CGFloat(1 - sin(75.0 * .pi / 180)))
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
                .foregroundStyle(.btText)
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
        LearnDocSectionCard(title: "怎样练到凭感觉也能瞄准") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                trainingStep(number: 1, title: "先把一类球练清楚",
                            description: "选一个容易重摆、自己能够稳定出杆的球形，用一种熟悉的打法练。每杆先想清楚瞄准方向、打点和力度，观察站着与俯身时各自看到的球形，再完成击球。尽量保持观察位置和打法一致，才便于比较前后两杆的判断。")
                trainingStep(number: 2, title: "看结果，也检查这一杆怎么打的",
                            description: "除了看进没进，也要看目标球实际走向哪里，以及这一杆有没有按原来的打算打出去。一次没进，不能立即认定瞄准点错了；对线、出杆和打点偏差都值得检查。先弄清楚偏差可能出在哪里，再有针对性地调整，避免每打一杆就另换一个瞄法。")
                trainingStep(number: 3, title: "先凭感觉选，再用方法核对",
                            description: "对这个球形逐渐有把握后，可以在出杆前先凭第一感觉选一个方向，再用学过的方法核对。两者不一致时，停下来看看差在哪里。这样练，你既在尝试独立判断，也保留了检查判断的依据。")
                trainingStep(number: 4, title: "逐渐改变球形和打法",
                            description: "把球摆得稍厚、稍薄一些，或者改变球距，比较新球形与熟悉球形的差别。然后再练同一球形下不同力度、不同杆法的瞄准。每次先弄清改变了什么，预想是否需要修正，再用实际结果核对；把球形和打法一起记住。")
                trainingStep(number: 5, title: "把练过的球混在一起",
                            description: "换顺序、换位置，先自行判断，拿不准时再回到方法上检查。混合练习能帮助你发现：哪些球已经能认出来，哪些只是连续练习时暂时打顺了。")
            }
            LearnDocText.body("在 App 中，可以先用几何练习和 2D 球台看清球位关系，再到 3D 视角辨认同一杆球。回到真实球桌后，还要把观察、出杆和击球结果连起来核对。")
            LearnDocText.body("从每杆都要有意识地找参照，到看到熟悉球形就能较快确定瞄准方向，中间靠的是一次次「先判断、再击球、再核对」的积累。随着你熟悉的球形和打法越来越多，需要临时推想的步骤就会越来越少。凭感觉瞄准，也就在这个过程中逐渐形成了。")
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

            LearnDocText.body("上下两图是同一杆 30° 切球。俯视时容易看清两条线的夹角；到了出杆位置，看到的是带有远近、遮挡的球形。球位没有变，画面却变了。观察位置和俯身高度也会影响你看到的样子，因此不能把一张重叠示意直接当成每个人眼前的画面。先在 2D 看懂关系，再到 3D 辨认同一杆球；「瞄准方法」会进一步介绍实际瞄准时可用的参照。")
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
enum BallFeelPerspectiveRenderer {
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
    static func resetCache() { cached = nil }

    static func snapshot() -> UIImage? {
        if let cached { return cached }
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let scene = AngleTrainingScene()
        // Offline still with its own camera; keep the plain pipeline (ADR-P5-01).
        scene.setupScene(recipe: .plainLegacy)
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
/// （瞄准线白实线 / 进球线绑球色 / 假想球白色虚线圈），几何按真实球径与 30° 切角解算。
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
