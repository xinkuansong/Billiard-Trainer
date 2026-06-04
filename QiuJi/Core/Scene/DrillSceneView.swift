import SwiftUI
import SceneKit

/// 详情页用的 live「USDZ 球桌 2D 顶视」场景：与角度页同一套 `AngleTrainingScene`
/// （`TaiQiuZhuo.usdz` 台呢 + 抽取球节点 + plain 光照），切正交顶视相机，按 drill 摆球、
/// 画烘焙轨迹，并可一键回放母球/目标球沿轨迹运动。非交互（无拖球/点袋）。
///
/// ⚠️ 仅用于单个全屏/横幅场景。列表缩略图请用离线烘焙 PNG（`BTBakedDrillTable`）。
@MainActor
final class DrillSceneController: ObservableObject {
    let scene = AngleTrainingScene()
    var cameraMode: AngleTrainingScene.CameraMode = .topDown2D

    private var didSetup = false
    private var animation: DrillAnimation?
    private var cueStart = SCNVector3Zero
    private var targetStart = SCNVector3Zero
    private var trajectoryNodes: [SCNNode] = []

    private let ballScale: Float = 1.3
    private let orthoScale: Double = 0.86

    func setup(animation: DrillAnimation) {
        guard !didSetup else { return }
        didSetup = true
        self.animation = animation

        scene.setupScene(enhancedRendering: false)
        let surfaceY = scene.surfaceY
        let cue = point(animation.cueBall.start, surfaceY: surfaceY)
        let target = point(animation.targetBall.start, surfaceY: surfaceY)
        scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: 8, targetPosition: target)
        scene.hideCueStick()
        enlarge(scene.cueBallNode)
        scene.targetBallNodes.forEach(enlarge)

        cueStart = scene.cueBallNode?.position ?? cue
        targetStart = scene.targetBallNodes.first?.position ?? target

        drawTrajectory(animation)

        scene.cameraRig?.topDownOrthographicScale = orthoScale
        scene.cameraRig?.topDownPanOffset = .zero
        scene.cameraRig?.applyTopDown2D()
    }

    func play() {
        guard let animation, let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        cue.removeAllActions(); target.removeAllActions()
        cue.position = cueStart
        target.position = targetStart

        let surfaceY = scene.surfaceY
        let yCue = cueStart.y
        let yTgt = targetStart.y
        let total: TimeInterval = 1.4

        let cuePts = scenePoints(start: animation.cueBall.start, path: animation.cueBall.path, surfaceY: surfaceY, y: yCue)
        let tgtPts = scenePoints(start: animation.targetBall.start, path: animation.targetBall.path, surfaceY: surfaceY, y: yTgt)

        if let cueAction = moveAction(points: cuePts, duration: total * 0.9, initialDelay: 0) {
            cue.runAction(cueAction)
        }
        // 目标球在母球接近接触点后才启动（先击后进的节奏）。
        if let tgtAction = moveAction(points: tgtPts, duration: total * 0.5, initialDelay: total * 0.38) {
            target.runAction(tgtAction)
        }
    }

    // MARK: - Trajectory

    private func drawTrajectory(_ animation: DrillAnimation) {
        clearTrajectory()
        let surfaceY = scene.surfaceY
        let y = surfaceY + AngleSceneCalculator.ballRadius * 0.5
        addPolyline(scenePoints(start: animation.targetBall.start, path: animation.targetBall.path, surfaceY: surfaceY, y: y),
                    color: UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.95))
        addPolyline(scenePoints(start: animation.cueBall.start, path: animation.cueBall.path, surfaceY: surfaceY, y: y),
                    color: UIColor.white.withAlphaComponent(0.95))
    }

    private func addPolyline(_ pts: [SCNVector3], color: UIColor) {
        guard pts.count >= 2 else { return }
        for i in 0..<(pts.count - 1) {
            trajectoryNodes.append(scene.addLine(from: pts[i], to: pts[i + 1], color: color, radius: 0.005))
        }
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
    }

    // MARK: - Geometry helpers

    private func point(_ p: CanvasPoint, surfaceY: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: surfaceY)
    }

    private func scenePoints(start: CanvasPoint, path: [PathPoint], surfaceY: Float, y: Float) -> [SCNVector3] {
        func at(_ c: CanvasPoint) -> SCNVector3 {
            let v = point(c, surfaceY: surfaceY)
            return SCNVector3(v.x, y, v.z)
        }
        var pts: [SCNVector3] = [at(start)]
        var prev = start
        for p in path {
            if p.isCurve, let c1 = p.cp1, let c2 = p.cp2 {
                for s in 1...14 {
                    let t = Double(s) / 14
                    pts.append(at(cubicBezier(prev, c1, c2, p.endPoint, t)))
                }
            } else {
                pts.append(at(p.endPoint))
            }
            prev = p.endPoint
        }
        return pts
    }

    private func moveAction(points: [SCNVector3], duration: TimeInterval, initialDelay: TimeInterval) -> SCNAction? {
        guard points.count >= 2 else { return nil }
        var lengths: [Double] = []
        var total = 0.0
        for i in 1..<points.count {
            let d = distance(points[i - 1], points[i])
            lengths.append(d); total += d
        }
        guard total > 0.0001 else { return nil }

        var seq: [SCNAction] = []
        if initialDelay > 0 { seq.append(.wait(duration: initialDelay)) }
        for i in 1..<points.count {
            let segDur = duration * (lengths[i - 1] / total)
            let m = SCNAction.move(to: points[i], duration: segDur)
            m.timingMode = .linear
            seq.append(m)
        }
        return .sequence(seq)
    }

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x), dz = Double(a.z - b.z)
        return (dx * dx + dz * dz).squareRoot()
    }

    private func enlarge(_ node: SCNNode?) {
        guard let node else { return }
        node.scale = SCNVector3(node.scale.x * ballScale, node.scale.y * ballScale, node.scale.z * ballScale)
    }

    private func cubicBezier(_ p0: CanvasPoint, _ p1: CanvasPoint,
                             _ p2: CanvasPoint, _ p3: CanvasPoint, _ t: Double) -> CanvasPoint {
        let mt = 1 - t
        let a = mt * mt * mt, b = 3 * mt * mt * t, c = 3 * mt * t * t, d = t * t * t
        return CanvasPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                           y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }
}

/// 详情页 live USDZ 2D 顶视球桌（2:1）+ 回放按钮。
struct DrillSceneView: View {
    let animation: DrillAnimation
    @StateObject private var controller = DrillSceneController()
    @State private var didAppear = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AngleSceneView(
                scene: controller.scene,
                cameraMode: .constant(controller.cameraMode),
                interactionMode: .none
            )
            .aspectRatio(2.0, contentMode: .fit)

            Button {
                controller.play()
            } label: {
                Image(systemName: "play.fill")
                    .font(.btFootnote14)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            controller.setup(animation: animation)
        }
    }
}
