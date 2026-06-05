import SceneKit
import UIKit

/// 把 USDZ 球节点逐颗离屏渲染成「俯视球面」小图（透明背景圆形），供走位编排器球库用真实球面替代数字。
///
/// 用法：进编排台时异步 `renderAll()` 一次，结果按球键缓存到内存（运行时零成本）。
/// ⚠️ 内部会解析一次 `AngleTrainingScene`（USDZ + 克隆），开销较大，**不要**在滚动列表里逐帧调用。
enum BallFaceRenderer {

    /// 渲染全部 16 颗球（母球 + 1..15）。键与 `AngleTrainingScene.allBallNodes` 一致。
    @MainActor
    static func renderAll(size: CGFloat = 72,
                          scale: CGFloat = 3,
                          device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> [String: UIImage] {
        guard let device else { return [:] }
        let source = AngleTrainingScene()
        source.setupScene(enhancedRendering: false)

        var out: [String: UIImage] = [:]
        for key in PositionPlayBall.allKeys {
            guard let ball = source.allBallNodes[key] else { continue }
            if let img = render(ball: ball, size: size, scale: scale, device: device) {
                out[key] = img
            }
        }
        return out
    }

    // MARK: - Single ball

    private static func render(ball: SCNNode, size: CGFloat, scale: CGFloat, device: MTLDevice) -> UIImage? {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let clone = ball.clone()
        clone.position = SCNVector3Zero
        clone.eulerAngles = SCNVector3Zero
        clone.isHidden = false
        clone.opacity = 1
        scene.rootNode.addChildNode(clone)

        // 统一用球半径取景（所有球同尺寸），俯视看下去，与桌面上的视觉一致。
        let r = AngleSceneCalculator.ballRadius

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = Double(r) * 1.18
        // 相机距球仅约 0.28（场景单位/米），远小于默认 zNear=1.0 会把球整颗裁掉 → 必须放小近裁剪面。
        cam.zNear = 0.001
        cam.zFar = 100
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, r * 10, 0)
        camNode.look(at: SCNVector3Zero, up: SCNVector3(0, 0, -1), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(camNode)

        let omni = SCNLight()
        omni.type = .omni
        omni.intensity = 1000
        let omniNode = SCNNode()
        omniNode.light = omni
        omniNode.position = SCNVector3(r * 6, r * 12, r * 6)
        scene.rootNode.addChildNode(omniNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 600
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camNode
        renderer.autoenablesDefaultLighting = false

        let pixelSize = CGSize(width: size * scale, height: size * scale)
        return renderer.snapshot(atTime: 0, with: pixelSize, antialiasingMode: .multisampling4X)
    }
}
