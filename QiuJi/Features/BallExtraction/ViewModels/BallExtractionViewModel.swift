//
//  BallExtractionViewModel.swift
//  QiuJi
//
//  拍照建球形（P15 阶段 1 竖切，ADR-P15-01）。
//
//  非 DL 几何链路：拍照 → 手动标定台面四角 → 解单应 H →
//  在照片上点标每颗球（指定号码，经 H 映射到归一化台面系）→
//  在 2D 真台（复用 `AngleTrainingScene`）上人工确认/微调/增删/改号 →
//  产出 `BoardSnapshot`，复用走位/思路/出片管线。
//
//  「人工确认是一等公民」：四角、球位、球号、增减全部可由用户改定；
//  识别（阶段 2/3）只为各步提供初值，最终真相以确认页为准。
//

import Foundation
import SwiftUI
import SceneKit

@MainActor
final class BallExtractionViewModel: ObservableObject {

    // MARK: - Flow

    enum Step: Int, CaseIterable {
        case pickPhoto   // 选图
        case calibrate   // 标定四角
        case markBalls   // 照片上标球
        case confirm     // 2D 台确认

        var title: String {
            switch self {
            case .pickPhoto: "选择照片"
            case .calibrate: "对齐台面四角"
            case .markBalls: "标记球与号码"
            case .confirm: "确认球形"
            }
        }
    }

    @Published var step: Step = .pickPhoto

    // MARK: - Photo + calibration

    @Published var image: UIImage?

    /// 台面四角，存图像归一化 uv ∈ [0,1]（与显示尺寸无关）。
    /// 顺序固定：左上 / 右上 / 右下 / 左下。
    @Published var corners: [CGPoint] = BallExtractionViewModel.defaultCorners

    static let defaultCorners: [CGPoint] = [
        CGPoint(x: 0.20, y: 0.25),
        CGPoint(x: 0.80, y: 0.25),
        CGPoint(x: 0.92, y: 0.80),
        CGPoint(x: 0.08, y: 0.80)
    ]

    /// 台面长轴在照片中的朝向。2:1 台面唯一的方向歧义：透视下"哪条边是长库"
    /// 无法可靠自动判别，由用户在标定页二选一指定。
    enum TableOrientation {
        /// 离镜头最近的边（照片底边）是**长库** → 长轴水平（默认，常规俯拍）。
        case longRailNear
        /// 最近的边是**短库**（端拍）→ 长轴竖直。
        case shortRailNear
    }

    @Published var orientation: TableOrientation = .longRailNear

    /// 把用户标的四角（固定视觉序：左上/右上/右下/左下）按朝向旋转到与
    /// `Homography.tableCorners` 对齐的源序。短库朝向 = 循环移三位（长轴转竖直
    /// 且与拍摄方向同向；移一位会差 180°）；循环移位保持环绕方向，不引入镜像。
    private var orientedCorners: [CGPoint] {
        switch orientation {
        case .longRailNear: return corners
        case .shortRailNear: return [corners[3], corners[0], corners[1], corners[2]]
        }
    }

    /// 由四角解出的单应（图像 uv → 归一化台面系）。四角退化时为 nil。
    var homography: Homography? {
        Homography.solve(source: orientedCorners, dest: Homography.tableCorners)
    }

    /// 标定质量自检：四角映回台面系的最大残差（归一化单位）。
    var calibrationResidual: CGFloat {
        homography?.cornerResidual(source: orientedCorners, dest: Homography.tableCorners)
            ?? .greatestFiniteMagnitude
    }

    var calibrationValid: Bool {
        // 残差应 ≈ 0（精确解）；退化四边形 homography == nil。
        homography != nil && calibrationResidual < 1e-6
    }

    // MARK: - Photo ball marks

    struct Mark: Identifiable, Equatable {
        let id = UUID()
        var key: String      // cueBall / _1.._15
        var uv: CGPoint      // 图像归一化坐标（球底接触点）
    }

    @Published var marks: [Mark] = []
    /// 当前在球库选中的「待标球号」。点照片即以该号落一个标记。
    @Published var activePaletteKey: String = PositionPlayBall.cueKey

    /// 未被标记的球键（球库展示序：母球、1…15）。
    var unmarkedKeys: [String] {
        let used = Set(marks.map(\.key))
        return PositionPlayBall.allKeys.filter { !used.contains($0) }
    }

