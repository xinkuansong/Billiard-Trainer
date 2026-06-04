//
//  ShotBaker.swift
//  QiuJi
//
//  离线烘焙门面（P10 物理升级 · 内容管线雏形，ADR-P10-01）。
//
//  把「击球意图」(`ShotIntent.Shot`) 喂给物理引擎门面 `ShotPredictor`（其内部使用
//  USDZ 对齐球桌 `TableGeometry.chineseEightBallQiuJi`），求解出精确轨迹，并把
//  母球 / 目标球折线从场景米制坐标转回归一化坐标，回填到现有 `DrillAnimation`。
//
//  渲染层（`BTMiniTable` 等）天然消费 `DrillAnimation`，故烘焙后无需改任何 View。
//  同时输出物理可达校验字段（feasible / 进选定袋 / 切球角），对接 H-11 人工核查。
//
//  纯函数、值类型；可在 XCTest 烘焙跑测中作为命令行管线调用，亦可未来接入运行时。
//

import SceneKit

enum ShotBaker {

    /// 当前烘焙器标识（写入 `DrillAnimation.generator`，可追溯 / 可重烘焙）。
    static let generatorTag = "ShotBaker/engine@v2-geom"

    /// 单杆烘焙结果：回填用的 `DrillAnimation` + 物理可达校验。
    struct BakeResult {
        /// 回填到 Drill JSON 的烘焙动画（`source = "baked"`）。
        let animation: DrillAnimation
        /// 选定袋口几何上是否可进（切球角 < 极限且母球不挡路）。
        let feasible: Bool
        /// 不可进原因（feasible == false 时有效）。
        let infeasibleReason: String
        /// 显示层判定：目标球是否进袋（几何可行即视为进）。
        let objectPocketed: Bool
        /// 真实模拟测量：目标球是否真的进了选定袋（不参与显示，供校验报告）。
        let simObjectPotted: Bool
        /// 切球角（度）。
        let cutAngleDeg: Double?
        /// 母球是否进袋（通常视为失误，校验报告参考）。
        let cuePocketed: Bool
    }

    /// 烘焙单杆击球意图。
    /// - Parameters:
    ///   - shot: 归一化击球意图。
    ///   - surfaceY: 台面世界 Y（默认 `TablePhysics.tableSurfaceY`，与运行时引擎一致）。
    /// - Returns: 烘焙结果；选袋 ID 非法时返回 nil。
    static func bake(
        _ shot: ShotIntent.Shot,
        surfaceY: Float = TablePhysics.tableSurfaceY
    ) -> BakeResult? {
        guard let input = shot.shotInput(surfaceY: surfaceY) else { return nil }
        let prediction = ShotPredictor.predict(input)

        let cueAnim = ballAnimation(
            fromScene: prediction.cuePath, fallbackStart: shot.cue
        )
        let targetAnim = ballAnimation(
            fromScene: prediction.objectPath, fallbackStart: shot.target
        )
        // 瞄准方向用归一化幽灵球中心表示（与既有 cueDirection 为「点」的约定一致）。
        let cueDirection = normalized(prediction.ghost)

        let animation = DrillAnimation(
            cueBall: cueAnim,
            targetBall: targetAnim,
            pocket: shot.pocket,
            cueDirection: cueDirection,
            source: "baked",
            generator: generatorTag
        )

        return BakeResult(
            animation: animation,
            feasible: prediction.feasible,
            infeasibleReason: prediction.infeasibleReason,
            objectPocketed: prediction.objectPocketed,
            simObjectPotted: prediction.simObjectPotted,
            cutAngleDeg: prediction.cutAngleDeg,
            cuePocketed: prediction.cuePocketed
        )
    }

    // MARK: - Scene → normalized conversion

    /// 把场景折线（含起点）转成 `BallAnimation`：首点为 start，其余为直线 path 点（无贝塞尔控制点）。
    private static func ballAnimation(
        fromScene scenePts: [SCNVector3],
        fallbackStart: CanvasPoint
    ) -> BallAnimation {
        let pts = scenePts.map(normalized)
        guard let first = pts.first else {
            return BallAnimation(start: fallbackStart, path: [])
        }
        let path = pts.dropFirst().map { PathPoint(x: $0.x, y: $0.y) }
        return BallAnimation(start: first, path: Array(path))
    }

    /// 场景米制坐标 → 归一化 CanvasPoint（既有桥 `sceneToNormalized`）。
    private static func normalized(_ p: SCNVector3) -> CanvasPoint {
        let n = AngleSceneCalculator.sceneToNormalized(position: p)
        return CanvasPoint(x: rounded(Double(n.x)), y: rounded(Double(n.y)))
    }

    /// 折线坐标保留 4 位小数（亚毫米级，避免 JSON 噪声尾数）。
    private static func rounded(_ v: Double) -> Double {
        (v * 10000).rounded() / 10000
    }
}
