import SceneKit
import UIKit

/// 学练教学插图「真台化」共享设施（T-P18-46，设计稿 §3.1 / §5-5）。
///
/// 把真实 USDZ 球桌（与 8 场景页、渲染管线同一张 `AngleTrainingScene` 桌）离屏渲染
/// 一次成**空台底图**并缓存；SwiftUI 教学图在其上按 §1.2 线语言叠加真球面
/// （`PoolBallFace`）与标注 —— 插图与场景页同一张桌、同一套线，风格同源。
///
/// 坐标契约（钉死，与 `CameraRig` 顶视相机一致）：
/// - 世界系：X = 台面长轴（innerLength 2.54m），Z = 短轴（innerWidth 1.27m），原点台心。
/// - landscape（`applyTopDown2D`，相机 eulerAngles(-π/2,0,0)）：屏幕右 = 世界 +X，屏幕上 = 世界 −Z。
/// - portrait（`applyTopDown2DRotated`，up = 世界 +X）：屏幕上 = 世界 +X，屏幕右 = 世界 +Z。
/// - 正交投影 ⇒ 世界 → 图像为线性映射：`orthographicScale` = 视口半高（世界米）。
///
/// ⚠️ 首渲需解析 USDZ（重），只在教学页首次出现时走一次，之后按 key 内存缓存。
@MainActor
enum TableFigureRenderer {

    // MARK: - Backdrop

    /// 空台底图 + 世界 ↔ 图像归一化坐标的确定性映射。
    struct Backdrop {
        enum Orientation: String {
            /// 长轴横放（配横宽插图卡）。
            case landscape
            /// 长轴竖放（配竖高题面）。
            case portrait
        }

        let image: UIImage
        let orientation: Orientation
        /// 相机正交半高（世界米）。
        let orthoScale: CGFloat
        /// 图像宽高比 W/H。
        let aspect: CGFloat
        /// 取景中心（世界 X/Z，米）。全台取景 = 台心 (0,0)；特写卡可偏移。
        let center: CGPoint

        /// 世界台面坐标（米）→ 归一化图像坐标（0–1，原点左上）。
        func imagePoint(x: CGFloat, z: CGFloat) -> CGPoint {
            let dx = x - center.x
            let dz = z - center.y
            switch orientation {
            case .landscape:
                return CGPoint(x: 0.5 + dx / (2 * orthoScale * aspect),
                               y: 0.5 + dz / (2 * orthoScale))
            case .portrait:
                return CGPoint(x: 0.5 + dz / (2 * orthoScale * aspect),
                               y: 0.5 - dx / (2 * orthoScale))
            }
        }

        /// 世界长度（米）→ 归一化图像**高度**比例（乘以视图高得点长）。
        func imageLength(_ meters: CGFloat) -> CGFloat {
            meters / (2 * orthoScale)
        }
    }

    private static var cache: [String: Backdrop] = [:]

    /// 渲染（或取缓存）空台底图。`aspect` = 目标视图宽高比（决定取景与图像比例）。
    ///
    /// 全台取景（`closeup == nil`）：球桌外框完整可见 + 双轴居中 + 少量安全余量
    /// （同 `CameraRig.rotatedFitMargin` 语义）。
    /// 特写取景（`closeup != nil`）：以指定世界点为中心、指定正交半高的台呢特写，
    /// 用于两球重叠/公式等近景教学卡——材质仍是同一张真台呢。
    static func backdrop(orientation: Backdrop.Orientation,
                         aspect: CGFloat,
                         closeup: (center: CGPoint, halfHeight: CGFloat)? = nil,
                         heightPoints: CGFloat = 360,
                         scale: CGFloat = 2) -> Backdrop? {
        // aspect 量化进缓存键，避免同页多卡因浮点微差重复渲。
        var key = "\(orientation.rawValue)-\(String(format: "%.2f", aspect))"
        if let closeup {
            key += String(format: "-c%.3f,%.3f,%.3f",
                          closeup.center.x, closeup.center.y, closeup.halfHeight)
        }
        if let hit = cache[key] { return hit }

        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil, let rig = scene.cameraRig else { return nil }
        scene.background.contents = UIColor.black
        scene.hideAllBalls()
        scene.hideCueStick()

        // 取景解算：正交半高需同时满足竖轴（半高 ≥ 竖向半幅×余量）与
        // 横轴（半高×aspect ≥ 横向半幅×余量）两个约束；特写取景直接用指定半高。
        let margin = CameraRig.rotatedFitMargin
        let halfL = rig.tableOuterHalfLength * margin   // 世界 X 半幅
        let halfW = rig.tableOuterHalfWidth * margin    // 世界 Z 半幅
        let center = closeup?.center ?? .zero
        // `applyTopDown2D(Rotated)` 把 panOffset (x,y) 直接作相机世界 X/Z 位置。
        rig.topDownPanOffset = center
        switch orientation {
        case .landscape:
            // 竖轴对应世界 Z，横轴对应世界 X。
            rig.topDownOrthographicScale = closeup.map { Double($0.halfHeight) }
                ?? max(halfW, halfL / Double(aspect))
            rig.applyTopDown2D()
        case .portrait:
            // 竖轴对应世界 X，横轴对应世界 Z。
            rig.topDownOrthographicScale = closeup.map { Double($0.halfHeight) }
                ?? max(halfL, halfW / Double(aspect))
            rig.applyTopDown2DRotated()
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false

        let pixel = CGSize(width: heightPoints * aspect * scale,
                           height: heightPoints * scale)
        let image = renderer.snapshot(atTime: 0, with: pixel,
                                      antialiasingMode: .multisampling4X)

        let backdrop = Backdrop(image: image,
                                orientation: orientation,
                                orthoScale: CGFloat(rig.topDownOrthographicScale),
                                aspect: aspect,
                                center: center)
        cache[key] = backdrop
        return backdrop
    }
}