    /// 在照片上落/移一个标记：同号只保留一个。
    func placeMark(at uv: CGPoint) {
        let clamped = CGPoint(x: min(max(uv.x, 0), 1), y: min(max(uv.y, 0), 1))
        if let idx = marks.firstIndex(where: { $0.key == activePaletteKey }) {
            marks[idx].uv = clamped
        } else {
            marks.append(Mark(key: activePaletteKey, uv: clamped))
        }
        advanceActiveKey()
        pushMarkHistory()
    }

    /// 拖动中连续调用，不入历史；历史在 `endMarkDrag()`（拖动结束）提交一次。
    func moveMark(id: UUID, to uv: CGPoint) {
        guard let idx = marks.firstIndex(where: { $0.id == id }) else { return }
        marks[idx].uv = CGPoint(x: min(max(uv.x, 0), 1), y: min(max(uv.y, 0), 1))
    }

    /// 标记拖动结束：若位置较上一历史确实变化，提交一步历史。
    func endMarkDrag() {
        guard step == .markBalls else { return }
        if markCursor >= 0, markCursor < markHistory.count, markHistory[markCursor] == marks { return }
        pushMarkHistory()
    }

    func removeMark(id: UUID) {
        guard let idx = marks.firstIndex(where: { $0.id == id }) else { return }
        let key = marks[idx].key
        marks.remove(at: idx)
        activePaletteKey = key
        pushMarkHistory()
    }

    /// 落一个标记后，自动把「待标球号」推进到下一颗未标球，连点更顺手。
    private func advanceActiveKey() {
        if let next = unmarkedKeys.first {
            activePaletteKey = next
        }
    }

    // MARK: - Undo / Redo（撤销=回上一步移动，前进=还原下一步）

    /// 两步各自独立的操作历史栈：cursor 指向当前状态；> 0 才能撤销，< 末尾才能前进。
    /// 历史「一步」= 一次完成的编辑（落子 / 拖动结束 / 删除 / 增球 / 改号）。
    private var markHistory: [[Mark]] = []
    @Published private(set) var markCursor = -1
    private var confirmHistory: [BoardSnapshot] = []
    @Published private(set) var confirmCursor = -1

    /// 当前步是否可撤销 / 前进（供右侧箭头按钮启用态）。
    var canUndo: Bool {
        switch step {
        case .markBalls: return markCursor > 0
        case .confirm: return confirmCursor > 0
        default: return false
        }
    }
    var canRedo: Bool {
        switch step {
        case .markBalls: return markCursor >= 0 && markCursor < markHistory.count - 1
        case .confirm: return confirmCursor >= 0 && confirmCursor < confirmHistory.count - 1
        default: return false
        }
    }

    func undo() {
        switch step {
        case .markBalls:
            guard markCursor > 0 else { return }
            markCursor -= 1
            marks = markHistory[markCursor]
        case .confirm:
            guard confirmCursor > 0 else { return }
            confirmCursor -= 1
            applyConfirmState(confirmHistory[confirmCursor])
        default: break
        }
    }

    func redo() {
        switch step {
        case .markBalls:
            guard markCursor < markHistory.count - 1 else { return }
            markCursor += 1
            marks = markHistory[markCursor]
        case .confirm:
            guard confirmCursor < confirmHistory.count - 1 else { return }
            confirmCursor += 1
            applyConfirmState(confirmHistory[confirmCursor])
        default: break
        }
    }

    /// 进入建球形步：以当前标记为历史初态（首步无法撤销）。
    func enterMarkBalls() {
        step = .markBalls
        markHistory = [marks]
        markCursor = 0
    }

    /// 提交一步建球形历史：截断已撤销的「前进」分支，追加当前状态。
    private func pushMarkHistory() {
        guard step == .markBalls else { return }
        if markCursor >= 0, markCursor < markHistory.count - 1 {
            markHistory.removeSubrange((markCursor + 1)...)
        }
        markHistory.append(marks)
        markCursor = markHistory.count - 1
    }

    private func applyConfirmState(_ snapshot: BoardSnapshot) {
        loadSnapshot(snapshot)
    }

