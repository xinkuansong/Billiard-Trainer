import SceneKit
import UIKit

/// 把一条 Drill 渲染成「USDZ 球桌 2D 顶视」缩略图（离屏，零交互）。
///
/// 用途：内容管线离线烘焙缩略图 PNG（运行时零成本）。与角度页同一套 `AngleTrainingScene`
/// （`TaiQiuZhuo.usdz` 台呢 + 抽取的球节点 + plain 光照），切到正交顶视相机，按 drill 摆
/// 母球/目标球，**用物理引擎 `ShotPredictor` 真算轨迹**（含减速/吃库/分离角），用
/// `SCNRenderer` 离屏快照成图。物理不可行时退回手画 `DrillAnimation` 折线。
///
/// ⚠️ 不要在可滚动列表里逐卡实时调用——`AngleTrainingScene.setupScene()` 每次都从磁盘
/// 解析 USDZ + 克隆节点，开销很大。仅用于离线烘焙或单个详情场景。
enum DrillThumbnailRenderer {

    // 进球线随目标球球色（缩略图目标球为黑 8 → 亮灰，ADR-P11-12）；低分辨率用紧凑线宽。
    private static let cueColor = TrajectoryStyle.aimColor
    private static let targetColor = TrajectoryStyle.potColor(for: "_8")

    /// 渲染缩略图。`size` 为点尺寸（2:1 横向最佳），`scale` 为像素倍率。
    @MainActor
    static func render(drill: DrillContent,
                       size: CGSize = CGSize(width: 320, height: 160),
                       scale: CGFloat = 2,
                       ballScale: Float = 1.8,
                       device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> UIImage? {
        guard let device else { return nil }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil else { return nil }

        let surfaceY = scene.surfaceY
        let animation = drill.animation

        // 优先物理引擎真算轨迹；不可行才退回手画折线。
        let input = DrillShotResolver.shotInput(for: drill, surfaceY: surfaceY)
        let prediction = input.map { ShotPredictor.predict($0) }

        // 摆球：母球白、目标球用 8 号（黑）。起点取物理入参（若有），否则取 animation。
        let cueScene = input?.cueBall ?? toScene(animation.cueBall.start, surfaceY: surfaceY)
        let targetScene = input?.targetBall ?? toScene(animation.targetBall.start, surfaceY: surfaceY)
        scene.applyBallLayout(cueBallPosition: cueScene, targetBallNumber: 8, targetPosition: targetScene)
        // 缩略图烘焙需可复现：钉死母球单位姿态，避免随机朝向造成像素漂移。
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation, apply: true)
        scene.hideCueStick()

        // 真实 USDZ 球相对台面偏小、缩略图里不醒目 → 放大球节点（顶视下只影响视觉大小）。
        enlarge(scene.cueBallNode, by: ballScale)
        scene.targetBallNodes.forEach { enlarge($0, by: ballScale) }

        // 轨迹折线（目标球橙、母球白），略抬离台呢避免 z-fighting。
        let lift = surfaceY + AngleSceneCalculator.ballRadius * 0.5
        if let pred = prediction, pred.feasible, pred.cuePath.count >= 2 {
            drawScenePolyline(in: scene, points: pred.objectPath, color: targetColor, y: lift)
            drawScenePolyline(in: scene, points: pred.cuePath, color: cueColor, y: lift)
        } else {
            drawPath(in: scene, start: animation.targetBall.start, path: animation.targetBall.path,
                     color: targetColor, surfaceY: surfaceY)
            drawPath(in: scene, start: animation.cueBall.start, path: animation.cueBall.path,
                     color: cueColor, surfaceY: surfaceY)
        }

        // 顶视正交相机：长轴(X)横向，正好 2:1。覆盖整张外台 + 余量。
        if let rig = scene.cameraRig {
            rig.topDownOrthographicScale = 0.86
            rig.topDownPanOffset = .zero
            rig.applyTopDown2D()
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false

        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let image = renderer.snapshot(atTime: 0, with: pixelSize,
                                      antialiasingMode: .multisampling4X)
        return image
    }

    // MARK: - Helpers

    private static func toScene(_ p: CanvasPoint, surfaceY: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: surfaceY)
    }

    /// 把场景坐标折线（物理引擎输出，含起点）逐段连线，统一抬到 `y`。
    private static func drawScenePolyline(in scene: AngleTrainingScene,
                                          points: [SCNVector3], color: UIColor, y: Float) {
        guard points.count >= 2 else { return }
        let pts = points.map { lifted($0, y: y) }
        for i in 0..<(pts.count - 1) {
            _ = scene.addLine(from: pts[i], to: pts[i + 1], color: color,
                              radius: TrajectoryStyle.compactRadius)
        }
    }

    /// 把归一化路径（含可选贝塞尔曲线）采样成场景点序列并逐段连线。
    private static func drawPath(in scene: AngleTrainingScene, start: CanvasPoint,
                                path: [PathPoint], color: UIColor, surfaceY: Float) {
        guard !path.isEmpty else { return }
        let lift = AngleSceneCalculator.ballRadius * 0.5
        let y = surfaceY + lift

        var pts: [SCNVector3] = [lifted(toScene(start, surfaceY: surfaceY), y: y)]
        var prev = start
        for point in path {
            if point.isCurve, let c1 = point.cp1, let c2 = point.cp2 {
                let steps = 14
                for s in 1...steps {
                    let t = Double(s) / Double(steps)
                    let bp = cubicBezier(prev, c1, c2, point.endPoint, t)
                    pts.append(lifted(toScene(bp, surfaceY: surfaceY), y: y))
                }
            } else {
                pts.append(lifted(toScene(point.endPoint, surfaceY: surfaceY), y: y))
            }
            prev = point.endPoint
        }

        guard pts.count >= 2 else { return }
        for i in 0..<(pts.count - 1) {
            _ = scene.addLine(from: pts[i], to: pts[i + 1], color: color,
                              radius: TrajectoryStyle.compactRadius)
        }
    }

    private static func lifted(_ v: SCNVector3, y: Float) -> SCNVector3 {
        SCNVector3(v.x, y, v.z)
    }

    private static func enlarge(_ node: SCNNode?, by factor: Float) {
        guard let node, factor != 1 else { return }
        node.scale = SCNVector3(node.scale.x * factor, node.scale.y * factor, node.scale.z * factor)
    }

    private static func cubicBezier(_ p0: CanvasPoint, _ p1: CanvasPoint,
                                    _ p2: CanvasPoint, _ p3: CanvasPoint, _ t: Double) -> CanvasPoint {
        let mt = 1 - t
        let a = mt * mt * mt
        let b = 3 * mt * mt * t
        let c = 3 * mt * t * t
        let d = t * t * t
        return CanvasPoint(
            x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
        )
    }
}
