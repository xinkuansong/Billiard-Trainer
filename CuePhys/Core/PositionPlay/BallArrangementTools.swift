import SwiftUI
import SceneKit

#if DEBUG
/// Diagnostic ring buffer only; the existing audit-only TimelineView reads it.
/// Recording never publishes state or invalidates the live gesture view.
enum BatchNudgeAudit {
    private struct Entry {
        let time: TimeInterval
        let key: String
        let event: String
        var count: Int
    }
    private static var entries: [Entry] = []
    static let enabled = ProcessInfo.processInfo.arguments.contains("-batchAuthor.audit")

    static func record(key: String, event: String) {
        guard enabled else { return }
        if let last = entries.lastIndex(where: { $0.key == key }), entries[last].event == event {
            entries[last].count += 1
        } else {
            entries.append(Entry(time: ProcessInfo.processInfo.systemUptime, key: key, event: event, count: 1))
            if entries.count > 256 { entries.removeFirst(entries.count - 256) }
        }
    }

    static var snapshot: String {
        entries.map { String(format: "%.3f", $0.time) + " " + $0.key + " " + $0.event + " ×" + String($0.count) }
            .joined(separator: "\n")
    }
}
#endif

// MARK: - Scroll-compatible editor nudge

/// A scroll must be distinguishable from a nudge before mutating the ball.
/// Tap commits on release; a stationary 0.4s hold starts the same accelerating
/// 0.5mm action. This local policy leaves non-scrolling shared controls unchanged.
struct BatchScrollNudgeButton: View {
    let icon: String
    let accessibility: String
    let onStep: () -> Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressing = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(isPressing ? 1 : 0.82))
            .frame(width: 30, height: 30)
            .background(isPressing ? HUDStyle.selectedBackground : .white.opacity(0.12), in: Circle())
            .frame(width: 44, height: 44)
            .overlay {
                BatchNudgeGestureSurface(enabled: isEnabled, isPressing: $isPressing, auditKey: icon, onStep: onStep)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if isEnabled { _ = onStep() } }
    }
}

private struct BatchNudgeGestureSurface: UIViewRepresentable {
    let enabled: Bool
    @Binding var isPressing: Bool
    let auditKey: String
    let onStep: () -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.4
        hold.allowableMovement = 10
        // A completed hold must never also commit the release as a single tap.
        tap.require(toFail: hold)
        // Install the same explicit touch gate in normal and diagnostic runs.
        // Audit recording must not alter the recognizers' delegate arrangement.
        tap.delegate = context.coordinator
        hold.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(hold)
        context.coordinator.trace("make view=\(ObjectIdentifier(view))")
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.trace("update view=\(ObjectIdentifier(view)) enabled=\(enabled) states=\((view.gestureRecognizers ?? []).map { "\(type(of: $0)):\($0.state.rawValue):\($0.isEnabled)" }.joined(separator: ","))")
        for gesture in view.gestureRecognizers ?? [] { gesture.isEnabled = enabled }
        if !enabled { context.coordinator.stop() }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.trace("dismantle view=\(ObjectIdentifier(view))")
        coordinator.stop()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: BatchNudgeGestureSurface
        private var timer: Timer?
        private var ticks = 0
        private var repeating = false

        init(parent: BatchNudgeGestureSurface) { self.parent = parent }

        func trace(_ event: @autoclosure () -> String) {
            #if DEBUG
            guard BatchNudgeAudit.enabled else { return }
            BatchNudgeAudit.record(key: parent.auditKey, event: event())
            #endif
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            trace("receive \(type(of: gestureRecognizer)) enabled=\(gestureRecognizer.isEnabled) point=\(touch.location(in: gestureRecognizer.view)) window=\(touch.location(in: nil)) view=\(gestureRecognizer.view.map { String(describing: ObjectIdentifier($0)) } ?? "nil") bounds=\(gestureRecognizer.view?.bounds ?? .zero) frameWindow=\(gestureRecognizer.view.map { $0.convert($0.bounds, to: nil) } ?? .zero)")
            return parent.enabled
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            trace("tap state=\(gesture.state.rawValue) enabled=\(parent.enabled)")
            guard gesture.state == .ended, parent.enabled else { return }
            _ = step()
        }

