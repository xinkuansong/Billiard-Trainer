import XCTest
import SceneKit
@testable import QiuJi

/// 一次性诊断：转储球桌模型节点层级的世界 Y 范围 + 材质透明度，定位「桌腿在 3D 下不完整」根因。
/// 不渲染，仅装载场景后遍历，秒级返回。
final class TableLegGeometryDiagTests: XCTestCase {

    @MainActor
    func test_dumpTableGeometryYRanges() {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: true)
        guard let table = scene.tableNode else {
            print("LEGDUMP no tableNode"); return
        }
        print("LEGDUMP surfaceY=\(scene.surfaceY) groundY=\(BTSceneLayout.groundLevelY)")

        var rows: [String] = []
        table.enumerateHierarchy { node, _ in
            guard let geo = node.geometry else { return }
            let (bMin, bMax) = node.boundingBox
            var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
            for c in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMin.z),
                      SCNVector3(bMin.x, bMin.y, bMax.z), SCNVector3(bMax.x, bMin.y, bMax.z),
                      SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMin.z),
                      SCNVector3(bMin.x, bMax.y, bMax.z), SCNVector3(bMax.x, bMax.y, bMax.z)] {
                let w = node.convertPosition(c, to: nil)
                lo = min(lo, w.y); hi = max(hi, w.y)
            }
            rows.append(String(format: "LEGDUMP node=%@ worldY=[%.3f..%.3f] hidden=%@ op=%.2f mats=%d",
                               node.name ?? "?", lo, hi, "\(node.isHidden)", node.opacity, geo.materials.count))
            for (i, m) in geo.materials.enumerated() {
                func desc(_ p: SCNMaterialProperty?) -> String {
                    guard let c = p?.contents else { return "nil" }
                    if let col = c as? UIColor {
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        col.getRed(&r, green: &g, blue: &b, alpha: &a)
                        return String(format: "rgb(%.2f,%.2f,%.2f)a%.2f", r, g, b, a)
                    }
                    if let n = c as? NSNumber { return "num(\(n.floatValue))" }
                    return "tex"
                }
                rows.append(String(format: "LEGMAT   [%d] name=%@ lm=%@ metal=%@ rough=%@ diff=%@ emis=%@",
                                   i, m.name ?? "?", "\(m.lightingModel.rawValue)",
                                   desc(m.metalness), desc(m.roughness),
                                   desc(m.diffuse), desc(m.emission)))
            }
        }
        // 按最低点排序，便于看清哪些节点探到地面（= 桌腿）。
        rows.sort()
        rows.forEach { print($0) }
        print("LEGDUMP total geometry nodes=\(rows.count)")

        // 同时转储 root 下的环境平面（地面 / 接地阴影），看它们是否挡腿。
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let n = node.name, n.contains("ground") else { return }
            print("LEGDUMP ENV node=\(n) pos=\(node.position) euler=\(node.eulerAngles) renderOrder=\(node.renderingOrder)")
        }
    }

    /// 直接渲染原始 USDZ（不经 TableModelLoader 处理），从侧面（低俯角）看桌腿是否完整。
    /// 若原始模型腿完整而我们处理后不完整 → 根因在 loader；若原始就不完整 → 模型/渲染本身。
    @MainActor
    func test_renderRawUSDZ_sideElevation() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let url = Bundle.main.url(forResource: "TaiQiuZhuo", withExtension: "usdz") else {
            print("LEGRAW no url"); return
        }
        let rawScene = try SCNScene(url: url, options: [.checkConsistency: true])

        // 原始 USDZ 是 Z-up：像 loader 那样套一个 -90°X 容器转成 Y-up 再看，
        // 否则相机会「看穿顶」得到俯视（此前 legraw_side 出错的原因）。
        let scene = SCNScene()
        scene.background.contents = UIColor(white: 0.55, alpha: 1)
        let container = SCNNode()
        let rootTF = rawScene.rootNode.transform
        if SCNMatrix4IsIdentity(rootTF) { container.eulerAngles.x = -Float.pi / 2 }
        else { container.transform = rootTF }
        for child in rawScene.rootNode.childNodes { container.addChildNode(child.clone()) }
        scene.rootNode.addChildNode(container)

        // 转储（Y-up 世界）节点层级 Y 范围。
        var rows: [String] = []
        container.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bMin, bMax) = node.boundingBox
            var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
            for c in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMax.z),
                      SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMax.z)] {
                let w = node.convertPosition(c, to: nil); lo = min(lo, w.y); hi = max(hi, w.y)
            }
            rows.append("LEGRAW node=\(node.name ?? "?") worldY=[\(lo)..\(hi)] elems=\(node.geometry!.elements.count)")
        }
        rows.sort(); rows.forEach { print($0) }

        // 低角度 3/4 透视，模拟参考照片视角看桌腿真实高度。
        let (bMin, bMax) = scene.rootNode.boundingBox
        let center = SCNVector3((bMin.x+bMax.x)/2, (bMin.y+bMax.y)/2, (bMin.z+bMax.z)/2)
        let span = max(bMax.x-bMin.x, max(bMax.y-bMin.y, bMax.z-bMin.z))
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.fieldOfView = 40
        cam.zNear = 0.01; cam.zFar = 10000
        camNode.camera = cam
        // 斜前方、略高于桌面一点点（低俯角），能同时看到台面与整条腿。
        camNode.position = SCNVector3(center.x + span*1.1, center.y + span*0.35, center.z + span*1.4)
        camNode.look(at: SCNVector3(center.x, center.y, center.z))
        scene.rootNode.addChildNode(camNode)

        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
        amb.light!.intensity = 900; scene.rootNode.addChildNode(amb)
        let dir = SCNNode(); dir.light = SCNLight(); dir.light!.type = .directional
        dir.light!.intensity = 700; dir.eulerAngles = SCNVector3(-0.7, 0.6, 0)
        scene.rootNode.addChildNode(dir)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camNode
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 800),
                                    antialiasingMode: .multisampling4X)
        try img.pngData()?.write(to: URL(fileURLWithPath: "/tmp/legraw_side.png"))
        print("LEGRAW wrote /tmp/legraw_side.png")
    }

    /// 处理后的 AngleTrainingScene 侧视立面（相机沿世界 +Z 平视），看桌腿真实高度轮廓。
    @MainActor
    func test_renderProcessed_sideElevation() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: true)
        scene.background.contents = UIColor(white: 0.55, alpha: 1)
        scene.hideAllBalls(); scene.hideCueStick()
        // 移除环境地面，避免遮挡侧视立面判读。
        scene.rootNode.enumerateChildNodes { node, _ in
            if let n = node.name, n.contains("ground") { node.removeFromParentNode() }
        }

        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = 0.9   // 竖直看全 0~0.85 桌高 + 余量
        cam.zNear = 0.01; cam.zFar = 100
        camNode.camera = cam
        // 从 +Z 方向平视桌子长侧立面，看向台面中点高度。
        camNode.position = SCNVector3(0, 0.42, 6)
        camNode.look(at: SCNVector3(0, 0.42, 0))
        scene.rootNode.addChildNode(camNode)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camNode
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: 1200, height: 700),
                                    antialiasingMode: .multisampling4X)
        try img.pngData()?.write(to: URL(fileURLWithPath: "/tmp/legproc_side.png"))
        print("LEGPROC wrote /tmp/legproc_side.png")
    }

    /// 生产导出管线单帧渲染（studio 灯已内建腿部 raking fill，见
    /// `AngleTrainingScene.setupLegFillLighting`），落盘供人工核验腿部可见性。
    @MainActor
    func test_render3D_exportPipeline() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: true)
        scene.background.contents = UIColor.black   // 真实导出场景（黑底）
        scene.hideAllBalls()
        scene.hideCueStick()

        let size = CGSize(width: 720, height: 1280)
        let cfg = SequenceVideoExporter.Perspective3DConfig()
        let cam = scene.cameraNode!.camera!
        cam.usesOrthographicProjection = false
        cam.projectionDirection = .vertical
        cam.fieldOfView = CGFloat(cfg.fovDeg)
        cam.zNear = 0.05; cam.zFar = 100
        let sol = SequenceVideoExporter.solvePerspectiveCamera(
            config: cfg, renderSize: size, surfaceY: scene.surfaceY,
            tableBottomY: scene.measuredTableBottomY()
        )
        scene.cameraNode!.position = sol.position
        scene.cameraNode!.look(at: sol.lookAt, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        try img.pngData()?.write(to: URL(fileURLWithPath: "/tmp/legexp_production.png"))
        print("LEGEXP wrote /tmp/legexp_production.png")
    }
}
