//
//  PerformanceProfiler.swift
//  BilliardTrainer
//
//  轻量级性能插桩工具——仅在 DEBUG 构建下生效，Release 下零开销。
//
//  使用方式：
//    PerformanceProfiler.begin("simulate")
//    engine.simulate(...)
//    PerformanceProfiler.end("simulate")
//
//    // 单次函数计时快捷方式
//    let result = PerformanceProfiler.measure("findNextEvent") { findNextEvent() }
//
//    // 读取报告
//    PerformanceProfiler.printReport()
//    PerformanceProfiler.reset()
//

import Foundation
import QuartzCore
import os.log

// MARK: - PerformanceProfiler

final class PerformanceProfiler {

    // MARK: - Types

    struct SectionStats {
        let label: String
        var callCount: Int = 0
        var totalMs: Double = 0
        var minMs: Double = .infinity
        var maxMs: Double = 0
        var lastMs: Double = 0

        var avgMs: Double { callCount > 0 ? totalMs / Double(callCount) : 0 }

        mutating func record(_ ms: Double) {
            callCount += 1
            totalMs += ms
            lastMs = ms
            if ms < minMs { minMs = ms }
            if ms > maxMs { maxMs = ms }
        }
    }

    // MARK: - Singleton

    static let shared = PerformanceProfiler()
    private init() {}

    // MARK: - State

    private var pendingStarts: [String: CFTimeInterval] = [:]
    private var stats: [String: SectionStats] = [:]
    private let lock = NSLock()

    // MARK: - Public API

    /// 开始计时
    static func begin(_ label: String) {
#if DEBUG
        shared.lock.lock()
        shared.pendingStarts[label] = CACurrentMediaTime()
        shared.lock.unlock()
#endif
    }

    /// 结束计时并记录
    @discardableResult
    static func end(_ label: String) -> Double {
#if DEBUG
        let endTime = CACurrentMediaTime()
        shared.lock.lock()
        defer { shared.lock.unlock() }
        guard let startTime = shared.pendingStarts.removeValue(forKey: label) else { return 0 }
        let ms = (endTime - startTime) * 1000.0
        if shared.stats[label] == nil {
            shared.stats[label] = SectionStats(label: label)
        }
        shared.stats[label]!.record(ms)
        return ms
#else
        return 0
#endif
    }

    /// 对一个返回值的闭包进行计时
    @discardableResult
    static func measure<T>(_ label: String, block: () -> T) -> T {
#if DEBUG
        begin(label)
        let result = block()
        end(label)
        return result
#else
        return block()
#endif
    }

    /// 对一个无返回值的闭包进行计时
    static func measure(_ label: String, block: () -> Void) {
#if DEBUG
        begin(label)
        block()
        end(label)
#else
        block()
#endif
    }

    /// 线程安全地记录一个外部测得的耗时样本（ms）。
    /// 与 `begin`/`end` 的区别：`begin`/`end` 共享同一 label 的挂起时刻，**并发调用会互相覆盖**；
    /// 并发热点（`DispatchQueue.concurrentPerform` 内）应在调用方本地计时后用本方法累计。
    static func recordSample(_ label: String, ms: Double) {
#if DEBUG
        shared.lock.lock()
        defer { shared.lock.unlock() }
        if shared.stats[label] == nil {
            shared.stats[label] = SectionStats(label: label)
        }
        shared.stats[label]!.record(ms)
#endif
    }

    /// 对闭包本地计时并以 `recordSample` 累计（并发安全），返回闭包结果。
    @discardableResult
    static func measureSample<T>(_ label: String, block: () -> T) -> T {
#if DEBUG
        let t0 = CACurrentMediaTime()
        let result = block()
        recordSample(label, ms: (CACurrentMediaTime() - t0) * 1000.0)
        return result
#else
        return block()
#endif
    }

    // MARK: - Reporting

    private static let reportLogger = Logger(subsystem: "com.billiardtrainer", category: "Profiler")

    /// 打印所有已收集区段的统计报告（通过 Logger 输出，可在 Console.app 查看）
    static func printReport(tag: String = "PerformanceProfiler") {
#if DEBUG
        shared.lock.lock()
        let snapshot = shared.stats
        shared.lock.unlock()

        guard !snapshot.isEmpty else { return }

        let sorted = snapshot.values.sorted { $0.label < $1.label }
        var lines: [String] = ["[Profiler:\(tag)]  区段                                    次数    总计ms    均值ms    最小ms    最大ms"]
        for s in sorted {
            let minStr: String = s.minMs == .infinity ? "    —" : String(format: "%9.2f", s.minMs)
            let row = String(
                format: "  %-40@ %6d %9.2f %9.2f %@ %9.2f",
                s.label as NSString,
                s.callCount,
                s.totalMs,
                s.avgMs,
                minStr as NSString,
                s.maxMs
            )
            lines.append(row)
        }
        reportLogger.info("\(lines.joined(separator: "\n"), privacy: .public)")
#endif
    }

