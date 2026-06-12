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
                          orientation: SCNVector3 = defaultOrientation,
                          device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> [String: UIImage] {
        guard let device else { return [:] }
        let source = AngleTrainingScene()
        source.setupScene(enhancedRendering: false)

        var out: [String: UIImage] = [:]
        for key in PositionPlayBall.allKeys {
            guard let ball = source.allBallNodes[key] else { continue }
            if let img = render(ball: ball, size: size, scale: scale,
                                orientation: orientation, device: device) {
                out[key] = img
            }
        }
        return out
    }

    /// 默认球姿态（欧拉角，弧度）：由 `BallFaceRenderDiagTests` 姿态矩阵出图人工核对选定
    /// （rx=π、rz=π/2 时 _1/_8/_9 号码面均朝向俯视相机；各球贴图布局略有差异，取整体最优）。
    static let defaultOrientation = SCNVector3(Float.pi, 0, Float.pi / 2)

    // MARK: - Single ball

    static func render(ball: SCNNode, size: CGFloat, scale: CGFloat,
                       orientation: SCNVector3 = defaultOrientation,
                       device: MTLDevice) -> UIImage? {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let clone = ball.clone()
        clone.position = SCNVector3Zero
        clone.eulerAngles = orientation
        clone.isHidden = false
        clone.opacity = 1
        scene.rootNode.addChildNode(clone)

        // 缩略图用**无光照**直出 USDZ 漫反射纹理：离屏场景没有全套打光/IBL，
        // PBR 材质在单 omni 下高光过曝成「白月牙」、纹理全失。clone 后改材质不影响场景原球。
        unlitMaterials(in: clone)

        // USDZ 球节点 pivot ≠ 球心（`AngleTrainingScene.visualCenter` 即为此而生）：把节点原点
        // 摆到原点后，网格实际中心可能偏在取景框外 → 必须按克隆体**真实包围球**取景：
        // boundingSphere 在节点自身坐标系（含子节点变换），转换到场景系后得到真实球心；
        // 半径同样取自包围球（含节点自身 scale），不再假设等于 `ballRadius`。
        let (localCenter, localRadius) = clone.boundingSphere
        let center = clone.convertPosition(localCenter, to: nil)
        let maxScale = max(abs(clone.scale.x), max(abs(clone.scale.y), abs(clone.scale.z)), 1e-6)
        let r = Float(localRadius) * maxScale
        guard r > 1e-6 else { return nil }

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = Double(r) * 1.18
        // 相机距球仅 ~10R，远小于默认 zNear=1.0 会把球整颗裁掉 → 必须放小近裁剪面。
        cam.zNear = 0.001
        cam.zFar = Double(r) * 40
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(center.x, center.y + r * 10, center.z)
        camNode.look(at: center, up: SCNVector3(0, 0, -1), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(camNode)

        let omni = SCNLight()
        omni.type = .omni
        omni.intensity = 1000
        let omniNode = SCNNode()
        omniNode.light = omni
        omniNode.position = SCNVector3(center.x + r * 6, center.y + r * 12, center.z + r * 6)
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

    /// 递归把节点树材质改为无光照（保留漫反射纹理）。
    private static func unlitMaterials(in node: SCNNode) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                material.lightingModel = .constant
            }
        }
        for child in node.childNodes { unlitMaterials(in: child) }
    }
}