    /// 提交一步确认页历史：截断「前进」分支，追加当前桌面快照。
    private func pushConfirmHistory() {
        guard step == .confirm else { return }
        if confirmCursor >= 0, confirmCursor < confirmHistory.count - 1 {
            confirmHistory.removeSubrange((confirmCursor + 1)...)
        }
        confirmHistory.append(currentSnapshot())
        confirmCursor = confirmHistory.count - 1
    }

    private func boardsEqual(_ a: BoardSnapshot, _ b: BoardSnapshot) -> Bool {
        guard a.onTable.count == b.onTable.count else { return false }
        for (k, v) in a.onTable {
            guard let w = b.onTable[k], abs(v.x - w.x) < 1e-6, abs(v.y - w.y) < 1e-6 else { return false }
        }
        return true
    }

    /// 由照片标记经 H 生成归一化球形。
    func snapshotFromMarks() -> BoardSnapshot {
        guard let h = homography else { return BoardSnapshot() }
        var dict: [String: CanvasPoint] = [:]
        for m in marks {
            let t = h.apply(m.uv)
            dict[m.key] = CanvasPoint(
                x: Double(min(max(t.x, 0), 1)),
                y: Double(min(max(t.y, 0), 0.5))
            )
        }
        return BoardSnapshot(onTable: dict)
    }

    // MARK: - Confirm scene (复用 AngleTrainingScene)

