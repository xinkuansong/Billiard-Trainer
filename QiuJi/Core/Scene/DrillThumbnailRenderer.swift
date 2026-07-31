import SceneKit
import UIKit

/// 把一条 Drill 渲染成「USDZ 球桌 2D 顶视」缩略图（离屏，零交互）。
///
/// 用途：内容管线离线烘焙缩略图 PNG（运行时零成本）。静帧契约见
/// `DrillStaticPreview`（代表性球形首杆 · 真球号 · 杆 · 线语言 v2 · ghost）。
///
/// ⚠️ 不要在可滚动列表里逐卡实时调用——`AngleTrainingScene.setupScene()` 每次都从磁盘
/// 解析 USDZ + 克隆节点，开销很大。仅用于离线烘焙或单个详情场景。
enum DrillThumbnailRenderer {

    /// 渲染缩略图。`size` 为点尺寸（2:1 横向最佳），`scale` 为像素倍率。
    @MainActor
    static func render(drill: DrillContent,
                       size: CGSize = CGSize(width: 320, height: 160),
                       scale: CGFloat = 2,
                       device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> UIImage? {
        guard let device else { return nil }

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        guard scene.cameraNode != nil else { return nil }

        guard DrillStaticPreview.apply(
            drill: drill, to: scene, options: .thumbnail
        ) != nil else { return nil }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false

        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let image = renderer.snapshot(atTime: 0, with: pixelSize,
                                      antialiasingMode: .multisampling4X)
        return image
    }
}
