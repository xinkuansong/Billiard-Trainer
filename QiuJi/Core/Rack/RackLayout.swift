//
//  RackLayout.swift
//  QiuJi
//
//  P17「球形生成器」核心：把一局开球的**摆球架**几何与球号分配收口到一处（ADR-P17-01）。
//
//  坐标系：SceneKit 世界系（X–Z 平面、Y 朝上、球心 Y = surfaceY + R），与物理引擎、
//  `AngleSceneCalculator` 同源；`Rack.boardSnapshot` 经 `AngleSceneCalculator.sceneToNormalized`
//  转归一化系（x∈[0,1] 左→右、y∈[0,0.5] 上→下）供编辑器消费。
//
//  几何移植自 `01.billiard_app` 的 `setupRackLayout`（同台面几何、同引擎血统）并已由
//  `BreakRackPhysicsTests` 验证 15 球开球可完全停稳/不出界/不互穿/确定性：三角阵紧贴、
//  `gap = 1mm`（01 实测：间隙过大动量传不下去，只撞动顶角球）、母球在开球区。
//

import Foundation
import SceneKit

// MARK: - Game type

/// 可生成的开球玩法。`zhuifen` 现为「9 球系」少球玩法（4/5/6 球），固定带 9 号、1 号在 apex：
/// 4 球小菱形（9 在底正对 1）、5 球菱形+尾（9 在尾）、6 球三角（9 在底排中点）；详见
/// `makeSlots` / `assignNumbers`（ADR-P17-01 §决策，按用户拍板的摆法）。
enum RackGame: Equatable {
    /// 中式八球：15 球三角阵，8 号居中（第 3 排中点），底两角一花一色。
    case chineseEightBall
    /// 美式九球：1–9 钻石阵，1 号顶角、9 号居中、2 号尾点。
    case nineBall
    /// 9 球系少球玩法：4/5/6 球（其余值按 [2,10] 截断，仅兜底）。固定 1 号在 apex、9 号按玩法定位。
    case zhuifen(balls: Int)

    /// 目标球数量。
    var ballCount: Int {
        switch self {
        case .chineseEightBall: return 15
        case .nineBall: return 9
        case .zhuifen(let n): return max(2, min(10, n))
        }
    }
}

// MARK: - Rack output

/// 摆球架中的一颗目标球（SceneKit 世界系）。
struct RackBall {
    /// 在桌键（`"_n"`），与 `PositionPlayBall.objectKeys` / 引擎球名一致。
    let key: String
    let number: Int
    let position: SCNVector3
}

/// 一副摆好的球架：母球 + 全部目标球（SceneKit 世界系，紧贴未开）。
struct Rack {
    let game: RackGame
    let cue: SCNVector3
    let balls: [RackBall]
    let surfaceY: Float

