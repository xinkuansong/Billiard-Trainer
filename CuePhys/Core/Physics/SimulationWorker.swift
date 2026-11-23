//
//  SimulationWorker.swift
//  BilliardTrainer
//
//  后台物理模拟任务管理器：统一负责 EventDrivenEngine.simulate() 的提交、取消、结果回传。
//  设计原则：
//    - 纯计算边界：SimulationWorker 仅接收值类型快照，不持有 SCNNode 引用。
//    - 单任务模型：每次提交新任务前先取消上一个，保证不产生结果串台。
//    - 主线程回调：结果/取消回调均在主线程触发，调用方无需关心线程切换。
//    - 可观测性：记录每次任务耗时与取消/丢弃计数，便于性能验证。
//

import Foundation
import SceneKit

// MARK: - SimulationSnapshot

/// 出杆瞬间的物理快照（值类型，跨线程安全传递）
struct SimulationSnapshot {
    let shotId: UInt64
    let ballStates: [BallState]
    let tableGeometry: TableGeometry
    let maxEvents: Int
    let maxTime: Float
}

// MARK: - SimulationResult

/// 模拟完成后的结果（值类型，跨线程安全传递）
struct SimulationResult {
    let shotId: UInt64
    let recorder: TrajectoryRecorder
    let resolvedEvents: [PhysicsEventType]
    let resolvedEventTimes: [Float]
    let firstBallBallCollisionTime: Float?
    /// simulate() 实际耗时（毫秒）
    let elapsedMs: Double
}

// MARK: - SimulationWorker

/// 后台物理模拟任务管理器
///
/// 线程模型：
///   - 公有方法均在主线程调用。
///   - simulate 计算在 `workerQueue`（后台 serial queue）执行。
///   - 结果回调通过 `DispatchQueue.main.async` 发回主线程。
final class SimulationWorker {

    // MARK: - Types

    typealias ResultHandler = (SimulationResult) -> Void
    typealias CancelHandler = (UInt64) -> Void

    // MARK: - Properties

    /// 任务完成时的主线程回调
    var onResult: ResultHandler?
    /// 任务被取消时的主线程回调（携带被取消的 shotId）
    var onCancelled: CancelHandler?

    // MARK: - Private State

    private let workerQueue = DispatchQueue(
        label: "com.billiardtrainer.simulation-worker",
        qos: .userInitiated
    )

    /// 当前任务的取消 token；写入在主线程，读取在 worker 线程（通过 isCancelled 原子标志保护）
    private var currentTask: SimulationTask?

    // MARK: - Observability Counters (主线程访问)

    private(set) var submittedCount: Int = 0
    private(set) var completedCount: Int = 0
    private(set) var cancelledCount: Int = 0
    private(set) var droppedStaleCount: Int = 0

    // MARK: - Public API

    /// 提交一次模拟任务。若存在正在运行的旧任务，先取消再提交。
    ///
    /// - Parameter snapshot: 出杆瞬间的物理状态快照（值类型，不持有 SCNNode）
    func submit(snapshot: SimulationSnapshot) {
        cancelCurrentTask()

        submittedCount += 1
        let task = SimulationTask(shotId: snapshot.shotId)
        currentTask = task

        workerQueue.async { [weak self, weak task] in
            guard let self, let task else { return }
            guard !task.isCancelled else {
                DispatchQueue.main.async {
                    self.cancelledCount += 1
                    self.onCancelled?(snapshot.shotId)
                }
                return
            }

            let startTime = CACurrentMediaTime()
            let engine = EventDrivenEngine(tableGeometry: snapshot.tableGeometry)
            for state in snapshot.ballStates {
                engine.setBall(state)
            }

            engine.simulate(maxEvents: snapshot.maxEvents, maxTime: snapshot.maxTime)

            let elapsedMs = (CACurrentMediaTime() - startTime) * 1000.0

            guard !task.isCancelled else {
                DispatchQueue.main.async {
                    self.cancelledCount += 1
                    self.onCancelled?(snapshot.shotId)
                }
                return
            }

            let result = SimulationResult(
                shotId: snapshot.shotId,
                recorder: engine.getTrajectoryRecorder(),
                resolvedEvents: engine.resolvedEvents,
                resolvedEventTimes: engine.resolvedEventTimes,
                firstBallBallCollisionTime: engine.firstBallBallCollisionTime,
                elapsedMs: elapsedMs
            )

            DispatchQueue.main.async {
                self.completedCount += 1
                self.onResult?(result)
            }
        }
    }

    /// 取消当前正在进行的任务（若有）。
    func cancelCurrentTask() {
        guard let task = currentTask else { return }
        task.cancel()
        currentTask = nil
    }

    /// 记录一次过期结果被丢弃（由调用方在 shotId 不匹配时调用）
    func recordDroppedStale() {
        droppedStaleCount += 1
    }

    // MARK: - Diagnostics

    func printStats() {
        print("[SimulationWorker] submitted=\(submittedCount) completed=\(completedCount) cancelled=\(cancelledCount) droppedStale=\(droppedStaleCount)")
    }
}

// MARK: - SimulationTask

/// 单次任务的取消令牌（在主线程创建，worker 线程读取 isCancelled）
private final class SimulationTask: @unchecked Sendable {
    let shotId: UInt64
    private let _cancelled = AtomicBool()

    init(shotId: UInt64) {
        self.shotId = shotId
    }

    var isCancelled: Bool { _cancelled.value }

    func cancel() { _cancelled.set(true) }
}

// MARK: - AtomicBool

/// 极简原子 Bool，用于跨线程取消标志（替代 Objective-C atomic）
private final class AtomicBool: @unchecked Sendable {
    private var _value: Bool = false
    private let lock = NSLock()

    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return _value
    }

    func set(_ v: Bool) {
        lock.lock(); defer { lock.unlock() }
        _value = v
    }
}
