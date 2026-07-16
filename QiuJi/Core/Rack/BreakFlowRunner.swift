import Foundation
import SceneKit
import SwiftUI
import Combine

/// 内置开球流程（T-P18-47，设计稿 §3.3-⑨/§5-6）：球形生成器页下线后，其「摆架 →
/// 开球区拖母球 → 真实物理开球 → 散局就地落座」闭环下沉为可嵌入任意场景页的共享 runner。
///
/// 宿主契约（编排台 / 思路训练器 / 打一走二想三）：
/// 1. 宿主创建 runner 并 `rackUp()`（会清台摆架，宿主应先自存 `currentSnapshot()` 供取消恢复）；
/// 2. 开球模式期间把拖拽路由到 `draggableCue`/`dragBegan/Moved/Ended`，其余台面交互挂起；
/// 3. 主按钮调 `breakNow()`；停稳后 runner 回调 `onSettled(board)`，宿主 `loadBoard` 落座并销毁 runner；
/// 4. 取消调 `cancel()` 后由宿主恢复进场前球形。
///
/// 逻辑迁自 `RackGeneratorViewModel`（ADR-P17-01，WYSIWYG：废局只提示不筛选，「换一局」换 seed）。
@MainActor
final class BreakFlowRunner: ObservableObject {

    enum Phase: Equatable {
        /// 球架摆好、母球可拖、待开球。
        case racked
        /// 物理求解中（后台）。
        case computing
        /// 开球动画回放中。
        case breaking
        /// 已停稳待确认（仅 `autoDeliverOnSettle == false`）：可「重开」换局或「完成」落座。
        case settled
    }

    /// 内置开球可选玩法（Z7 玩法选择 sheet 选项，斯诺克不加——用户拍板）。
    static let gameOptions: [(title: String, game: RackGame)] = [
        ("中式八球", .chineseEightBall),
        ("9 球", .nineBall),
        ("6 球", .zhuifen(balls: 6)),
        ("5 球", .zhuifen(balls: 5)),
        ("4 球", .zhuifen(balls: 4)),
    ]

    /// 玩法显示名（顶部信息行 pill 用）。
    static func title(for game: RackGame) -> String {
        gameOptions.first(where: { $0.game == game })?.title ?? "\(game.ballCount) 球"
    }

    /// 开球默认杆头速度 (m/s)：G18（问题集合 v5·V6）——默认 6.0（替代固定 7.0），
    /// 经右侧力度条 `BTShotInstrumentColumn` 可调，参与开球速度。
    static let defaultBreakVelocity: Double = 6.0

    let game: RackGame
    @Published private(set) var phase: Phase = .racked
    @Published private(set) var statusText = "拖屏调方向 · 拖母球定开球点 · 点「开球」散局"

    /// 开球杆头速度 (m/s)：右侧力度柱绑定（G18）。默认 6.0，量程沿用 `ShotTuning.velocityRange`。
    @Published var velocity: Double = BreakFlowRunner.defaultBreakVelocity

    /// 当前开球瞄准方向（XZ 单位向量，SceneKit 世界系）。nil 时以「锁顶球」兜底。
    /// G18：默认锁顶球，用户可拖屏（G13 相对语义）或左侧刻度轮调整。
    @Published private(set) var aimDir: SCNVector3?
    /// 用户是否手动调过瞄准。false = 自动锁顶球（母球移动即重瞄顶角）；一旦手动调过则固定方向。
    private var aimManuallyAdjusted = false

    /// 底部条主按钮是否显示为「完成」（仅手动交付宿主、且已停稳时）。
    var showsConfirm: Bool { phase == .settled && !autoDeliverOnSettle }

    /// 停稳交付：散开球形（刮杆已补回开球区）。宿主负责 loadBoard + 销毁 runner。
    var onSettled: ((BoardSnapshot) -> Void)?

    /// 停稳后是否立即交付宿主（老宿主行为）。自由击球页（条 15.8/15.9）设 false：
    /// 停稳进 `.settled`，用户可「重开」换局或点「完成」手动送入击打阶段。
    var autoDeliverOnSettle = true
    /// `.settled` 阶段暂存的散局（等待「完成」交付）。
    private var settledBoard: BoardSnapshot?

    var isBusy: Bool { phase == .computing || phase == .breaking }

    private unowned let scene: AngleTrainingScene
    private var rack: Rack
    private var seed: UInt64 = 1
    private var aimNodes: [SCNNode] = []
    private let breakQueue = DispatchQueue(label: "com.qiuji.break-flow", qos: .userInitiated)
    private var breakGeneration = 0
    private var breakFinishTask: Task<Void, Never>?
    private var surfaceY: Float { scene.surfaceY }
    private var allKeys: [String] { [PositionPlayBall.cueKey] + rack.balls.map { $0.key } }