        @objc func hold(_ gesture: UILongPressGestureRecognizer) {
            trace("hold state=\(gesture.state.rawValue) enabled=\(parent.enabled)")
            switch gesture.state {
            case .began:
                guard parent.enabled else { return }
                repeating = true
                parent.isPressing = true
                if step() { scheduleNext(after: 0.12) } else { stop() }
            case .ended, .cancelled, .failed:
                stop()
            default:
                break
            }
        }

        private func step() -> Bool {
            guard parent.enabled else { return false }
            let moved = parent.onStep()
            trace("step moved=\(moved) repeating=\(repeating) ticks=\(ticks)")
            UIImpactFeedbackGenerator(style: moved ? .light : .rigid)
                .impactOccurred(intensity: moved ? 0.6 : 0.9)
            return moved
        }

        private func scheduleNext(after delay: TimeInterval) {
            timer?.invalidate()
            let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, self.repeating else { return }
                guard self.step() else { self.stop(); return }
                self.ticks += 1
                self.scheduleNext(after: max(0.05, 0.12 - Double(self.ticks) * 0.005))
            }
            timer = next
            RunLoop.main.add(next, forMode: .common)
        }

        func stop() {
            trace("stop repeating=\(repeating) ticks=\(ticks)")
            timer?.invalidate()
            timer = nil
            repeating = false
            ticks = 0
            if parent.isPressing { parent.isPressing = false }
        }
    }
}

// MARK: - 辅助线（条 20.4–20.9）

/// 出片台辅助线状态机：起点/终点两步确认；终点与水平/垂直夹角 < 10° 自动吸附
/// （SceneKit X–Z 台面系：吸附 = 对齐 X 轴向或 Z 轴向）；白色；只存在于场景节点
/// （不进 JSON）；击球时由宿主 `clear` 隐藏。
@MainActor
final class BatchGuideLine: ObservableObject {
    enum Phase: Equatable { case off, pickStart, pickEnd, placed }

    @Published private(set) var phase: Phase = .off
    // P12.1：必须 @Published——「确认」按钮 enabled 依赖 `hasCurrentPoint`，
    // 选点只改这两个属性不改 phase，非 @Published 时视图不重渲、按钮永远禁用。
    @Published private(set) var startPoint: SCNVector3?
    @Published private(set) var endPoint: SCNVector3?
    private var nodes: [SCNNode] = []

    /// 吸附阈值（度）：与水平/垂直夹角小于该值时归为轴向线（条 20.4）。
    static let snapDeg: Float = 10

    var isPicking: Bool { phase == .pickStart || phase == .pickEnd }

    /// 当前阶段是否已有可确认的点。
    var hasCurrentPoint: Bool {
        switch phase {
        case .pickStart: return startPoint != nil
        case .pickEnd: return endPoint != nil
        default: return false
        }
    }

    var hint: String? {
        switch phase {
        case .off, .placed: return nil
        case .pickStart: return startPoint == nil ? "点按球桌选起点" : "可拖动微调起点"
        case .pickEnd: return endPoint == nil ? "点按球桌选终点" : "±10° 自动吸附水平/垂直"
        }
    }

    func setPreviewHidden(_ hidden: Bool) { nodes.forEach { $0.isHidden = hidden } }

    func begin() {
        startPoint = nil
        endPoint = nil
        phase = .pickStart
    }

    /// 取点（世界坐标）：pickStart 设起点，pickEnd 设终点（带轴向吸附）。
    func setPoint(_ world: SCNVector3, scene: AngleTrainingScene) {
        let y = scene.surfaceY + 0.003
        let p = SCNVector3(world.x, y, world.z)
        switch phase {
        case .pickStart:
            startPoint = p
        case .pickEnd:
            guard let a = startPoint else { return }
            endPoint = snapped(end: p, from: a)
        default:
            return
        }
        render(scene: scene)
    }

    /// 确认当前点：起点 → 进入终点阶段；终点 → 定线。返回 true = 辅助线已就位
    /// （宿主随即做一次均分摆球）。
    @discardableResult
    func confirm(scene: AngleTrainingScene) -> Bool {
        switch phase {
        case .pickStart where startPoint != nil:
            phase = .pickEnd
            return false
        case .pickEnd where endPoint != nil:
            phase = .placed
            render(scene: scene)
            return true
        default:
            return false
        }
    }

    func clear(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        startPoint = nil
        endPoint = nil
        phase = .off
    }

