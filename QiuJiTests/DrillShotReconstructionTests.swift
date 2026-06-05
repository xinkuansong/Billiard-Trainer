//
//  DrillShotReconstructionTests.swift
//  QiuJiTests
//
//  里程碑 B（截图逆向 → 引擎反解）：读取 Python 抠图产出的 extraction.json
//  （球位 + 选袋 + 母球轨迹点云，归一化坐标），在物理引擎里反解出每杆的
//  **力度(velocity m/s) / 加塞(spinX 左右、spinY 高低) / 速度**，使引擎重算的
//  母球轨迹与截图提取的轨迹最吻合（Chamfer 距离，免排序）。
//
//  产出：
//    build/shot_reconstruction/drill_c005/solve_groupN.png  重算轨迹 vs 截图轨迹对比图
//    build/shot_reconstruction/drill_c005/solve_sheet.png    四杆合览
//    build/shot_reconstruction/drill_c005/solved.json        反解参数（喂给里程碑 C 视频合成）
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/DrillShotReconstructionTests/test_solveDrillC005
//

import XCTest
import UIKit
import SceneKit
import AVFoundation
@testable import QiuJi

final class DrillShotReconstructionTests: XCTestCase {

    private let baseDir = "/Users/song/projects/13.billiard_trainer/build/shot_reconstruction/drill_c005"
    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    /// 顶视世界范围（含袋口落孔，与 ShotScenarioRenderTests 一致）。
    private let xRange: Float = 1.40
    private let zRange: Float = 0.76

    // MARK: - extraction.json 解码

    private struct ExtractionFile: Decodable { let drill: String; let shots: [ExShot] }
    private struct ExShot: Decodable {
        let group: Int
        let balls: [ExBall]
        let cue_path_norm: [[Double]]
        let cue_rest_norm: [Double]?
        let object_path_norm: [[Double]]
        let selected_pocket: String?
    }
    private struct ExBall: Decodable { let role: String; let nx: Double; let ny: Double }

    // MARK: - hints.json 解码（手工标注先验：吃库数 / 高低杆 / 速度范围）

    private struct HintsFile: Decodable { let shots: [Hint] }
    private struct Hint: Decodable {
        let group: Int
        let cueCushions: Int?
        let spin: String?
        let velMin: Double?
        let velMax: Double?
    }

    /// 高低杆类别 → spinY 区间（左右塞 spinX 不受此约束）。
    private func spinYRange(_ spin: String?) -> (lo: Float, hi: Float) {
        switch spin?.lowercased() {
        case "draw":          return (-0.85, -0.15)   // 低杆（缩）
        case "low":           return (-0.60, -0.10)   // 偏低
        case "stun", "center":return (-0.15, 0.15)    // 中杆 / 定杆
        case "midhigh", "mid-high": return (0.10, 0.60) // 中高杆
        case "follow":        return (0.15, 0.85)     // 高杆（跟）
        case "follow-strong", "followstrong": return (0.50, 0.95) // 强跟
        default:              return (-0.80, 0.80)     // 无标注 = 全范围
        }
    }

    // MARK: - 反解结果

    private struct Solved {
        var group: Int
        var cue: SCNVector3
        var target: SCNVector3
        var obstacle: SCNVector3?
        var pocketIndex: Int
        var pocketId: String
        var velocity: Float
        var spinX: Float
        var spinY: Float
        var residualMM: Float       // 母球形状残差（Chamfer）
        var objResidualMM: Float    // 目标球线残差（Chamfer，进球点变量的拟合度）
        var restErrMM: Float        // 母球落点误差（主目标）
        var aimOffsetMM: Float      // 进球点相对袋心的横向偏移（容错窗内，正=进球线左侧）
        var cueCushions: Int        // 反解出的母球吃库数
        var hintCushions: Int?      // 截图标注的母球吃库数（nil=未标注）
        var observedCue: [SCNVector3]
        var observedObject: [SCNVector3]
        var observedRest: SCNVector3?
        var prediction: ShotPrediction
    }

    // MARK: - 主流程

    func test_solveDrillC005() throws {
        let solvedShots = try loadAndSolve()
        try renderSheet(solvedShots)
        for s in solvedShots { try renderOne(s) }
        try writeSolvedJSON(solvedShots)
        XCTAssertFalse(solvedShots.isEmpty, "未反解出任何一杆")
    }