    let scene = AngleTrainingScene()
    @Published private(set) var onTableKeys: [String] = []
    @Published var selectedKey: String? {
        didSet { if oldValue != selectedKey { refreshSelectionRing() } }
    }
    @Published var message: String?
    private var selectionNodes: [SCNNode] = []

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲提示位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard let node = scene.allBallNodes[key], !node.isHidden else { return }
        node.removeAction(forKey: "libraryPulse")
        let up = SCNAction.scale(to: 1.7, duration: 0.18); up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24); down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: "libraryPulse")
    }

    /// 选中球的绿色选中环，跟随球位。
    func refreshSelectionRing() {
        scene.clearResultNodes(nodes: &selectionNodes)
        guard let key = selectedKey,
              let node = scene.allBallNodes[key], !node.isHidden else { return }
        selectionNodes.append(scene.addSelectionRing(at: node.position))
    }

    private var surfaceY: Float { scene.surfaceY }
    private var sceneReady = false

    /// 球库展示序（确认页）：在库球按固定序，母球优先。
    var paletteKeys: [String] {
        PositionPlayBall.allKeys.filter { !onTableKeys.contains($0) }
    }

    var draggableBalls: [SCNNode] { onTableKeys.compactMap { scene.allBallNodes[$0] } }

    /// 进入确认页：建场景并以照片标记的球形为初值。
    func enterConfirm() {
        if !sceneReady {
            scene.setupScene()
            scene.hideAllBalls()
            scene.hideCueStick()
            scene.cameraRig?.topDownPanOffset = .zero
            sceneReady = true
        }
        loadSnapshot(snapshotFromMarks())
        step = .confirm
        confirmHistory = [currentSnapshot()]
        confirmCursor = 0
    }

    private func loadSnapshot(_ snapshot: BoardSnapshot) {
        scene.hideAllBalls()
        for (key, pt) in snapshot.onTable { place(key: key, normalized: pt) }
        selectedKey = nil
        refreshOnTableKeys()
    }

    private func place(key: String, normalized: CanvasPoint) {
        let pos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: normalized.x, y: normalized.y), surfaceY: surfaceY
        )
        scene.showBall(key: key, scenePosition: pos)
    }

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter { !(scene.allBallNodes[$0]?.isHidden ?? true) }
    }

    // MARK: - Confirm edits（位置 / 号码 / 增删）

    func selectBall(node: SCNNode) {
        guard let key = scene.ballKey(for: node) else { return }
        selectedKey = (selectedKey == key) ? nil : key
    }

    func deselect() {
        selectedKey = nil
    }

    // 选中反馈走底部条文案（"已选 X 号"），不改变球的几何尺寸——持续放大的球会让
    // 2D 相机的大半径 SSAO/阴影足迹变大，整桌看起来变暗（与走位编排台对齐：拖拽
    // 只做瞬时脉冲、结束即回弹到 1.0，不留持久缩放）。
    /// 拖动起点快照，用于结束时判定位置是否真的变化（避免无位移拖动入历史）。
    private var dragStartSnapshot: BoardSnapshot?

    func dragBegan(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(to: 1.15, duration: 0.1), forKey: "dragPulse")
        dragStartSnapshot = currentSnapshot()
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        node.position = clampMultiBall(worldPosition, movingNode: node)
        if scene.ballKey(for: node) == selectedKey { refreshSelectionRing() }
    }

    func dragEnded(node: SCNNode) {
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(to: 1.0, duration: 0.15))
        if let start = dragStartSnapshot, !boardsEqual(start, currentSnapshot()) {
            pushConfirmHistory()
        }
        dragStartSnapshot = nil
    }

    /// 从球库添加一颗球到台面（自动空位）。
    func addFromPalette(_ key: String) {
        place(key: key, normalized: freeNormalizedSlot())
        refreshOnTableKeys()
        selectedKey = key
        pushConfirmHistory()
    }

    /// 从球库拖放到指定世界坐标。
    func addFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        selectedKey = key
        pushConfirmHistory()
    }

    func removeFromTable(_ key: String) {
        scene.hideBall(key: key)
        scene.allBallNodes[key]?.scale = SCNVector3(1, 1, 1)
        if selectedKey == key { selectedKey = nil }
        refreshOnTableKeys()
        pushConfirmHistory()
    }

    /// 改号：把当前选中球改为球库里的另一个号码（保持原位置）。
    /// 目标号已在桌上时拒绝（保持号码唯一），提示用户先移除冲突球。
    func assignNumber(_ newKey: String) {
        guard let old = selectedKey, old != newKey,
              let oldNode = scene.allBallNodes[old] else { return }
        if onTableKeys.contains(newKey) {
            flash("\(PositionPlayBall.shortLabel(for: newKey)) 号已在桌上")
            return
        }
        let pos = oldNode.position
        scene.hideBall(key: old)
        scene.allBallNodes[old]?.scale = SCNVector3(1, 1, 1)
        scene.showBall(key: newKey, scenePosition: pos)
        selectedKey = newKey
        refreshOnTableKeys()
        pushConfirmHistory()
    }

    /// 当前确认页桌面快照（最终产物）。
    func currentSnapshot() -> BoardSnapshot {
        var dict: [String: CanvasPoint] = [:]
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let n = AngleSceneCalculator.sceneToNormalized(position: node.position)
            dict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        return BoardSnapshot(onTable: dict)
    }

    // MARK: - Geometry helpers

    private func freeNormalizedSlot() -> CanvasPoint {
        let candidates: [CanvasPoint] = stride(from: 0.15, through: 0.85, by: 0.1).flatMap { x in
            stride(from: 0.10, through: 0.42, by: 0.08).map { y in CanvasPoint(x: x, y: y) }
        }
        for c in candidates {
            let pos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: c.x, y: c.y), surfaceY: surfaceY
            )
            if !overlaps(pos, excluding: nil) { return c }
        }
        return CanvasPoint(x: 0.5, y: 0.25)
    }

    private func overlaps(_ pos: SCNVector3, excluding key: String?) -> Bool {
        for k in onTableKeys where k != key {
            guard let node = scene.allBallNodes[k], !node.isHidden else { continue }
            if AngleSceneCalculator.horizontalDistance(pos, node.position) < 2.2 * AngleSceneCalculator.ballRadius {
                return true
            }
        }
        return false
    }

    /// 落点钳制：台面内 + 远离袋口 + 不与其它球重叠。
    private func clampMultiBall(_ pos: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let r = AngleSceneCalculator.ballRadius
        let minDist: Float = 2 * r + 0.001
        for _ in 0..<6 {
            var moved = false
            for k in onTableKeys {
                guard let other = scene.allBallNodes[k], other !== movingNode, !other.isHidden else { continue }
                let dx = p.x - other.position.x
                let dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else {
                        p.x += minDist
                    }
                    moved = true
                }
            }
            p.x = max(-halfL + r, min(halfL - r, p.x))
            p.z = max(-halfW + r, min(halfW - r, p.z))
            if !moved { break }
        }
        return SCNVector3(p.x, surfaceY + r, p.z)
    }

    private func flash(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.message == text { self?.message = nil }
        }
    }
}