    init(scene: AngleTrainingScene, game: RackGame) {
        self.scene = scene
        self.game = game
        self.rack = RackLayout.make(game, seed: 1, surfaceY: scene.surfaceY)
    }

    // MARK: - Rack

    /// 清台摆架：按玩法 + 当前 seed 摆球架，母球落默认开球点，画锁顶球瞄准线。
    func rackUp() {
        cancelPlayback()
        settledBoard = nil
        rack = RackLayout.make(game, seed: seed, surfaceY: surfaceY)
        scene.hideAllBalls()
        for b in rack.balls { scene.showBall(key: b.key, scenePosition: b.position) }
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: rack.cue)
        phase = .racked
        statusText = "拖屏调方向 · 拖母球定开球点 · 点「开球」散局"
        // G18：每次摆架回到「自动锁顶球」默认瞄准（用户随后可拖屏/刻度轮微调）。
        aimManuallyAdjusted = false
        aimDir = BreakSimulator.aimAtApex(rack: rack, from: rack.cue)
        drawAimLine()
    }

    /// 当前生效的开球瞄准方向：用户调过则用 `aimDir`，否则实时锁顶球（随母球位置）。
    private func resolvedAim(cuePos: SCNVector3) -> SCNVector3 {
        aimDir ?? BreakSimulator.aimAtApex(rack: rack, from: cuePos)
    }

    // MARK: - Cue dragging

    var draggableCue: [SCNNode] {
        guard phase == .racked,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return [] }
        return [cue]
    }

    func dragBegan(node: SCNNode) {
        guard phase == .racked else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard phase == .racked else { return }
        node.position = clampToBreakBox(worldPosition)
        // 未手动调向时，母球移动即重锁顶球（默认瞄准跟随开球点）；已手动调向则保持绝对方向。
        if !aimManuallyAdjusted {
            aimDir = BreakSimulator.aimAtApex(rack: rack, from: node.position)
        }
        drawAimLine()
    }

    // MARK: - Aim adjustment（G18：开放瞄准方向，遵循 G13 相对调整语义）

    /// 相对微调开球瞄准方向：`delta > 0` = 屏幕顺时针（向右）旋转。
    /// 台面空白处拖屏（`onAimNudged`，绕母球公转增益）与左缘刻度轮（`BTAimWheel`）共用本入口，
    /// 均为对**当前**方向的增量旋转（第一落点只选中不转向由手势层保证，见 `AngleSceneView`）。
    func nudgeAim(byDegrees delta: Float) {
        guard phase == .racked, abs(delta) > 1e-4 else { return }
        let cuePos = scene.allBallNodes[PositionPlayBall.cueKey]?.position ?? rack.cue
        let base = resolvedAim(cuePos: cuePos)
        aimDir = AngleSceneCalculator.rotatedAim(base, byDegrees: delta)
        aimManuallyAdjusted = true
        drawAimLine()
    }

    func dragEnded(node: SCNNode) {
        guard phase == .racked else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        drawAimLine()
    }

    /// 母球钳在开球区（厨房半区）并避开袋口。
    private func clampToBreakBox(_ pos: SCNVector3) -> SCNVector3 {
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let headLine = AngleSceneCalculator.innerLength / 4
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        p.x = max(headLine, min(halfL - r, p.x))
        p.z = max(-halfW + r, min(halfW - r, p.z))
        return SCNVector3(p.x, surfaceY + r, p.z)
    }

    // MARK: - Aim line（锁顶球瞄准可视化，§1.2：对照白 + 方向绿）

    private func drawAimLine() {
        scene.clearResultNodes(nodes: &aimNodes)
        guard phase == .racked,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return }
        // G18：沿当前（可调）瞄准方向画线——前段淡绿对照线延伸到库内边界、
        // 后段实线尾巴表示母球来向（同其他击打页瞄准语言）。
        let dir = resolvedAim(cuePos: cue.position)
        let forward = AngleSceneCalculator.rayToInnerRail(from: cue.position, dir: dir)
        aimNodes.append(scene.addLine(from: cue.position, to: forward,
                                      color: TrajectoryStyle.hintColor.withAlphaComponent(0.5),
                                      radius: TrajectoryStyle.lineHint))
        let tail = SCNVector3(cue.position.x - dir.x * AngleSceneCalculator.ballRadius * 2,
                              cue.position.y,
                              cue.position.z - dir.z * AngleSceneCalculator.ballRadius * 2)
        aimNodes.append(scene.addLine(from: tail, to: cue.position,
                                      color: TrajectoryStyle.contactColor.withAlphaComponent(0.85),
                                      radius: TrajectoryStyle.lineMain))
    }

    // MARK: - Break

    func breakNow() {
        guard phase == .racked,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden else { return }
        let cuePos = cueNode.position
        let theRack = rack
        // G18：无随机塞——开球确定性由「瞄准方向 + 力度」用户控制，随机性只保留球堆间距（RackLayout jitter）。
        let aim = resolvedAim(cuePos: cuePos)
        let power = Float(velocity)
        breakGeneration += 1
        let gen = breakGeneration
        phase = .computing
        statusText = "开球计算中…"
        scene.clearResultNodes(nodes: &aimNodes)

        breakQueue.async { [weak self] in
            let result = BreakSimulator.breakShot(
                rack: theRack, cuePosition: cuePos, aimDirection: aim, power: power,
                spinX: 0, spinY: 0)
            DispatchQueue.main.async {
                guard let self, self.breakGeneration == gen, self.phase == .computing else { return }
                self.startPlayback(result)
            }
        }
    }

    private func startPlayback(_ result: BreakResult) {
        phase = .breaking
        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden else {
            runBreakMotion(result)
            return
        }
        statusText = "运杆…"
        let aim = resolvedAim(cuePos: cueNode.position)
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: 0)
        scene.runCueStroke(strikePosition: strikePos, aim: aim,
                           velocity: Float(velocity)) { [weak self] in
            guard let self, self.phase == .breaking else { return }
            self.runBreakMotion(result)
        }
    }

    private func runBreakMotion(_ result: BreakResult) {
        statusText = "开球中…"
        let playback = TrajectoryPlayback(recorder: result.recorder,
                                          surfaceY: surfaceY + AngleSceneCalculator.ballRadius)
        for key in allKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            if let action = playback.action(for: node, ballName: key, speed: 1.0, removeOnPocket: false) {
                node.runAction(action)
            }
        }
        // G15：开球收尾等到引擎自然静止（不做 0.07 感知截断），球停止前无最后一跳/瞬移。
        let settle = playback.duration
        let tail: TimeInterval = result.pocketed.isEmpty ? 0.15
            : TrajectoryPlayback.pocketSettleDuration + 0.15
        let finishAfter = max(0.05, TimeInterval(settle) + tail)
        breakFinishTask?.cancel()
        breakFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(finishAfter * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishBreak(result)
        }
    }

    /// 收尾：进袋球离场、存活球钉终点、刮杆补回开球区，然后把散开板交付宿主。
    private func finishBreak(_ result: BreakResult) {
        guard phase == .breaking else { return }
        for key in allKeys { scene.allBallNodes[key]?.removeAllActions() }
        for key in result.pocketed { scene.hideBall(key: key) }

        var board = result.board
        for (key, pt) in board.onTable {
            let pos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY)
            scene.showBall(key: key, scenePosition: pos)
        }
        if result.cueScratched {
            scene.showBall(key: PositionPlayBall.cueKey, scenePosition: rack.cue)
            let c = AngleSceneCalculator.sceneToNormalized(position: rack.cue)
            board.onTable[PositionPlayBall.cueKey] = CanvasPoint(x: Double(c.x), y: Double(c.y))
        }
        if autoDeliverOnSettle {
            statusText = settledHint(result)
            onSettled?(board)
        } else {
            // 条 15.8/15.9：停稳不自动进击打阶段——「重开」换局 / 「完成」手动交付。
            settledBoard = board
            phase = .settled
            statusText = settledHint(result) + " · 点「完成」进入击打，或「重开」换局"
        }
    }

    /// 「重开」（G18 统一：合并原「换一局」+「重开」为单一语义）：换 seed 重摆——
    /// 重新洗球号 + 重新扰动球堆间距（`RackLayout` jitter）。`.racked` 与 `.settled` 均可用。
    func reRack() {
        guard phase == .settled || phase == .racked else { return }
        seed &+= 1
        rackUp()
    }

    /// 「完成」（条 15.9）：把停稳散局交付宿主，进入击打阶段。
    func confirmSettled() {
        guard phase == .settled, let board = settledBoard else { return }
        settledBoard = nil
        onSettled?(board)
    }

    /// 取消开球模式：停动画、清瞄准线。桌面恢复由宿主负责（回填进场前球形）。
    func cancel() {
        cancelPlayback()
        scene.clearResultNodes(nodes: &aimNodes)
    }

    private func cancelPlayback() {
        breakGeneration += 1
        breakFinishTask?.cancel()
        breakFinishTask = nil
        for key in allKeys { scene.allBallNodes[key]?.removeAllActions() }
    }

    private func settledHint(_ result: BreakResult) -> String {
        if result.eightOnBreak { return "8 号开球落袋（按规则废局）· 可换一局重开" }
        if result.cueScratched { return "母球进袋（刮杆）· 已补回开球区" }
        return "已停稳"
    }
}

