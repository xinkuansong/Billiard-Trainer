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
        // Approved thumbnail recipe: current model/style with the original
        // thumbnail lighting. Mobile area-light shaders have a different look.
        scene.setupScene(enhancedRendering: false, mobileRendering: false)
        scene.applyTableStyle(.defaultStyle, showsSights: true)
        scene.applyClothColor(.green)
        // Freeze the published cue finish instead of inheriting bake-device preferences.
        guard scene.cueStick?.applyStyle(.inkDragon) == true else { return nil }
        scene.setCameraMode(.topDown2D, animated: false)
        scene.background.contents = UIColor.black
        guard scene.cameraNode != nil,
              var source = DrillStaticPreview.resolveSource(for: drill) else { return nil }

        do {
            // Only the display copy moves. Re-solve its shot so cue/aim lines
            // use these same positions; never mutate content or live layouts.
            source.board.onTable = try ThumbnailBallLayout.resolve(
                source.board.onTable,
                radius: Double(AngleSceneCalculator.ballRadius)
                    * Double(DrillStaticPreview.Options.thumbnail.ballScale)
                    / Double(AngleSceneCalculator.innerLength)
            )
        } catch {
            NSLog("Thumbnail layout failed for %@: %@", drill.id, String(describing: error))
            return nil
        }
        DrillStaticPreview.apply(source: source, to: scene, options: .thumbnail)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        renderer.delegate = scene.contactOcclusion

        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let image = renderer.snapshot(atTime: 0, with: pixelSize,
                                      antialiasingMode: .multisampling4X)
        return image
    }
}

/// Minimum squared displacement subject to inset table bounds and pairwise
/// separation along each pair's original direction. This preserves rows and
/// relative ordering instead of scattering balls or cumulatively pushing one end.
/// Dykstra projections converge to the nearest point in these convex constraints.
enum ThumbnailBallLayout {
    enum LayoutError: Error { case invalidInput, infeasibleOrUnconverged }

    static func resolve(_ input: [String: CanvasPoint], radius: Double) throws -> [String: CanvasPoint] {
        guard radius.isFinite, radius > 0, radius < 0.25,
              input.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            throw LayoutError.invalidInput
        }
        let keys = input.keys.sorted()
        guard !keys.isEmpty else { return input }
        let originals = keys.map { SIMD2(input[$0]!.x, input[$0]!.y) }
        var points = originals
        let lower = SIMD2(repeating: radius), upper = SIMD2(1 - radius, 0.5 - radius)
        let diameter = 2 * radius
        let tolerance = 1e-9 // normalized units; far below a rendered pixel
        struct Pair {
            let i: Int, j: Int
            let normal: SIMD2<Double>
            var correction: Double = 0
        }
        var pairs: [Pair] = []
        for i in keys.indices {
            for j in keys.indices where j > i {
                let delta = originals[j] - originals[i]
                let length = hypot(delta.x, delta.y)
                // Coincident source centers have no direction. Stable ID order
                // supplies a reproducible horizontal ordering on the longer axis.
                let normal = length > tolerance ? delta / length : SIMD2(1, 0)
                pairs.append(Pair(i: i, j: j, normal: normal))
            }
        }
        var boundCorrections = Array(repeating: SIMD2<Double>.zero, count: points.count)
        for _ in 0..<4096 {
            let previous = points
            for k in pairs.indices {
                let pair = pairs[k]
                let a = points[pair.i] - pair.normal * pair.correction
                let b = points[pair.j] + pair.normal * pair.correction
                let delta = b - a
                let deficit = diameter - (delta.x * pair.normal.x + delta.y * pair.normal.y)
                let push = max(0, deficit / 2)
                points[pair.i] = a - pair.normal * push
                points[pair.j] = b + pair.normal * push
                pairs[k].correction = -push
            }
            for i in points.indices {
                let p = points[i] + boundCorrections[i]
                points[i] = SIMD2(min(upper.x, max(lower.x, p.x)), min(upper.y, max(lower.y, p.y)))
                boundCorrections[i] = p - points[i]
            }
            let movement = zip(points, previous).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
            let worst = pairs.map { pair in
                let delta = points[pair.j] - points[pair.i]
                return diameter - (delta.x * pair.normal.x + delta.y * pair.normal.y)
            }.max() ?? 0
            if movement <= tolerance && worst <= tolerance {
                return Dictionary(uniqueKeysWithValues: zip(keys, points).map { ($0, CanvasPoint(x: $1.x, y: $1.y)) })
            }
        }
        // Never silently publish overlapping balls if preserving the formation
        // and requested display size cannot satisfy the table bounds.
        throw LayoutError.infeasibleOrUnconverged
    }
}
