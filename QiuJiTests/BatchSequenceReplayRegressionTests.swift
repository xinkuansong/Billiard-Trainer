//
//  BatchSequenceReplayRegressionTests.swift
//  QiuJiTests
//
//  批量出片全流程回归（求解器性能优化 B5，方案 §3）：
//  重放 `content/position_play/sequences/` 下全部 drill 序列（覆盖 62 个 drill 的成品出片内容），
//  逐杆走「保存后重进」的同一条链路（`PositionPlayShotSolver.solve` → finalPositions/potted），
//  把结果落成**确定性文本 dump**（build/solver_regression/replay_dump.txt）。
//
//  用法（A/B 对拍）：本工作树（优化后）与 HEAD 基线 worktree 各跑一次本测试，
//  diff 两份 dump——**逐字节一致** = 优化未改变展示物理在全部真实 drill 盘面上的行为。
//
//  断言只做健壮性闸门（每杆可解且 feasible）；与存档 after 的偏差仅统计打印不断言
//  （存档早于 2026-07-06 的 pocketNoseRestitution 0.60→0.70 物理修订，属既有漂移，与本轮优化无关）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class BatchSequenceReplayRegressionTests: XCTestCase {

    /// 仓库根（当前树 / 基线 worktree 各自解析到自己的根，dump 互不覆盖）。
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QiuJiTests/
            .deletingLastPathComponent()   // repo root
    }

    func test_replayAllDrillSequences_deterministicDump() throws {
        let fm = FileManager.default
        let seqDir = repoRoot.appendingPathComponent("content/position_play/sequences")
        let files = (try fm.contentsOfDirectory(atPath: seqDir.path))
            .filter { $0.hasPrefix("drill_c") && $0.hasSuffix(".json") }
            .sorted()
        XCTAssertFalse(files.isEmpty, "未找到 drill 序列：\(seqDir.path)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let surfaceY = BTTablePhysics.surfaceY

        var lines: [String] = []
        var stepCount = 0
        var outcomeMismatch = 0      // 与存档 potted/flags 不一致的杆数（仅统计）
        var maxRestDriftMM = 0.0     // 与存档 after 的最大球位偏差（仅统计）

        for file in files {
            let data = try Data(contentsOf: seqDir.appendingPathComponent(file))
            let seq = try decoder.decode(PositionPlaySequence.self, from: data)

            for (i, step) in seq.steps.enumerated() {
                stepCount += 1
                guard let pred = PositionPlayShotSolver.solve(
                    before: step.before, shot: step.shot, surfaceY: surfaceY
                ) else {
                    XCTFail("\(file) step[\(i)] 快照/意图不完整，无法求解")
                    continue
                }
                XCTAssertTrue(pred.feasible, "\(file) step[\(i)] 重放不可行：\(pred.infeasibleReason)")

                // 与录制/重放同语义：进袋离场，其余球取 finalPositions（无位移保持 before）。
                let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0, shot: step.shot) })
                var after: [String: CGPoint] = [:]
                for key in step.before.onTable.keys where !potted.contains(key) {
                    let predN = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                    if let p = pred.finalPositions[predN] {
                        after[key] = AngleSceneCalculator.sceneToNormalized(position: p)
                    } else if let b = step.before.onTable[key] {
                        after[key] = CGPoint(x: b.x, y: b.y)
                    }
                }

                // 确定性 dump 行（键排序 + 定点格式）。
                let pottedStr = potted.sorted().joined(separator: ",")
                let afterStr = after.keys.sorted().map { k -> String in
                    let p = after[k]!
                    return String(format: "%@=(%.5f,%.5f)", k, p.x, p.y)
                }.joined(separator: " ")
                lines.append("\(file)|s\(i)|cuePot=\(pred.cuePocketed)|objPot=\(pred.objectPocketed)"
                             + "|potted=[\(pottedStr)]|\(afterStr)")

                // 与存档对照（仅统计，不断言——存档物理版本早于既有引擎修订）。
                if Set(step.potted) != potted
                    || step.cuePocketed != pred.cuePocketed
                    || step.objectPocketed != pred.objectPocketed {
                    outcomeMismatch += 1
                }
                for (key, np) in after {
                    guard let sp = step.after.onTable[key] else { continue }
                    // 归一化 x 跨度 = innerLength（2.54m）；y∈[0,0.5] 同尺度。
                    let dx = (Double(np.x) - sp.x) * Double(AngleSceneCalculator.innerLength)
                    let dy = (Double(np.y) - sp.y) * 2.0 * Double(AngleSceneCalculator.innerWidth)
                    maxRestDriftMM = max(maxRestDriftMM, (dx * dx + dy * dy).squareRoot() * 1000)
                }
            }
        }

        let outDir = repoRoot.appendingPathComponent("build/solver_regression")
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outFile = outDir.appendingPathComponent("replay_dump.txt")
        try (lines.joined(separator: "\n") + "\n")
            .write(to: outFile, atomically: true, encoding: .utf8)

        print("📼 [B5] 重放 \(files.count) 条序列 / \(stepCount) 杆全部可解可行；"
              + "dump → \(outFile.path)")
        print("📼 [B5] 与存档对照（信息项）：结果不一致 \(outcomeMismatch) 杆，"
              + String(format: "最大球位漂移 %.1fmm", maxRestDriftMM))
    }

    /// `ShotPrediction` 球名 → 桌面键（`PositionPlayShotSolver.predName` 的逆映射）。
    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if !shot.isFree, name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }
}