// MARK: - 开球模式底部条（四宿主唯一共享条，G18/V6：取消 / 重开 / 开球|完成）
//
// 收敛原 `BreakControlBar`（自动交付宿主：Silu/PlanThree/Composer）与 FreePlay 私有
// `FreePlayBreakBar`（手动交付）为单一真源。按钮语义（问题集合 v5·G18-5）：
// - **取消**：退出开球模式，宿主恢复进场前球形（恒在最左）。
// - **重开**：换 seed 重摆（= 原「换一局」+「重开」合并语义：重洗球号 + 重扰球堆间距），
//   `.racked`/`.settled` 均可用（次级按钮）。
// - **主按钮**：需手动交付（`autoDeliverOnSettle == false`，自由击球页）且已停稳 ⇒ 显示「完成」
//   （交付击打阶段）；否则显示「开球」（`.racked` 触发散局）。
// 「重开」与「完成」位置互换（相对旧 FreePlayBreakBar：完成移到最右主位、重开在其左）。

struct BreakControlBar: View {
    @ObservedObject var runner: BreakFlowRunner
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button("取消") { onCancel() }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, Spacing.lg)
                .frame(height: 42)
                .background(Color.white.opacity(0.10), in: Capsule())
                .buttonStyle(.plain)
                .disabled(runner.isBusy)

            Spacer(minLength: 0)

            // 重开（次级）：换 seed 重摆——恒显（racked/settled 均可）。
            Button {
                runner.reRack()
            } label: {
                Label("重开", systemImage: "arrow.2.squarepath")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(runner.isBusy)
            .accessibilityIdentifier("break.rerack")

            // 主按钮（最右）：停稳待手动交付 ⇒ 「完成」；否则 ⇒ 「开球」。
            if runner.showsConfirm {
                Button {
                    runner.confirmSettled()
                } label: {
                    Text("完成")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 42)
                        .background(Color.btPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("break.confirm")
            } else {
                Button {
                    runner.breakNow()
                } label: {
                    HStack(spacing: 5) {
                        CueStickShape().frame(width: 15, height: 15).foregroundStyle(.white)
                        Text(runner.isBusy ? "开球中" : "开球")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 92, height: 42)
                    .background(runner.isBusy ? Color.btPrimary.opacity(0.3) : Color.btPrimary,
                                in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(runner.isBusy)
                .accessibilityIdentifier("break.strike")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
    }
}

// MARK: - 开球模式贴边仪表（四宿主共享，G18/V6）
//
// 左侧瞄准刻度轮（`BTAimWheel`，G13 相对调瞄）+ 右侧力度柱（`BTShotInstrumentColumn`，默认 6 m/s）。
// 遵循既有 `ShotStageProxy` 贴边标准（G4/G5/G7：右缘/左缘贴球桌、同底）。宿主开球模式统一叠加，
// 避免逐页复制开球控件逻辑（单一真源）。

struct BreakInstrumentsOverlay: View {
    @ObservedObject var runner: BreakFlowRunner
    let proxy: ShotStageProxy

    var body: some View {
        // 铺满 stage（origin 左上），使内部 `.position` 与球桌矩形同一坐标系 ⇒ 两竖条严格同底（G5）。
        ZStack(alignment: .topLeading) {
            if proxy.isValid {
                // 仅摆架待开球（`.racked`）时可调；计算/回放/停稳期禁用（避免中途改参）。
                let editable = runner.phase == .racked
                let wf = proxy.aimWheelFrame()
                BTAimWheel(onNudge: { runner.nudgeAim(byDegrees: $0) })
                    .frame(width: wf.width, height: wf.height)
                    .position(x: wf.midX, y: wf.midY)
                    .allowsHitTesting(editable)
                    .opacity(editable ? 1 : 0.5)

                let inf = proxy.instrumentFrame()
                BTShotInstrumentColumn(
                    spinX: 0, spinY: 0,
                    velocity: $runner.velocity,
                    range: ShotTuning.velocityRange,
                    isDisabled: !editable
                )
                .frame(width: inf.width, height: inf.height)
                .position(x: inf.midX, y: inf.midY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Z7 玩法选择 sheet（暗材质，§1.6/§4-5）
//
// C32：原 `BreakEntryTile`（球库行首开球块）零消费死代码已删；开球入口统一 `BTBreakSideButton`。

/// 内置开球的玩法选择浮出层：选中即开始摆架。
struct BreakGamePickerSheet: View {
    let onSelect: (RackGame) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("开球玩法")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)

            ForEach(Array(BreakFlowRunner.gameOptions.enumerated()), id: \.offset) { _, option in
                Button {
                    dismiss()
                    onSelect(option.game)
                } label: {
                    HStack {
                        Text(option.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("break.game.\(option.game.ballCount)")
            }

            Text("摆架后可在开球区拖动母球，点「开球」真实物理散局。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.09).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}