    /// 摆球架的归一化快照（母球 + 全部球），供静态预览 / 动画起始帧。
    var boardSnapshot: BoardSnapshot {
        var onTable: [String: CanvasPoint] = [:]
        let c = AngleSceneCalculator.sceneToNormalized(position: cue)
        onTable[PositionPlayBall.cueKey] = CanvasPoint(x: Double(c.x), y: Double(c.y))
        for b in balls {
            let n = AngleSceneCalculator.sceneToNormalized(position: b.position)
            onTable[b.key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        return BoardSnapshot(onTable: onTable)
    }
}

// MARK: - Generator

enum RackLayout {

    /// 开球缝隙（米）。开球三角必须**近似冻结**（紧贴），间隙过大动量无法逐颗传递 → 母球留太多能量、
    /// 球堆不炸。本项目 `BreakRackPhysicsTests.test_break15Ball_gapSweep` 实测（v=7、5 个瞄准偏角取均值）：
    /// gap=1mm 仅 ~5/15 球散开>30cm，gap≤0.2mm 升到 ~10/15 且仍完全停稳/不互穿（终态最小球距≈2R）。
    /// 取 0.2mm：贴近真实冻结球架的强开球，又留一丝数值余量（>0.1mm 的极限贴球）。
    static let gap: Float = 0.0002

    /// 生成一副摆球架。`seed` 决定球号随机排布（中八底角一花一色、9 球钻石锚点、
    /// 少球玩法 1 号在 apex / 9 号定位等**规则约束**不随机）；同 `seed` 必产同架（确定性）。
    static func make(_ game: RackGame,
                     seed: UInt64 = 0,
                     surfaceY: Float = BTTablePhysics.surfaceY) -> Rack {
        var rng = SeededGenerator(seed: seed)
        let R = BallPhysics.radius
        let spacing = R * 2 + gap                       // 相切球心距（含 1mm 开球缝隙）
        let rowOffset = spacing * sqrt(3.0) / 2.0       // 三角/钻石阵排间距
        let footSpotX = -TablePhysics.innerLength / 4   // 置球点（左半区）
        let headX = TablePhysics.innerLength / 4        // 开球线（右半区）
        let y = surfaceY + R

        let slots = makeSlots(for: game, footSpotX: footSpotX,
                              rowOffset: rowOffset, spacing: spacing, y: y)
        let numbers = assignNumbers(for: game, slotCount: slots.count, rng: &rng)
        let balls = zip(slots, numbers).map { pos, num in
            RackBall(key: "_\(num)", number: num, position: pos)
        }
        return Rack(game: game, cue: SCNVector3(headX, y, 0), balls: balls, surfaceY: surfaceY)
    }

    // MARK: - Slot geometry

    /// 生成每副球架的 slot 世界坐标（apex 在 +X 侧、沿 −X 展开）。
    /// slot 顺序 = 逐排、每排从 +z 到 −z，与 `assignNumbers` 的下标约定一一对应。
    private static func makeSlots(for game: RackGame,
                                  footSpotX: Float, rowOffset: Float,
                                  spacing: Float, y: Float) -> [SCNVector3] {
        // 一整排：在 x 处放 count 颗，z 上居中（+z → −z），排内球心距 = spacing。
        func row(_ x: Float, _ count: Int) -> [SCNVector3] {
            (0..<count).map { col in
                SCNVector3(x, y, (Float(count - 1) / 2 - Float(col)) * spacing)
            }
        }
        // 多排三角/钻石阵（apex 在第 0 排，逐排沿 −X 偏移 rowOffset）。
        func rows(_ counts: [Int]) -> [SCNVector3] {
            var s: [SCNVector3] = []
            for (r, k) in counts.enumerated() { s += row(footSpotX - Float(r) * rowOffset, k) }
            return s
        }

        switch game {
        case .chineseEightBall:
            return rows([1, 2, 3, 4, 5])                 // 15 三角
        case .nineBall:
            return rows([1, 2, 3, 2, 1])                 // 9 钻石
        case .zhuifen(let raw):
            let n = max(2, min(10, raw))
            switch n {
            case 4:
                return rows([1, 2, 1])                   // 小菱形：apex / 中行两颗 / 底一颗
            case 5:
                // 菱形 [1,2,1] + 一颗与底球**共线相切**的尾球（x 间距 = spacing，非 rowOffset）。
                var s = rows([1, 2, 1])
                let backX = footSpotX - 2 * rowOffset
                s.append(SCNVector3(backX - spacing, y, 0))
                return s
            case 6:
                return rows([1, 2, 3])                   // 三角
            default:
                // 兜底（UI 仅用 4/5/6）：整三角满排取前 N（保证落在真实 nestle 位、不互穿）。
                var counts: [Int] = []; var placed = 0; var size = 1
                while placed < n { counts.append(size); placed += size; size += 1 }
                return Array(rows(counts).prefix(n))
            }
        }
    }

    // MARK: - Number assignment

    /// 按玩法规则把球号填入 slot（slot 顺序 = 逐排、每排从 +z 到 −z）。
    private static func assignNumbers(for game: RackGame,
                                      slotCount: Int,
                                      rng: inout SeededGenerator) -> [Int] {
        switch game {
        case .chineseEightBall:
            // 15 slot：idx4 = 第 3 排中点（8 号）；idx10 / idx14 = 底排两角（一花一色）。
            var result = [Int](repeating: 0, count: 15)
            result[4] = 8
            var solids = Array(1...7).shuffled(using: &rng)    // 全色
            var stripes = Array(9...15).shuffled(using: &rng)  // 花色
            let cornerSolid = solids.removeLast()
            let cornerStripe = stripes.removeLast()
            if Bool.random(using: &rng) {
                result[10] = cornerSolid; result[14] = cornerStripe
            } else {
                result[10] = cornerStripe; result[14] = cornerSolid
            }
            var rest = (solids + stripes).shuffled(using: &rng)
            for i in 0..<15 where result[i] == 0 { result[i] = rest.removeLast() }
            return result

        case .nineBall:
            // 9 slot：idx0 顶角 = 1、idx4 钻石中心 = 9、idx8 尾点 = 2，其余随机。
            var result = [Int](repeating: 0, count: 9)
            result[0] = 1; result[4] = 9; result[8] = 2
            var rest = [3, 4, 5, 6, 7, 8].shuffled(using: &rng)
            for i in 0..<9 where result[i] == 0 { result[i] = rest.removeLast() }
            return result

        case .zhuifen(let raw):
            // 9 球系少球：固定带 9 号、1 号在 apex；中行 2/3、底两角 4/5 随机左右。
            let n = max(2, min(10, raw))
            switch n {
            case 4:
                // [1,2,1]：idx0 apex = 1、idx3 底（正对 1）= 9、idx1/2 中行 = 2/3。
                var r = [Int](repeating: 0, count: 4)
                r[0] = 1; r[3] = 9
                var mid = [2, 3].shuffled(using: &rng)
                r[1] = mid.removeLast(); r[2] = mid.removeLast()
                return r
            case 5:
                // 菱形 1/2/3/4 + 尾 9：idx0 = 1、idx3 菱形底 = 4、idx4 尾 = 9、idx1/2 中行 = 2/3。
                var r = [Int](repeating: 0, count: 5)
                r[0] = 1; r[3] = 4; r[4] = 9
                var mid = [2, 3].shuffled(using: &rng)
                r[1] = mid.removeLast(); r[2] = mid.removeLast()
                return r
            case 6:
                // 三角 [1,2,3]：idx0 apex = 1、idx4 底排中点 = 9、idx1/2 中行 = 2/3、idx3/5 底两角 = 4/5。
                var r = [Int](repeating: 0, count: 6)
                r[0] = 1; r[4] = 9
                var mid = [2, 3].shuffled(using: &rng)
                r[1] = mid.removeLast(); r[2] = mid.removeLast()
                var corners = [4, 5].shuffled(using: &rng)
                r[3] = corners.removeLast(); r[5] = corners.removeLast()
                return r
            default:
                // 兜底：idx0 顶角 = 1，其余随机。
                var result = [Int](repeating: 0, count: slotCount)
                result[0] = 1
                var rest = Array(2...slotCount).shuffled(using: &rng)
                for i in 0..<slotCount where result[i] == 0 { result[i] = rest.removeLast() }
                return result
            }
        }
    }
}

// MARK: - Deterministic RNG

/// SplitMix64 确定性随机源（同 seed 同序列），供球号洗牌；与测试网种子化习惯一致。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