    /// 读取 extraction.json，逐杆反解，返回解集（供对比图与视频合成共用）。
    private func loadAndSolve() throws -> [Solved] {
        let url = URL(fileURLWithPath: "\(baseDir)/extraction.json")
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("缺少 extraction.json，请先跑 tools/shot_reconstruction/extract.py")
        }
        let file = try JSONDecoder().decode(ExtractionFile.self, from: data)
        // 手工标注先验（可选）：吃库数 / 高低杆 / 速度范围。缺文件则全空间搜索。
        var hints: [Int: Hint] = [:]
        if let hdata = try? Data(contentsOf: URL(fileURLWithPath: "\(baseDir)/hints.json")),
           let hfile = try? JSONDecoder().decode(HintsFile.self, from: hdata) {
            for h in hfile.shots { hints[h.group] = h }
            print("HINTS loaded: \(hints.count) 杆有标注")
        } else {
            print("HINTS 无（hints.json 缺失）→ 全空间搜索")
        }
        var solvedShots: [Solved] = []
        print("\n===SHOT-RECONSTRUCT=== drill=\(file.drill)")
        for shot in file.shots.sorted(by: { $0.group < $1.group }) {
            guard let s = solveOne(shot, hint: hints[shot.group]) else {
                print("  group\(shot.group): 跳过（缺球位/非法选袋）")
                continue
            }
            solvedShots.append(s)
            let cushTag = s.hintCushions.map { "\(s.cueCushions)/标注\($0)" } ?? "\(s.cueCushions)"
            print(String(format: "  group%d 袋=%@ | 力度 v=%.2f m/s(档≈%@) | 加塞 x=%+.2f(左右) y=%+.2f(高低) | 母球吃库=%@ | 进球点偏移=%+.0fmm | 落点误差=%.0fmm | 母球残差=%.0fmm | 目标球残差=%.0fmm | 进袋=%@",
                         s.group, s.pocketId, s.velocity, forceLabel(s.velocity), s.spinX, s.spinY,
                         cushTag, s.aimOffsetMM, s.restErrMM, s.residualMM, s.objResidualMM,
                         s.prediction.objectPocketed ? "✓" : "✗"))
        }
        print("===END===\n")
        return solvedShots
    }

    // MARK: - 单杆反解（坐标descent 搜 velocity/spin，最小化 Chamfer）

    private func solveOne(_ shot: ExShot, hint: Hint? = nil) -> Solved? {
        func ball(_ role: String) -> SCNVector3? {
            guard let b = shot.balls.first(where: { $0.role == role }) else { return nil }
            return AngleSceneCalculator.normalizedToScene(point: CGPoint(x: b.nx, y: b.ny), surfaceY: sY)
        }
        guard let cue = ball("cue"), let target = ball("target"),
              let pid = shot.selected_pocket,
              let pocketIndex = ShotIntent.pocketIndex(for: pid) else { return nil }
        let obstacle = ball("obstacle")
        let observed = shot.cue_path_norm.map {
            AngleSceneCalculator.normalizedToScene(point: CGPoint(x: $0[0], y: $0[1]), surfaceY: sY)
        }
        guard observed.count >= 4 else { return nil }
        // 截图提取的**目标球**轨迹（进球线）：进球点变量的拟合目标（之前抠了未用）。
        let observedObj = shot.object_path_norm.map {
            AngleSceneCalculator.normalizedToScene(point: CGPoint(x: $0[0], y: $0[1]), surfaceY: sY)
        }

        // 母球落点（走位终点）：来自 Python 测地最远点，是反解的**主目标**。
        let obsRest: SCNVector3? = shot.cue_rest_norm.map {
            AngleSceneCalculator.normalizedToScene(point: CGPoint(x: $0[0], y: $0[1]), surfaceY: sY)
        }

        // 进球点几何：袋心 + t·n̂（n̂ ⟂ 进球线 target→袋心），t 在袋口**容错窗**内滑动。
        // 容错半幅 = 落袋孔半径 − 球半径（球心可偏离袋心而仍落袋的最大量）。
        let pocketCenter = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let pdx = pocketCenter.x - target.x, pdz = pocketCenter.z - target.z
        let pdl = max(hypotf(pdx, pdz), 1e-5)
        let nX = -pdz / pdl, nZ = pdx / pdl                              // 垂直进球线的单位向量
        let aimTol = AngleSceneCalculator.pocketDropRadius(index: pocketIndex) - R
        func aimPoint(_ t: Float) -> SCNVector3 {
            SCNVector3(pocketCenter.x + t * nX, pocketCenter.y, pocketCenter.z + t * nZ)
        }

        // 手工标注先验：高低杆 → spinY 区间；可选速度上下限；可选母球吃库数。
        let (syLo, syHi) = spinYRange(hint?.spin)
        let vLo = Float(hint?.velMin ?? 0.8)
        let vHi = Float(hint?.velMax ?? 6.5)
        let cueCushTarget = hint?.cueCushions

        /// 综合代价（参考图是**理想化示意**：直线+硬反弹；引擎是**真实物理**：减速曲线、真实
        /// 反弹角）。稳健组合：
        ///   母球落点误差（主）+ 0.15×母球形状 chamfer（辅）+ 0.20×目标球线 chamfer（进球点拟合）
        ///   + 0.012×|塞|（塞正则）+ 0.02×|进球点偏移/容错|（进球点正则）
        ///   + 0.12×|吃库数−标注|（截图先验：母球吃库数约束解支）+ 进袋/刮杆惩罚。
        func cost(_ v: Float, _ sx: Float, _ sy: Float, _ t: Float)
            -> (combined: Float, chamfer: Float, objChamfer: Float, restErr: Float, pred: ShotPrediction) {
            var inp = ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: v, spinX: sx, spinY: sy, surfaceY: sY)
            inp.pocketAimOverride = aimPoint(t)
            let pred = ShotPredictor.predict(inp)
            guard pred.feasible, pred.cuePath.count >= 2 else { return (9.99, 9.99, 9.99, 9.99, pred) }
            let ch = chamfer(sim: pred.cuePath, obs: observed)
            let chObj = observedObj.count >= 2 ? chamfer(sim: pred.objectPath, obs: observedObj) : 0
            let simRest = pred.cuePath.last ?? cue
            let restErr = obsRest.map { hypotf(simRest.x - $0.x, simRest.z - $0.z) } ?? 0
            var combined = (obsRest == nil ? ch : restErr + 0.15 * ch)
            combined += 0.20 * chObj                          // 目标球线拟合（驱动进球点变量）
            combined += 0.012 * (abs(sx) + abs(sy))           // 塞量正则
            combined += 0.02 * (aimTol > 1e-5 ? abs(t) / aimTol : 0)  // 进球点正则：偏好袋心
            if let cc = cueCushTarget {                        // 截图先验：母球吃库数
                combined += 0.12 * Float(abs(pred.cueCushionCount - cc))
            }
            if !pred.objectPocketed { combined += 0.08 }      // 目标球须进选定袋
            if pred.cuePocketed { combined += 0.15 }          // 母球进袋（失误）重罚
            return (combined, ch, chObj, restErr, pred)
        }

        var bestV: Float = 3.3, bestSX: Float = 0, bestSY: Float = 0, bestT: Float = 0
        var bestCost = Float.greatestFiniteMagnitude
        var bestChamfer: Float = 9.99, bestObjChamfer: Float = 9.99, bestRest: Float = 9.99
        var bestPred = cost(3.3, 0, 0, 0).pred

        func consider(_ v: Float, _ sx: Float, _ sy: Float, _ t: Float) {
            let r = cost(v, sx, sy, t)
            if r.combined < bestCost {
                bestCost = r.combined; bestChamfer = r.chamfer
                bestObjChamfer = r.objChamfer; bestRest = r.restErr
                bestV = v; bestSX = sx; bestSY = sy; bestT = t; bestPred = r.pred
            }
        }
        func clampT(_ t: Float) -> Float { max(-aimTol, min(aimTol, t)) }
        func clampSY(_ s: Float) -> Float { max(syLo, min(syHi, s)) }
        func clampV(_ v: Float) -> Float { max(max(0.6, vLo), min(vHi, v)) }
        // 在 [lo,hi] 内按最大步长生成均匀样本（窄区间至少含端点）。
        func samples(_ lo: Float, _ hi: Float, _ maxStep: Float) -> [Float] {
            guard hi - lo > 1e-4 else { return [lo] }
            let n = max(1, Int(ceilf((hi - lo) / maxStep)))
            return (0...n).map { lo + (hi - lo) * Float($0) / Float(n) }
        }

        // 1) 全网格粗扫（进球点固定袋心 t=0）：力度 × 高低杆（受 hint 约束）× 左右塞（自由）。
        let vGrid = samples(vLo, vHi, 0.4)
        let syGrid = samples(syLo, syHi, 0.3)
        for v in vGrid {
            for sy in syGrid {
                for sx in stride(from: Float(-0.8), through: 0.8, by: 0.4) {
                    consider(v, sx, sy, 0)
                }
            }
        }
        // 2) 坐标下降细化（两遍）：力度 ±0.3/0.1、高低杆/左右塞 ±0.3/0.1、进球点 t 在容错窗内 9 档。
        //    高低杆与速度被钳到 hint 区间；左右塞（spinX）全范围自由。
        for pass in 0..<2 {
            for dv in stride(from: Float(-0.3), through: 0.3, by: 0.1) { consider(clampV(bestV + dv), bestSX, bestSY, bestT) }
            for dsy in stride(from: Float(-0.3), through: 0.3, by: 0.1) { consider(bestV, bestSX, clampSY(bestSY + dsy), bestT) }
            for dsx in stride(from: Float(-0.3), through: 0.3, by: 0.1) { consider(bestV, clampSpin(bestSX + dsx), bestSY, bestT) }
            if aimTol > 1e-5 {
                let half = pass == 0 ? aimTol : aimTol * 0.35
                let step = half / 4
                for dt in stride(from: -half, through: half, by: step) { consider(bestV, bestSX, bestSY, clampT(bestT + dt)) }
            }
        }

        return Solved(group: shot.group, cue: cue, target: target, obstacle: obstacle,
                      pocketIndex: pocketIndex, pocketId: pid,
                      velocity: bestV, spinX: bestSX, spinY: bestSY,
                      residualMM: bestChamfer * 1000, objResidualMM: bestObjChamfer * 1000,
                      restErrMM: bestRest * 1000, aimOffsetMM: bestT * 1000,
                      cueCushions: bestPred.cueCushionCount, hintCushions: cueCushTarget,
                      observedCue: observed, observedObject: observedObj,
                      observedRest: obsRest, prediction: bestPred)
    }

    private func clampSpin(_ s: Float) -> Float { max(-1, min(1, s)) }

    private func forceLabel(_ v: Float) -> String {
        StrokePhysics.SpeedLevel.allCases.min(by: { abs($0.velocity - v) < abs($1.velocity - v) })!.label
    }

    // MARK: - Chamfer 距离（对称，XZ 平面，单位 m）

    /// obs→sim：每个观测点到模拟折线最近距离；sim→obs：模拟折线重采样点到观测点最近距离。
    private func chamfer(sim: [SCNVector3], obs: [SCNVector3]) -> Float {
        guard sim.count >= 2, !obs.isEmpty else { return 9.99 }
        var a: Float = 0
        for o in obs { a += distToPolyline(o, sim) }
        a /= Float(obs.count)
        let samples = resample(sim, count: 80)
        var b: Float = 0
        for s in samples { b += nearestPoint(s, obs) }
        b /= Float(samples.count)
        return 0.5 * (a + b)
    }

    private func distToPolyline(_ p: SCNVector3, _ poly: [SCNVector3]) -> Float {
        var m = Float.greatestFiniteMagnitude
        for i in 0..<(poly.count - 1) { m = min(m, distToSeg(p, poly[i], poly[i + 1])) }
        return m
    }

    private func distToSeg(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x, dz = b.z - a.z
        let l2 = dx * dx + dz * dz
        if l2 < 1e-9 { return hypotf(p.x - a.x, p.z - a.z) }
        var t = ((p.x - a.x) * dx + (p.z - a.z) * dz) / l2
        t = max(0, min(1, t))
        return hypotf(p.x - (a.x + t * dx), p.z - (a.z + t * dz))
    }

    private func nearestPoint(_ p: SCNVector3, _ pts: [SCNVector3]) -> Float {
        var m = Float.greatestFiniteMagnitude
        for q in pts { m = min(m, hypotf(p.x - q.x, p.z - q.z)) }
        return m
    }

    private func resample(_ poly: [SCNVector3], count: Int) -> [SCNVector3] {
        guard poly.count >= 2 else { return poly }
        var lengths: [Float] = [0]
        for i in 1..<poly.count {
            lengths.append(lengths[i - 1] + hypotf(poly[i].x - poly[i - 1].x, poly[i].z - poly[i - 1].z))
        }
        let total = lengths.last!
        guard total > 1e-5 else { return poly }
        var out: [SCNVector3] = []
        for k in 0..<count {
            let d = total * Float(k) / Float(count - 1)
            var i = 1
            while i < lengths.count && lengths[i] < d { i += 1 }
            i = min(i, poly.count - 1)
            let seg = max(lengths[i] - lengths[i - 1], 1e-5)
            let t = (d - lengths[i - 1]) / seg
            out.append(SCNVector3(poly[i - 1].x + t * (poly[i].x - poly[i - 1].x), sY + R,
                                  poly[i - 1].z + t * (poly[i].z - poly[i - 1].z)))
        }
        return out
    }

    // MARK: - solved.json（供里程碑 C 视频合成）

    private func writeSolvedJSON(_ shots: [Solved]) throws {
        func n(_ v: SCNVector3) -> [Double] {
            let p = AngleSceneCalculator.sceneToNormalized(position: v)
            return [Double(p.x), Double(p.y)]
        }
        var arr: [[String: Any]] = []
        for s in shots {
            var d: [String: Any] = [
                "group": s.group, "pocket": s.pocketId,
                "cue": n(s.cue), "target": n(s.target),
                "velocity": Double(s.velocity), "spinX": Double(s.spinX), "spinY": Double(s.spinY),
                "aimOffsetMM": Double(s.aimOffsetMM),
                "cueCushions": s.cueCushions,
                "shapeResidualMM": Double(s.residualMM), "objResidualMM": Double(s.objResidualMM),
                "restErrMM": Double(s.restErrMM),
                "potted": s.prediction.objectPocketed,
            ]
            if let hc = s.hintCushions { d["hintCushions"] = hc }
            if let r = s.observedRest { d["cueRest"] = n(r) }
            if let o = s.obstacle { d["obstacle"] = n(o) }
            arr.append(d)
        }
        let obj: [String: Any] = ["drill": "drill_c005", "shots": arr]
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: "\(baseDir)/solved.json"))
        print("SOLVED-JSON wrote \(baseDir)/solved.json")
    }

    // MARK: - 里程碑 C：合成完整视频（4 杆 + 每杆后 3 秒停顿）

    private let videoFPS: Int32 = 60
    private let videoSize = CGSize(width: 1280, height: 720)
    private let setupHoldSec: Double = 1.2   // 每杆开打前的摆位停顿（看清新球形）
    private let restHoldSec: Double = 3.0     // 每杆结束后的停顿（用户要求 3 秒）

    func test_renderDrillC005Video() throws {
        let shots = try loadAndSolve()
        guard !shots.isEmpty else { throw XCTSkip("无可渲染杆") }
        let outURL = URL(fileURLWithPath: "\(baseDir)/drill_c005.mp4")
        try? FileManager.default.removeItem(at: outURL)

        let writer = try AVAssetWriter(url: outURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ])
        guard writer.canAdd(input) else { XCTFail("无法添加视频输入"); return }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var frameIdx: Int64 = 0
        let fps = Double(videoFPS)
        func emit(_ image: CGImage) {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            guard let buf = pixelBuffer(from: image) else { return }
            adaptor.append(buf, withPresentationTime: CMTime(value: frameIdx, timescale: videoFPS))
            frameIdx += 1
        }

        for (i, s) in shots.enumerated() {
            let playback = s.prediction.recorder.map { TrajectoryPlayback(recorder: $0, surfaceY: sY) }
            let dur = playback?.duration ?? 0
            // 1) 摆位停顿（t=0，显示新球形 + 力度/加塞指示）
            let setupImg = videoFrame(s, playback: playback, t: 0, showParams: true, trailT: 0)
            for _ in 0..<Int(setupHoldSec * fps) { emit(setupImg) }
            // 2) 击球运动（逐帧解析插值）
            let motionFrames = max(1, Int(Double(dur) * fps))
            for k in 0...motionFrames {
                let t = Float(Double(k) / fps)
                emit(videoFrame(s, playback: playback, t: t, showParams: true, trailT: t))
            }
            // 3) 结束停顿 3 秒（球静止 + 落点结果）
            let restImg = videoFrame(s, playback: playback, t: dur, showParams: true, trailT: dur)
            for _ in 0..<Int(restHoldSec * fps) { emit(restImg) }
            print("VIDEO shot \(i + 1)/\(shots.count): motion \(String(format: "%.1f", dur))s, frames so far \(frameIdx)")
        }

        input.markAsFinished()
        let done = expectation(description: "finishWriting")
        writer.finishWriting { done.fulfill() }
        wait(for: [done], timeout: 120)
        XCTAssertEqual(writer.status, .completed, "视频写入失败：\(String(describing: writer.error))")
        let secs = Double(frameIdx) / fps
        print("VIDEO wrote \(outURL.path) — \(frameIdx) 帧 / \(String(format: "%.1f", secs))s @\(videoFPS)fps")
    }

    /// CGImage → CVPixelBuffer（32ARGB），供 AVAssetWriter 适配器吞入。
    private func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        var pb: CVPixelBuffer?
        let w = Int(videoSize.width), h = Int(videoSize.height)
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB,
                            attrs as CFDictionary, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buffer
    }

    /// 渲染一帧视频：顶视球桌 + 当前时刻球位 + 已走轨迹拖尾 + 力度/加塞字幕。
    private func videoFrame(_ s: Solved, playback: TrajectoryPlayback?, t: Float,
                            showParams: Bool, trailT: Float) -> CGImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let img = UIGraphicsImageRenderer(size: videoSize, format: fmt).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: videoSize))

            // 等比映射世界→像素（保形不拉伸，居中，顶部留字幕条）。
            let topBar: CGFloat = 64
            let m: CGFloat = 24
            let availW = videoSize.width - 2 * m
            let availH = videoSize.height - topBar - m
            let scale = min(availW / CGFloat(2 * xRange), availH / CGFloat(2 * zRange))
            let plotW = scale * CGFloat(2 * xRange), plotH = scale * CGFloat(2 * zRange)
            let ox = (videoSize.width - plotW) / 2
            let oy = topBar + (availH - plotH) / 2
            func P(_ x: Float, _ z: Float) -> CGPoint {
                CGPoint(x: ox + CGFloat((x + xRange) / (2 * xRange)) * plotW,
                        y: oy + CGFloat((z + zRange) / (2 * zRange)) * plotH)
            }
            func P3(_ v: SCNVector3) -> CGPoint { P(v.x, v.z) }
            let plot = CGRect(x: ox, y: oy, width: plotW, height: plotH)

            // 台呢
            cg.setFillColor(UIColor(red: 0.11, green: 0.34, blue: 0.20, alpha: 1).cgColor)
            let felt = UIBezierPath(roundedRect: plot, cornerRadius: 10)
            cg.addPath(felt.cgPath); cg.fillPath()

            let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
            // 库边（直库 + jaw 直线段）
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor); cg.setLineWidth(1.4)
            for seg in geo.linearCushions {
                cg.beginPath(); cg.move(to: P3(seg.start)); cg.addLine(to: P3(seg.end)); cg.strokePath()
            }
            // 圆弧库（角袋 jaw 圆弧 + 中袋圆角）
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor); cg.setLineWidth(1.1)
            for arc in geo.circularCushions {
                var a0 = arc.startAngle, a1 = arc.endAngle
                if a1 < a0 { a1 += 2 * .pi }
                cg.beginPath()
                for k in 0...24 {
                    let a = a0 + (a1 - a0) * Float(k) / 24
                    let pt = P(arc.center.x + arc.radius * cosf(a), arc.center.z + arc.radius * sinf(a))
                    if k == 0 { cg.move(to: pt) } else { cg.addLine(to: pt) }
                }
                cg.strokePath()
            }
            // 袋口
            let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
            for (i, pc) in pockets.enumerated() {
                let drop = AngleSceneCalculator.pocketDropRadius(index: i)
                let c = P(pc.x, pc.z)
                let rp = CGFloat(drop) * scale
                cg.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
                cg.fillEllipse(in: CGRect(x: c.x - rp, y: c.y - rp, width: 2 * rp, height: 2 * rp))
                if i == s.pocketIndex {
                    cg.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.9).cgColor); cg.setLineWidth(2.5)
                    cg.strokeEllipse(in: CGRect(x: c.x - rp - 3, y: c.y - rp - 3, width: 2 * rp + 6, height: 2 * rp + 6))
                }
            }

            // 已走过的轨迹拖尾（按 trailT 采样 playback）：目标球橙、母球青
            func trail(_ ballName: String, color: UIColor) {
                guard let pb = playback, trailT > 1e-4 else { return }
                var pts: [CGPoint] = []
                let stepT: Float = 1.0 / Float(videoFPS)
                var tt: Float = 0
                while tt <= trailT + 1e-4 {
                    if let st = pb.stateAt(ballName: ballName, time: tt) { pts.append(P3(st.position)) }
                    tt += stepT
                }
                strokePath(cg, pts, color: color.withAlphaComponent(0.85), width: 2.6)
            }
            trail(ShotInput.targetBallName, color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 1))
            trail(ShotInput.cueBallName, color: .cyan)

            // 当前时刻球位（进袋后淡出）
            let gpx = CGFloat(R) * scale
            func ball(_ v: SCNVector3, _ color: UIColor, alpha: CGFloat = 1) {
                let c = P3(v)
                cg.setFillColor(color.withAlphaComponent(alpha).cgColor)
                cg.fillEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpx, width: 2 * gpx, height: 2 * gpx))
                cg.setStrokeColor(UIColor.black.withAlphaComponent(0.5 * alpha).cgColor); cg.setLineWidth(1)
                cg.strokeEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpx, width: 2 * gpx, height: 2 * gpx))
            }
            if let o = s.obstacle { ball(o, UIColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1)) }
            func dynamicBall(_ name: String, fallback: SCNVector3, color: UIColor) {
                if let pb = playback, let st = pb.stateAt(ballName: name, time: t) {
                    let a: CGFloat = st.motionState == .pocketed ? 0.2 : 1.0
                    ball(st.position, color, alpha: a)
                } else {
                    ball(fallback, color)
                }
            }
            dynamicBall(ShotInput.targetBallName, fallback: s.target, color: UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
            dynamicBall(ShotInput.cueBallName, fallback: s.cue, color: .white)

            // 字幕条
            if showParams {
                let l1 = String(format: "球迹 · drill_c005    第 %d 杆 / 共 4 杆    袋 = %@", s.group, s.pocketId)
                let l2 = String(format: "力度 v=%.2f m/s (档≈%@)    加塞 左右=%+.2f 高低=%+.2f%@",
                                s.velocity, forceLabel(s.velocity), s.spinX, s.spinY,
                                s.prediction.objectPocketed ? "    目标球进袋 ✓" : "")
                drawText(l1, at: CGPoint(x: 28, y: 12), size: 22, color: .white, bold: true)
                drawText(l2, at: CGPoint(x: 28, y: 40), size: 16,
                         color: UIColor(red: 0.60, green: 0.95, blue: 0.70, alpha: 1))
            }
        }
        return img.cgImage!
    }

    private func renderOne(_ s: Solved) throws {
        let w: CGFloat = 900, h: CGFloat = 560
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            ctx.cgContext.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
            drawCell(ctx.cgContext, origin: .zero, w: w, h: h, s: s)
        }
        guard let data = img.pngData() else { throw NSError(domain: "render", code: 1) }
        try data.write(to: URL(fileURLWithPath: "\(baseDir)/solve_group\(s.group).png"))
    }

    private func renderSheet(_ shots: [Solved], filename: String = "solve_sheet.png") throws {
        guard !shots.isEmpty else { return }
        let cols = 2, rows = (shots.count + 1) / 2
        let cellW: CGFloat = 760, cellH: CGFloat = 470
        let w = cellW * CGFloat(cols), h = cellH * CGFloat(rows)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            ctx.cgContext.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for (i, s) in shots.enumerated() {
                let origin = CGPoint(x: CGFloat(i % cols) * cellW, y: CGFloat(i / cols) * cellH)
                drawCell(ctx.cgContext, origin: origin, w: cellW, h: cellH, s: s)
            }
        }
        guard let data = img.pngData() else { throw NSError(domain: "render", code: 1) }
        let path = "\(baseDir)/\(filename)"
        try data.write(to: URL(fileURLWithPath: path))
        print("SOLVE-SHEET wrote \(path) (\(Int(w))x\(Int(h)))")
    }

    private func drawCell(_ cg: CGContext, origin: CGPoint, w: CGFloat, h: CGFloat, s: Solved) {
        let headerH: CGFloat = 56
        // 等比映射（保持桌面真实长宽比，不拉伸；居中于可用区）。
        let area = CGRect(x: origin.x + 8, y: origin.y + headerH, width: w - 16, height: h - headerH - 8)
        let scale = min(area.width / CGFloat(2 * xRange), area.height / CGFloat(2 * zRange))
        let plotW = scale * CGFloat(2 * xRange), plotH = scale * CGFloat(2 * zRange)
        let plot = CGRect(x: area.midX - plotW / 2, y: area.midY - plotH / 2, width: plotW, height: plotH)
        func P(_ x: Float, _ z: Float) -> CGPoint {
            CGPoint(x: plot.minX + CGFloat((x + xRange) / (2 * xRange)) * plot.width,
                    y: plot.minY + CGFloat((z + zRange) / (2 * zRange)) * plot.height)
        }
        func P3(_ v: SCNVector3) -> CGPoint { P(v.x, v.z) }

        cg.setFillColor(UIColor(red: 0.10, green: 0.22, blue: 0.16, alpha: 1).cgColor)
        cg.fill(plot)
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)

        // 袋口
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        for (i, pc) in pockets.enumerated() {
            let drop = AngleSceneCalculator.pocketDropRadius(index: i)
            let c = P(pc.x, pc.z)
            let rpx = CGFloat(drop / (2 * xRange)) * plot.width
            let rpy = CGFloat(drop / (2 * zRange)) * plot.height
            cg.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - rpx, y: c.y - rpy, width: 2 * rpx, height: 2 * rpy))
            if i == s.pocketIndex {
                cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.9).cgColor)
                cg.setLineWidth(2)
                cg.strokeEllipse(in: CGRect(x: c.x - rpx - 2, y: c.y - rpy - 2, width: 2 * rpx + 4, height: 2 * rpy + 4))
            }
        }
        // 库边（直库 + jaw 直线段）
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        cg.setLineWidth(1.2)
        for seg in geo.linearCushions { cg.beginPath(); cg.move(to: P3(seg.start)); cg.addLine(to: P3(seg.end)); cg.strokePath() }
        // 圆弧库（角袋 jaw 圆弧 + 中袋圆角）——与分离角诊断图一致，避免桌角看起来像豁口。
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.65).cgColor)
        cg.setLineWidth(1.0)
        for arc in geo.circularCushions {
            var a0 = arc.startAngle, a1 = arc.endAngle
            if a1 < a0 { a1 += 2 * .pi }
            cg.beginPath()
            for k in 0...24 {
                let a = a0 + (a1 - a0) * Float(k) / 24
                let pt = P(arc.center.x + arc.radius * cosf(a), arc.center.z + arc.radius * sinf(a))
                if k == 0 { cg.move(to: pt) } else { cg.addLine(to: pt) }
            }
            cg.strokePath()
        }

        // 截图提取的母球轨迹点（灰点）
        cg.setFillColor(UIColor(white: 0.7, alpha: 0.9).cgColor)
        for o in s.observedCue { let c = P3(o); cg.fillEllipse(in: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2)) }
        // 截图提取的目标球轨迹点（暗橙点）：进球点变量的拟合目标
        cg.setFillColor(UIColor(red: 0.85, green: 0.45, blue: 0.10, alpha: 0.8).cgColor)
        for o in s.observedObject { let c = P3(o); cg.fillEllipse(in: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2)) }

        // 进球点（容错窗内反解出的偏心瞄点）：黄色叉
        let aim = s.prediction.pocketAimPoint
        let ap = P3(aim)
        cg.setStrokeColor(UIColor.systemYellow.cgColor); cg.setLineWidth(1.6)
        cg.beginPath(); cg.move(to: CGPoint(x: ap.x - 5, y: ap.y - 5)); cg.addLine(to: CGPoint(x: ap.x + 5, y: ap.y + 5))
        cg.move(to: CGPoint(x: ap.x - 5, y: ap.y + 5)); cg.addLine(to: CGPoint(x: ap.x + 5, y: ap.y - 5)); cg.strokePath()

        // 引擎重算：目标球（橙）、母球（青）
        strokePath(cg, s.prediction.objectPath.map(P3), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 1), width: 2.4)
        strokePath(cg, s.prediction.cuePath.map(P3), color: UIColor.cyan, width: 2.4)

        // 落点对齐：参考落点（洋红实心）vs 引擎落点（青空心）
        if let r = s.observedRest {
            let c = P3(r)
            cg.setFillColor(UIColor.magenta.cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
        }
        if let sr = s.prediction.cuePath.last {
            let c = P3(sr)
            cg.setStrokeColor(UIColor.cyan.cgColor); cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
        }

        // 球
        let gpx = CGFloat(R / (2 * xRange)) * plot.width
        let gpy = CGFloat(R / (2 * zRange)) * plot.height
        func ball(_ v: SCNVector3, _ color: UIColor) {
            let c = P3(v)
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpy, width: 2 * gpx, height: 2 * gpy))
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor); cg.setLineWidth(0.8)
            cg.strokeEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpy, width: 2 * gpx, height: 2 * gpy))
        }
        if let o = s.obstacle { ball(o, UIColor(red: 0.2, green: 0.4, blue: 0.95, alpha: 1)) }
        ball(s.target, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
        ball(s.cue, .white)

        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor); cg.setLineWidth(1); cg.stroke(plot)

        // 文字
        let cushTag = s.hintCushions.map { "\(s.cueCushions)/标注\($0)" } ?? "\(s.cueCushions)"
        let l1 = String(format: "group %d  袋=%@  母球吃库=%@  %@", s.group, s.pocketId, cushTag,
                        s.prediction.objectPocketed ? "进袋✓" : "未进✗")
        let l2 = String(format: "力度 v=%.2f m/s(档≈%@)  加塞 左右=%+.2f 高低=%+.2f  进球点偏移=%+.0fmm  落点误差=%.0fmm  母球残差=%.0fmm  目标球残差=%.0fmm",
                        s.velocity, forceLabel(s.velocity), s.spinX, s.spinY, s.aimOffsetMM, s.restErrMM, s.residualMM, s.objResidualMM)
        let l3 = "灰点=截图母球  暗橙点=截图目标球  青线=引擎母球  橙线=引擎目标球  黄叉=进球点  洋红点=参考落点  青圈=引擎落点"
        drawText(l1, at: CGPoint(x: origin.x + 10, y: origin.y + 6), size: 19, color: .white, bold: true)
        drawText(l2, at: CGPoint(x: origin.x + 10, y: origin.y + 30),
                 size: 13, color: s.prediction.objectPocketed ? .systemGreen : .systemOrange)
        drawText(l3, at: CGPoint(x: origin.x + 10, y: origin.y + h - 18), size: 11, color: UIColor(white: 0.7, alpha: 1))
    }

    private func strokePath(_ cg: CGContext, _ pts: [CGPoint], color: UIColor, width: CGFloat) {
        guard pts.count >= 2 else { return }
        cg.setStrokeColor(color.cgColor); cg.setLineWidth(width); cg.setLineJoin(.round)
        cg.beginPath(); cg.move(to: pts[0])
        for p in pts.dropFirst() { cg.addLine(to: p) }
        cg.strokePath()
    }

    private func drawText(_ s: String, at p: CGPoint, size: CGFloat, color: UIColor, bold: Bool = false) {
        (s as NSString).draw(at: p, withAttributes: [
            .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
            .foregroundColor: color,
        ])
    }
}