    /// 终点吸附：与 X 轴向夹角 < 10° → 对齐起点 Z（水平）；与 Z 轴向夹角 < 10° →
    /// 对齐起点 X（垂直）；其余保留原始终点（条 20.4）。
    private func snapped(end: SCNVector3, from start: SCNVector3) -> SCNVector3 {
        let dx = abs(end.x - start.x)
        let dz = abs(end.z - start.z)
        guard dx > 1e-5 || dz > 1e-5 else { return end }
        let angleToXAxis = atan2f(dz, dx) * 180 / .pi
        if angleToXAxis < Self.snapDeg { return SCNVector3(end.x, end.y, start.z) }
        if angleToXAxis > 90 - Self.snapDeg { return SCNVector3(start.x, end.y, end.z) }
        return end
    }

    /// 渲染：白色细线 + 起/终点小十字（条 20.9）。
    private func render(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        let white = UIColor.white.withAlphaComponent(0.9)
        func cross(_ c: SCNVector3) {
            let r: Float = 0.018
            nodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                       to: SCNVector3(c.x + r, c.y, c.z), color: white, radius: 0.0022, placement: .table))
            nodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                       to: SCNVector3(c.x, c.y, c.z + r), color: white, radius: 0.0022, placement: .table))
        }
        if let a = startPoint { cross(a) }
        if let b = endPoint { cross(b) }
        if let a = startPoint, let b = endPoint {
            nodes.append(scene.addLine(from: a, to: b, color: white, radius: 0.0018, placement: .table))
        }
    }

    /// 均分摆球（条 20.6）：统计球心落在线上（距线段 < 1.2R 且不在端点）的在桌球，
    /// 按沿线投影排序后摆到 i/(n+1) 等分点（端点不放球）。返回 true = 有球被调整。
    func redistribute(keys: [String], scene: AngleTrainingScene) -> Bool {
        let placements = redistributedPositions(positions: currentPositions(keys: keys, scene: scene), surfaceY: scene.surfaceY)
        for (key, position) in placements { scene.allBallNodes[key]?.position = position }
        return !placements.isEmpty
    }

    /// Consumers can validate the entire proposed arrangement before committing any ball.
    func proposedPlacements(keys: [String], scene: AngleTrainingScene) -> [String: SCNVector3] {
        redistributedPositions(positions: currentPositions(keys: keys, scene: scene), surfaceY: scene.surfaceY)
    }

    func previewPlacement(key: String, position: SCNVector3, keys: [String], scene: AngleTrainingScene) -> SCNVector3 {
        var positions = currentPositions(keys: keys, scene: scene)
        positions[key] = position
        return redistributedPositions(positions: positions, surfaceY: scene.surfaceY)[key] ?? position
    }

    private func currentPositions(keys: [String], scene: AngleTrainingScene) -> [String: SCNVector3] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            guard let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return (key, node.position)
        })
    }

    private func redistributedPositions(positions: [String: SCNVector3], surfaceY: Float) -> [String: SCNVector3] {
        guard phase == .placed, let a = startPoint, let b = endPoint else { return [:] }
        let abx = b.x - a.x, abz = b.z - a.z
        let len2 = abx * abx + abz * abz
        guard len2 > 1e-6 else { return [:] }
        let r = AngleSceneCalculator.ballRadius

        var onLine: [(key: String, t: Float)] = []
        for (key, position) in positions {
            let px = position.x - a.x, pz = position.z - a.z
            let t = (px * abx + pz * abz) / len2
            guard t > 0.02, t < 0.98 else { continue }        // 端点不算
            let cx = a.x + abx * t, cz = a.z + abz * t
            let dx = position.x - cx, dz = position.z - cz
            if sqrtf(dx * dx + dz * dz) < r * 1.2 { onLine.append((key, t)) }
        }
        guard !onLine.isEmpty else { return [:] }

        onLine.sort { $0.t == $1.t ? $0.key < $1.key : $0.t < $1.t }
        let n = onLine.count
        let y = surfaceY + r
        var result: [String: SCNVector3] = [:]
        for (i, item) in onLine.enumerated() {
            let f = Float(i + 1) / Float(n + 1)
            result[item.key] =
                SCNVector3(a.x + abx * f, y, a.z + abz * f)
        }
        return result
    }
}