    /// 获取某区段最近一次耗时（ms），供实时 HUD 展示
    static func lastMs(for label: String) -> Double {
#if DEBUG
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared.stats[label]?.lastMs ?? 0
#else
        return 0
#endif
    }

    /// 获取某区段调用次数
    static func callCount(for label: String) -> Int {
#if DEBUG
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared.stats[label]?.callCount ?? 0
#else
        return 0
#endif
    }

    /// 返回统计报告纯文本（测试输出用；DEBUG 之外返回空串）。
    static func reportText() -> String {
#if DEBUG
        shared.lock.lock()
        let snapshot = shared.stats
        shared.lock.unlock()
        guard !snapshot.isEmpty else { return "" }
        let sorted = snapshot.values.sorted { $0.totalMs > $1.totalMs }
        var lines: [String] = [String(format: "  %-36@ %6@ %10@ %9@ %9@ %9@",
                                      "区段" as NSString, "次数" as NSString, "总计ms" as NSString,
                                      "均值ms" as NSString, "最小ms" as NSString, "最大ms" as NSString)]
        for s in sorted {
            let minStr: String = s.minMs == .infinity ? "    —" : String(format: "%9.2f", s.minMs)
            lines.append(String(
                format: "  %-36@ %6d %10.1f %9.2f %@ %9.2f",
                s.label as NSString, s.callCount, s.totalMs, s.avgMs, minStr as NSString, s.maxMs))
        }
        return lines.joined(separator: "\n")
#else
        return ""
#endif
    }

    /// 重置所有统计数据
    static func reset() {
#if DEBUG
        shared.lock.lock()
        shared.stats.removeAll()
        shared.pendingStarts.removeAll()
        shared.lock.unlock()
#endif
    }
}

// MARK: - ProfilerLabels

/// 统一管理所有插桩标签，避免字符串拼写错误
enum ProfilerLabel {
    // 物理模拟
    static let simulate         = "Physics.simulate"
    static let findNextEvent    = "Physics.findNextEvent"
    static let ballBallDetect   = "Physics.ballBall.detect"
    static let cushionDetect    = "Physics.cushion.detect"
    static let evolveAllBalls   = "Physics.evolveAllBalls"
    static let resolveEvent     = "Physics.resolveEvent"

    // 渲染 / 回放
    static let renderUpdate     = "Render.renderUpdate"
    static let playbackFrame    = "Render.playbackFrame"
    static let stateAt          = "Render.stateAt"
    static let aimLineUpdate    = "Render.aimLineUpdate"
    static let trajectoryPreview = "Render.trajectoryPreview"
    static let cueStickUpdate   = "Render.cueStickUpdate"
    static let qualitySync      = "Render.qualitySync"
    static let shadowUpdate     = "Render.shadowUpdate"
    static let cameraUpdate     = "Render.cameraUpdate"

    // 灯光 / 环境
    static let iblApply         = "Lighting.iblApply"
    static let lightSettings    = "Lighting.lightSettings"
    static let cameraSettings   = "Lighting.cameraSettings"
    static let reapplyMaterials = "Lighting.reapplyMaterials"
    static let reapplyLights    = "Lighting.reapplyLights"
    static let reapplyCamera    = "Lighting.reapplyCamera"

    // 摄像机约束
    static let hitTest          = "Camera.hitTest"

    // 击球流程
    static let executeStroke    = "Shot.executeStroke"
    static let buildEngine      = "Shot.buildEngine"
    static let applyResult      = "Shot.applyResult"

    // 反解求解器分段（B0 基线；并发热点一律用 recordSample/measureSample）
    static let solverAimMemo        = "Solver.aimMemoization"       // 候选矩阵 ① 瞄准记忆化（外层墙钟）
    static let solverCandidateEval  = "Solver.candidateEval"        // 候选矩阵 ② 全候选评估（外层墙钟）
    static let solverRefine         = "Solver.refine"               // 情形 A 局部精修（每桶代表解一次）
    static let solverPassInfo       = "Solver.passInfo"             // 情形 B 过点回放采样（每候选）
    static let predictorRunShot     = "Predictor.runShot"           // 单次事件模拟（含瞄准短模拟）
    static let predictorPostProcess = "Predictor.postProcess"       // buildPrediction/simulateFree 后处理（polyline 等）
    static let predictorSimFreeEngine = "Predictor.simulateFree.engine" // simulateFree 引擎模拟段
}
