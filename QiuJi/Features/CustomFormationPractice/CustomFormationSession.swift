import SwiftUI
import SceneKit
import Combine

/// A practice is a mutable copy. Only an explicit save can reach the template library.
@MainActor
final class CustomFormationSession: ObservableObject, Identifiable {
    let id = UUID()
    let vm = PositionPlayViewModel()
    let guide = BatchGuideLine()
    let isTemplateEditor: Bool
    let original: CustomFormationTemplate?
    @Published var keys: [String]
    @Published var toolsActive: Bool
    @Published var focusKey: String?
    @Published var swapMode = false
    @Published var notice: String?
    @Published var hasEdits = false
    @Published var name: String
    @Published var showSave = false
    @Published var saveAsNew = false
    @Published var showExit = false
    @Published var showRestart = false
    @Published var showClear = false
    @Published var showSettings = false
    @Published private(set) var trialBoard: BoardSnapshot?
    @Published var editTool: FormationEditTool?
    @Published var snapEnabled = true
    @Published var drawing = FormationDrawing()
    @Published var selectedLineID: UUID?
    @Published private(set) var lineSorts: [UUID: FormationLineSort] = [:]
    @Published var measurement: [SCNVector3] = []
    @Published var pendingVertex: FormationVertex?
    @Published private(set) var undoStack: [FormationEditState] = []
    @Published private(set) var redoStack: [FormationEditState] = []
    private var constructionNodes: [SCNNode] = []
    private var vertexNodes: [UUID: SCNNode] = [:]
    private var measurementNodes: [SCNNode] = []
    private var axisLock: Int?
    private var dragBefore: FormationEditState?
    private var trialKeys: [String] = []
    private var startBoard: BoardSnapshot
    private var startKeys: [String]
    private var startTemplateID: UUID?
    private var subscriptions = Set<AnyCancellable>()
    private let progressStore: CustomFormationProgressStore?
    private let restoredProgress: CustomFormationProgress?
    private var progressActive = false
    var busy: Bool { vm.isPlaying || vm.isSequencePlaying }
    var isPicking: Bool { isTemplateEditor ? editTool != nil : guide.isPicking }
    var paletteKeys: [String] {
        isTemplateEditor ? PositionPlayBall.objectKeys : PositionPlayBall.objectKeys.filter { paletteCount($0) > 0 }
    }
    /// Restart can restore the original inventory after an in-session removal.
    var maximumPaletteCount: Int {
        isTemplateEditor ? 15 : Set((startKeys + keys).map { PositionPlayBall.number(for: $0) }).count
    }
    func paletteCount(_ source: String) -> Int {
        keys.filter { PositionPlayBall.number(for: $0) == PositionPlayBall.number(for: source) }.count
    }
    /// A grouped slot returns an off-table instance first, preserving every ball's identity.
    func paletteActionKey(_ source: String) -> String {
        guard !PositionPlayBall.isCue(source) else { return source }
        let matches = keys.filter { PositionPlayBall.number(for: $0) == PositionPlayBall.number(for: source) }
        return matches.first { !vm.onTableKeys.contains($0) }
            ?? matches.first { $0 == vm.selectedTargetKey } ?? matches.first ?? source
    }
    private var canAddTarget: Bool { keys.count < CustomFormationTemplate.maximumTargetBalls }
    private func permitTarget(_ source: String) -> Bool {
        if PositionPlayBall.isCue(source) || keys.contains(source) { return true }
        guard !PositionPlayBall.isInstance(source), let number = PositionPlayBall.number(for: source) else { return false }
        guard !keys.contains(where: { PositionPlayBall.number(for: $0) == number }) else {
            notice = "每个球号只能有一颗"; return false
        }
        guard canAddTarget else { notice = "最多15颗目标球（母球另计）"; return false }
        return true
    }
    var canSave: Bool {
        let active = keys.filter { vm.onTableKeys.contains($0) }
        return !busy && trialBoard == nil && vm.onTableKeys.contains(PositionPlayBall.cueKey)
            && !active.isEmpty && CustomFormationTemplate.ballRuleIssue(for: active) == nil
    }
    var toolTitle: String { isTemplateEditor || toolsActive ? "摆球" : "重新开始" }
    var preferredTitleLineBreak: Int? { name == "4443球形" ? 4 : nil }

    init(template: CustomFormationTemplate?, editing: Bool, progress: CustomFormationProgress? = nil,
         progressStore: CustomFormationProgressStore? = nil) {
        self.progressStore = progressStore; restoredProgress = progress
        original = template; isTemplateEditor = editing; toolsActive = editing
        vm.isFormationEditing = editing
        name = template?.name ?? "未命名球形"
        keys = template?.ballKeys ?? []
        startKeys = template?.ballKeys ?? []
        startTemplateID = template?.id
        startBoard = template?.board ?? BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.25, y: 0.25)])
        vm.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        guide.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        // Read after published mutations have committed; never serialize animation frames.
        vm.objectWillChange.debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveProgress() }.store(in: &subscriptions)
    }

    func setup() {
        guard !progressActive else { return }
        if !isTemplateEditor, let restoredProgress { keys = restoredProgress.keys }
        vm.configureCustomBalls(keys)
        vm.loadBoard(!isTemplateEditor ? (restoredProgress?.board ?? startBoard) : startBoard)
        if isTemplateEditor { drawing = original?.drawing ?? .init(); refreshDrawing() }
        vm.setPreferredAimMode(.free)
        if !isTemplateEditor, let restoredProgress { vm.restoreTrainingInput(restoredProgress.input) }
        else { aimAtBuiltInStartingBall() }
        progressActive = true
        vm.onShotWillStart = { [weak self] in self?.willStrike() }
        vm.onShotSettled = { [weak self] facts in
            guard let self else { return }
            if facts.cuePocketed { self.vm.placeFromPalette(PositionPlayBall.cueKey) }
            self.saveProgress()
        }
    }

    func saveProgress() {
        guard progressActive, !isTemplateEditor, !busy, let progressStore, let startTemplateID else { return }
        let value = CustomFormationProgress(templateID: startTemplateID, initialBoard: startBoard,
            initialKeys: startKeys, board: vm.currentSnapshot(), keys: keys, input: vm.trainingInput)
        do { try progressStore.save(value) }
        catch {
            let message = "练习进度未能保存：\(error.localizedDescription)"
            if notice != message { notice = message }
        }
    }

    func finishPractice() {
        saveProgress()
        progressActive = false
        vm.cancelDailyAttempt()
    }

    func willStrike() {
        guard !isTemplateEditor else { return }
        saveProgress()
        guide.clear(scene: vm.scene); swapMode = false; toolsActive = false; notice = nil
    }

    func resumeArrangement(adoptTrial: Bool = false) {
        guard !busy else { return }
        if let trialBoard, !adoptTrial {
            keys = trialKeys; vm.configureCustomBalls(keys); vm.loadBoard(trialBoard)
        }
        trialBoard = nil; toolsActive = true; swapMode = false
        if adoptTrial { changed() }
    }

    func changed() {
        hasEdits = true; notice = nil
        vm.invalidateEditedShotHistory()
    }

    func reset() {
        guard !busy else { return }
        clearTools(); trialBoard = nil
        keys = startKeys; vm.configureCustomBalls(keys); vm.loadBoard(startBoard)
        aimAtBuiltInStartingBall()
        toolsActive = isTemplateEditor; hasEdits = false
        saveProgress()
    }

    func switchTemplate(_ template: CustomFormationTemplate) {
        startTemplateID = template.id
        startBoard = template.board; startKeys = template.ballKeys; name = template.name
        reset(); showSettings = false
    }

    private func aimAtBuiltInStartingBall() {
        guard !isTemplateEditor, let startTemplateID, BuiltInCustomFormations.contains(startTemplateID),
              let first = startKeys.first(where: { PositionPlayBall.number(for: $0) == 1 }) else { return }
        vm.setPreferredAimMode(.free)
        vm.selectTarget(key: first)
    }

    func clearTools() { guide.clear(scene: vm.scene); swapMode = false; focusKey = nil; notice = nil }

    func startLine() {
        guard !busy else { return }
        swapMode = false; toolsActive = true; guide.begin(); notice = nil
    }

    func confirmLine() {
        guard !busy else { return }
        if guide.confirm(scene: vm.scene) { redistribute() }
    }

    func tableTapped(_ point: SCNVector3) -> Bool {
        if isTemplateEditor { editorTableTapped(point); return true }
        guard guide.isPicking else { return false }
        guide.setPoint(point, scene: vm.scene)
        return true
    }

    func select(_ key: String) {
        if isTemplateEditor { selectForEditing(key); return }
        guard !busy else { return }
        if swapMode, !PositionPlayBall.isCue(key),
           let target = vm.scene.allBallNodes[key], let cue = vm.scene.cueBallNode, !cue.isHidden {
            changed()
            let position = cue.position; cue.position = target.position; target.position = position
            swapMode = false; vm.recompute()
        }
        focusKey = key
        if !PositionPlayBall.isCue(key) { _ = vm.selectTarget(key: key) }
        vm.pulseTableBall(key)
    }

    func place(_ source: String, world: SCNVector3?) {
        guard !busy else { return }
        let addsInstance = !PositionPlayBall.isCue(source) && !PositionPlayBall.isInstance(source)
        if isTemplateEditor { placeForEditing(source,world:world); return }
        guard permitTarget(source) else { return }
        let before = editState
        guard let destination = world ?? emptyPosition(excluding: addsInstance ? nil : source),
              validPlacements([addsInstance ? "new" : source: destination]) else {
            notice = "此处放不下，请移到台内空位"; return
        }
        let key: String
        if addsInstance {
            guard let number = PositionPlayBall.number(for: source) else { return }
            key = PositionPlayBall.instanceKey(number: number)
            keys.append(key); vm.configureCustomBalls(keys)
        } else { key = source }
        if let world {
            guard let placement = vm.palettePlacement(key, atWorld: world), validPlacements([key: placement]) else {
                if addsInstance { keys.removeAll { $0 == key }; vm.configureCustomBalls(keys) }
                notice = "此处放不下，请移到台内空位"; return
            }
        }
        changed()
        vm.placeFromPalette(key, atWorld: destination)
        focusKey = key
        record(before)
        redistribute()
    }

    func remove(_ key: String, permanently: Bool = false) {
        guard !busy, !PositionPlayBall.isCue(key) else { return }
        if isTemplateEditor { removeForEditing(key); return }
        let before = dragBefore ?? editState
        changed(); vm.removeFromTable(key)
        if isTemplateEditor || permanently {
            keys.removeAll { $0 == key }; vm.configureCustomBalls(keys)
        }
        if focusKey == key { focusKey = nil }
        record(before)
    }

    func clearTargets() {
        guard !busy else { return }
        let before = editState
        changed(); clearTools()
        for key in keys { vm.removeFromTable(key) }
        keys = []; vm.configureCustomBalls(keys)
        if isTemplateEditor { drawing.lines.indices.forEach { drawing.lines[$0].balls = [] }; refreshDrawing() }
        if !vm.onTableKeys.contains(PositionPlayBall.cueKey) { vm.placeFromPalette(PositionPlayBall.cueKey) }
        record(before)
    }

    func dragEnded() {
        changed()
        if let before = dragBefore { record(before); dragBefore = nil }
        redistribute(); vm.recompute(interactive: true)
    }

    func redistribute() {
        guard !isTemplateEditor else { return }
        let placements = guide.proposedPlacements(keys: keys.filter { vm.onTableKeys.contains($0) }, scene: vm.scene)
        guard !placements.isEmpty else { return }
        guard validPlacements(placements) else { notice = "线上空间不足或与其他球重叠，请调整端点"; return }
        changed()
        for (key, position) in placements { vm.scene.allBallNodes[key]?.position = position }
        vm.recompute()
    }

    /// World X/Z in metres; validate the whole transaction before moving a single node.
    func validPlacements(_ placements: [String: SCNVector3], excluding: Set<String> = []) -> Bool {
        var positions = Dictionary(uniqueKeysWithValues: vm.onTableKeys.filter { !excluding.contains($0) }.compactMap { key in
            vm.scene.allBallNodes[key].map { (key, $0.position) }
        })
        positions.merge(placements) { _, proposed in proposed }
        let entries = Array(positions)
        let radius = AngleSceneCalculator.ballRadius
        for (i, entry) in entries.enumerated() {
            let p = entry.value
            guard p.x.isFinite, p.z.isFinite,
                  abs(p.x) <= AngleSceneCalculator.innerLength / 2 - radius,
                  abs(p.z) <= AngleSceneCalculator.innerWidth / 2 - radius else { return false }
            if placements[entry.key] != nil {
                let bounded = AngleSceneCalculator.clampAwayFromPockets(p, surfaceY: vm.scene.surfaceY)
                guard AngleSceneCalculator.horizontalDistance(p, bounded) < 0.00001 else { return false }
            }
            for other in entries.dropFirst(i + 1) {
                if AngleSceneCalculator.horizontalDistance(p, other.value) < 2 * radius - 0.000001 { return false }
            }
        }
        return true
    }

    @discardableResult
    func nudge(_ direction: BallNudgeDirection, projector: TableProjector) -> Bool {
        guard !busy, let key = focusKey, let node = vm.scene.allBallNodes[key],
              let project = projector.project, let origin = project(node.position) else { return false }
        let desired: CGPoint
        switch direction {
        case .up: desired = CGPoint(x: 0, y: -1)
        case .down: desired = CGPoint(x: 0, y: 1)
        case .left: desired = CGPoint(x: -1, y: 0)
        case .right: desired = CGPoint(x: 1, y: 0)
        }
        let mapped = BallNudgeDirection.allCases.max { a, b in
            func score(_ d: BallNudgeDirection) -> CGFloat {
                let delta = BallNudgeMath.delta(for: d, stepMeters: 0.1)
                guard let p = project(SCNVector3(node.position.x + delta.dx, node.position.y, node.position.z + delta.dz)) else { return -.greatestFiniteMagnitude }
                return (p.x - origin.x) * desired.x + (p.y - origin.y) * desired.y
            }
            return score(a) < score(b)
        } ?? direction
        let moved = vm.nudgeBall(key: key, direction: mapped)
        if moved { changed(); vm.recompute(interactive: true) }
        return moved
    }

    func templateForSaving() throws -> CustomFormationTemplate {
        let board = vm.currentSnapshot()
        let active = keys.filter { board.onTable[$0] != nil }
        var result = CustomFormationTemplate(name: name.trimmingCharacters(in: .whitespacesAndNewlines), ballKeys: active, board: board, drawing: isTemplateEditor ? drawing : nil)
        if isTemplateEditor, !saveAsNew, let original { result.id = original.id }
        try result.validateForPractice()
        return result
    }
}

// Geometry uses world X/Z metres (Y-up); UI readouts convert to centimetres.
enum FormationEditTool: String, CaseIterable { case line = "直线", distance = "量距离", angle = "量角度" }
struct FormationVertex: Codable, Equatable, Identifiable {
    var id = UUID()
    var x: Float
    var z: Float
    func world(y: Float) -> SCNVector3 { SCNVector3(x, y, z) }
}
struct FormationLine: Codable, Equatable, Identifiable {
    var id = UUID()
    var start: UUID
    var end: UUID
    var balls: [String] = []
}
struct FormationDrawing: Codable, Equatable {
    var vertices: [FormationVertex] = []
    var lines: [FormationLine] = []
    func vertex(_ id: UUID, y: Float) -> SCNVector3? { vertices.first { $0.id == id }?.world(y: y) }
}
struct FormationLineSort: Equatable {
    var original: [String]
    var reversed = false
}
struct FormationEditState {
    var keys: [String]; var board: BoardSnapshot; var drawing: FormationDrawing
    var lineSorts: [UUID: FormationLineSort]
    var selectedLineID: UUID?
}

enum FormationGeometry {
    /// Screen coordinates are points, +x right / +y down. Vertical lines read top to bottom.
    static func startPrecedesEnd(_ a: CGPoint, _ b: CGPoint) -> Bool {
        abs(a.x-b.x) > 1 ? a.x < b.x : a.y < b.y
    }
    static func line(a: SCNVector3, b: SCNVector3, count: Int) -> [SCNVector3]? {
        guard count > 0, [a.x,a.z,b.x,b.z].allSatisfy({ $0.isFinite }),
              abs(a.x) <= AngleSceneCalculator.innerLength/2, abs(b.x) <= AngleSceneCalculator.innerLength/2,
              abs(a.z) <= AngleSceneCalculator.innerWidth/2, abs(b.z) <= AngleSceneCalculator.innerWidth/2 else { return nil }
        let length = AngleSceneCalculator.horizontalDistance(a, b)
        guard count == 1 || Double(count - 1) <= Double(length / (2 * BallPhysics.radius)) + 0.00001 else { return nil }
        return (0..<count).map { i in
            let f: Float = count == 1 ? 0.5 : Float(i) / Float(count - 1)
            return SCNVector3(a.x + (b.x-a.x)*f, a.y, a.z + (b.z-a.z)*f)
        }
    }
    static func angleArc(_ a: SCNVector3, vertex b: SCNVector3, _ c: SCNVector3) -> [SCNVector3] {
        guard let degrees = angle(a,vertex:b,c), degrees > 0.001 else { return [] }
        let start = atan2(a.z-b.z,a.x-b.x)
        let sweep = atan2((a.x-b.x)*(c.z-b.z)-(a.z-b.z)*(c.x-b.x),
                          (a.x-b.x)*(c.x-b.x)+(a.z-b.z)*(c.z-b.z))
        let radius = min(0.16, min(AngleSceneCalculator.horizontalDistance(a,b),AngleSceneCalculator.horizontalDistance(c,b))*0.3)
        return (0...48).map { i in
            let angle = start+sweep*Float(i)/48
            return SCNVector3(b.x+cos(angle)*radius,b.y,b.z+sin(angle)*radius)
        }
    }
    static func projection(_ p: SCNVector3, a: SCNVector3, b: SCNVector3) -> (point: SCNVector3, fraction: Float) {
        let dx = b.x-a.x, dz = b.z-a.z, square = dx*dx+dz*dz
        let t = square > 1e-10 ? min(1,max(0,((p.x-a.x)*dx+(p.z-a.z)*dz)/square)) : 0
        return (SCNVector3(a.x+t*dx,a.y,a.z+t*dz),t)
    }
    static func angle(_ a: SCNVector3, vertex b: SCNVector3, _ c: SCNVector3) -> Double? {
        let ux = Double(a.x-b.x), uz = Double(a.z-b.z), vx = Double(c.x-b.x), vz = Double(c.z-b.z)
        let denominator = hypot(ux,uz)*hypot(vx,vz)
        guard denominator.isFinite, denominator > 1e-10 else { return nil }
        return acos(min(1,max(-1,(ux*vx+uz*vz)/denominator))) * 180 / .pi
    }
}

extension CustomFormationSession {
    var editState: FormationEditState { .init(keys: keys, board: vm.currentSnapshot(), drawing: drawing, lineSorts: lineSorts, selectedLineID: selectedLineID) }
    var selectedLine: FormationLine? { drawing.lines.first { $0.id == selectedLineID } }
    var lineSortTitle: String {
        guard let id = selectedLineID, let sort = lineSorts[id] else { return "排序" }
        return sort.reversed ? "右→左" : "左→右"
    }
    func sortSelectedLine(startPrecedesEnd: Bool) {
        guard isTemplateEditor, editTool == nil, let line = selectedLine, line.balls.count > 1 else { return }
        let before = editState
        let previous = lineSorts[line.id]
        let original = previous?.original ?? line.balls
        let desired: [String]
        var next: FormationLineSort?
        if previous?.reversed == true {
            desired = original
        } else {
            let ascending = original.enumerated().sorted {
                let a = PositionPlayBall.number(for:$0.element) ?? 0
                let b = PositionPlayBall.number(for:$1.element) ?? 0
                return a == b ? $0.offset < $1.offset : a < b
            }.map(\.element)
            let reversed = previous != nil
            desired = startPrecedesEnd != reversed ? ascending : Array(ascending.reversed())
            next = FormationLineSort(original:original,reversed:reversed)
        }
        // Remap identities at occupied slots throughout the graph. A joint still has one ball.
        let replacements = Dictionary(uniqueKeysWithValues:zip(line.balls,desired))
        var graph = drawing
        for i in graph.lines.indices {
            graph.lines[i].balls = graph.lines[i].balls.map { replacements[$0] ?? $0 }
        }
        guard let positions = placements(for:graph),validPlacements(positions) else { return }
        drawing = graph; lineSorts[line.id] = next
        applyPositions(positions); focusKey = nil; notice = nil
        refreshDrawing(); record(before)
    }
    var lineBallCount: Int { selectedLine?.balls.count ?? 0 }
    var lineLengthCM: Double? {
        guard let line = selectedLine, let a = vertex(line.start), let b = vertex(line.end) else { return nil }
        return Double(AngleSceneCalculator.horizontalDistance(a,b))*100
    }
    var lineSpacingCM: Double? { lineBallCount > 1 ? lineLengthCM.map { $0/Double(lineBallCount-1) } : nil }
    var measurementValue: Double? {
        if editTool == .distance, measurement.count == 2 { return Double(AngleSceneCalculator.horizontalDistance(measurement[0],measurement[1]))*100 }
        if editTool == .angle, measurement.count == 3 { return FormationGeometry.angle(measurement[0],vertex:measurement[1],measurement[2]) }
        return nil
    }
    var precisionHandles: [SCNNode] {
        if editTool == .distance || editTool == .angle { return measurementNodes }
        guard editTool == nil, let line = selectedLine else { return [] }
        return [vertexNodes[line.start],vertexNodes[line.end]].compactMap { $0 }
    }
    var editingDragNodes: [SCNNode] {
        if editTool == .distance || editTool == .angle { return measurementNodes }
        if editTool == .line { return [] }
        return precisionHandles + vm.draggableBalls
    }
    var editHint: String? {
        if let notice { return notice }
        switch editTool {
        case .line: return pendingVertex == nil ? "点起点，可连接已有端点" : "点终点"
        case .distance: return measurement.count < 2 ? (measurement.isEmpty ? "点第一点" : "点第二点") : nil
        case .angle: return measurement.count < 3 ? ["点第一点","点角顶点","点第三点"][measurement.count] : nil
        case nil: return nil
        }
    }
    private var ballY: Float { vm.scene.surfaceY + BallPhysics.radius }
    private func vertex(_ id: UUID) -> SCNVector3? { drawing.vertex(id,y:ballY) }
    func record(_ before: FormationEditState) {
        guard isTemplateEditor else { return }
        // Manual membership/order changes start a new cycle; undo restores the prior cycle too.
        for id in Array(lineSorts.keys) where before.lineSorts[id] == lineSorts[id] {
            if before.drawing.lines.first(where: { $0.id == id })?.balls != drawing.lines.first(where: { $0.id == id })?.balls {
                lineSorts[id] = nil
            }
        }
        let after = editState
        guard before.keys != after.keys || before.drawing != after.drawing || before.lineSorts != after.lineSorts || !sameBoard(before.board,after.board) else { return }
        undoStack.append(before); redoStack = []; hasEdits = true
    }
    private func sameBoard(_ a: BoardSnapshot, _ b: BoardSnapshot) -> Bool {
        Set(a.onTable.keys) == Set(b.onTable.keys) && a.onTable.allSatisfy { key,p in
            b.onTable[key].map { abs($0.x-p.x)<1e-8 && abs($0.y-p.y)<1e-8 } ?? false
        }
    }
    func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(editState); restoreEdit(previous)
    }
    func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(editState); restoreEdit(next)
    }
    private func restoreEdit(_ state: FormationEditState) {
        cancelTool(); keys = state.keys; drawing = state.drawing; lineSorts = state.lineSorts
        vm.configureCustomBalls(keys); vm.loadBoard(state.board)
        selectedLineID = state.selectedLineID; focusKey = nil; hasEdits = true; notice = nil
        refreshDrawing()
    }
    func beginTool(_ tool: FormationEditTool) {
        let wasActive = editTool == tool
        cancelTool()
        if !wasActive { editTool = tool; focusKey = nil }
        refreshDrawing()
    }
    func cancelTool() {
        editTool = nil; pendingVertex = nil; measurement = []; notice = nil; axisLock = nil
        refreshDrawing()
    }
    func clearMeasurement() { measurement = []; notice = nil; refreshDrawing() }
    func deleteSelectedLine() {
        guard let id = selectedLineID else { return }
        let before = editState
        drawing.lines.removeAll { $0.id == id }
        pruneVertices(); selectedLineID = nil; pendingVertex = nil
        refreshDrawing(); record(before)
    }
    func clearDrawing() {
        let before = editState
        drawing = .init(); selectedLineID = nil; cancelTool(); record(before)
    }
    private func pruneVertices() {
        let used = Set(drawing.lines.flatMap { [$0.start,$0.end] })
        drawing.vertices.removeAll { !used.contains($0.id) }
    }
    func selectForEditing(_ key: String) {
        guard let node = vm.scene.allBallNodes[key] else { return }
        if editTool != nil { editorTableTapped(node.position); return }
        focusKey = key
        if let owner = drawing.lines.first(where: { $0.balls.contains(key) }) { selectedLineID = owner.id }
        else { selectedLineID = nil }
        vm.pulseTableBall(key); refreshDrawing()
    }
    private func bounded(_ raw: SCNVector3) -> SCNVector3 {
        let r = BallPhysics.radius
        let p = SCNVector3(min(AngleSceneCalculator.innerLength/2-r,max(-AngleSceneCalculator.innerLength/2+r,raw.x)),ballY,
                           min(AngleSceneCalculator.innerWidth/2-r,max(-AngleSceneCalculator.innerWidth/2+r,raw.z)))
        return AngleSceneCalculator.clampAwayFromPockets(p,surfaceY:vm.scene.surfaceY)
    }
    // Magnetic capture band in table metres, with a wider release band to prevent chatter.
    var snapRadius: Float { 0.045 }
    private func nearVertex(_ p: SCNVector3, excluding: UUID? = nil) -> FormationVertex? {
        drawing.vertices.filter { $0.id != excluding }.min { distance($0.world(y:ballY),p) < distance($1.world(y:ballY),p) }
            .flatMap { distance($0.world(y:ballY),p) <= snapRadius ? $0 : nil }
    }
    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float { AngleSceneCalculator.horizontalDistance(a,b) }
    private func magnet(_ p: SCNVector3, anchor: SCNVector3) -> SCNVector3 {
        guard snapEnabled else { axisLock = nil; return p }
        let dx = abs(p.x-anchor.x), dz = abs(p.z-anchor.z)
        let previous = axisLock
        if axisLock == 0 && dz > snapRadius*1.5 { axisLock = nil }
        if axisLock == 1 && dx > snapRadius*1.5 { axisLock = nil }
        if axisLock == nil {
            if dz < snapRadius && dx > dz { axisLock = 0 }
            else if dx < snapRadius && dz > dx { axisLock = 1 }
        }
        if previous != axisLock, axisLock != nil { UISelectionFeedbackGenerator().selectionChanged() }
        if axisLock == 0 { return SCNVector3(p.x,ballY,anchor.z) }
        if axisLock == 1 { return SCNVector3(anchor.x,ballY,p.z) }
        return p
    }
    func editorTableTapped(_ raw: SCNVector3) {
        guard raw.x.isFinite,raw.z.isFinite else { return }
        notice = nil
        let p = bounded(raw)
        switch editTool {
        case .line:
            if let start = pendingVertex {
                let before = editState
                let linked = nearVertex(p)
                let endPoint = linked?.world(y:ballY) ?? magnet(p,anchor:start.world(y:ballY))
                guard distance(start.world(y:ballY),endPoint) > 0.001, linked?.id != start.id else { return }
                let end = linked ?? FormationVertex(x:endPoint.x,z:endPoint.z)
                guard !drawing.lines.contains(where: { Set([$0.start,$0.end]) == Set([start.id,end.id]) }) else {
                    notice = "这两个端点已有连线"; return
                }
                if !drawing.vertices.contains(where: { $0.id == start.id }) { drawing.vertices.append(start) }
                if !drawing.vertices.contains(where: { $0.id == end.id }) { drawing.vertices.append(end) }
                let line = FormationLine(start:start.id,end:end.id)
                drawing.lines.append(line); selectedLineID = line.id; pendingVertex = nil; axisLock = nil
                record(before)
            } else { pendingVertex = nearVertex(p) ?? FormationVertex(x:p.x,z:p.z) }
        case .distance,.angle:
            let limit = editTool == .distance ? 2 : 3
            if measurement.count == limit { measurement = [] }
            axisLock = nil
            let point = measurementPoint(p,index:measurement.count)
            if let last = measurement.last, distance(last,point) < 0.001 { return }
            measurement.append(point)
        case nil:
            if let ball = vm.onTableKeys.compactMap({ key in vm.scene.allBallNodes[key].map { (key,$0.position) } })
                .min(by: { distance($0.1,p)<distance($1.1,p) }), distance(ball.1,p)<BallPhysics.radius {
                selectForEditing(ball.0)
            } else { focusKey = nil; selectedLineID = nearestLine(p)?.id }
        }
        refreshDrawing()
    }
    private func measurementPoint(_ raw: SCNVector3, index: Int) -> SCNVector3 {
        let p = measurementSnap(bounded(raw))
        guard editTool == .angle, snapEnabled else { return p }
        // Ball centres / existing vertices win over axial snapping.
        if distance(p,bounded(raw)) > 0.00001 { axisLock = nil; return p }
        let anchors = index == 1 ? measurement.enumerated().filter { $0.offset != 1 }.map(\.element)
            : (measurement.count > 1 ? [measurement[1]] : [])
        guard let anchor = anchors.min(by: { min(abs($0.x-p.x),abs($0.z-p.z)) < min(abs($1.x-p.x),abs($1.z-p.z)) }) else { return p }
        return bounded(magnet(p,anchor:anchor))
    }
    var measurementColor: UIColor { editTool == .angle ? .systemOrange : .cyan }
    var measurementAnnotationColor: UIColor { editTool == .angle ? .white : measurementColor }
    var measurementLabelPoint: SCNVector3? {
        guard measurementValue != nil else { return nil }
        if editTool == .distance { return SCNVector3((measurement[0].x+measurement[1].x)/2,ballY,(measurement[0].z+measurement[1].z)/2) }
        let arc = FormationGeometry.angleArc(measurement[0],vertex:measurement[1],measurement[2])
        guard !arc.isEmpty else { return measurement[1] }
        let middle = arc[arc.count/2], vertex = measurement[1]
        return bounded(SCNVector3(vertex.x+(middle.x-vertex.x)*1.45,ballY,vertex.z+(middle.z-vertex.z)*1.45))
    }
    private func measurementSnap(_ p: SCNVector3) -> SCNVector3 {
        guard snapEnabled else { return p }
        let candidates = drawing.vertices.map { $0.world(y:ballY) } + vm.onTableKeys.compactMap { vm.scene.allBallNodes[$0]?.position }
        return candidates.min { distance($0,p)<distance($1,p) }.flatMap { distance($0,p)<=snapRadius ? $0 : nil } ?? p
    }
    private func nearestLine(_ p: SCNVector3) -> FormationLine? {
        let candidates = drawing.lines.compactMap { line -> (FormationLine,Float)? in
            guard let a = vertex(line.start),let b = vertex(line.end) else { return nil }
            return (line,distance(FormationGeometry.projection(p,a:a,b:b).point,p))
        }.filter { $0.1 <= snapRadius }
        if let selected = candidates.first(where: { $0.0.id == selectedLineID }) { return selected.0 }
        return candidates.min { $0.1 < $1.1 }?.0
    }
    /// Return the ball already occupying a shared vertex, so two lines never duplicate it.
    private func endpointBall(_ id: UUID, excluding lineID: UUID, in graph: FormationDrawing) -> String? {
        for line in graph.lines where line.id != lineID && line.balls.count >= 2 {
            if line.start == id { return line.balls.first }
            if line.end == id { return line.balls.last }
        }
        return nil
    }
    private func attach(_ key: String, to id: UUID, at p: SCNVector3, graph: inout FormationDrawing) {
        guard let i = graph.lines.firstIndex(where: { $0.id == id }),
              let a = graph.vertex(graph.lines[i].start,y:ballY), let b = graph.vertex(graph.lines[i].end,y:ballY) else { return }
        for j in graph.lines.indices { graph.lines[j].balls.removeAll { $0 == key } }
        var members = graph.lines[i].balls
        let startBall = endpointBall(graph.lines[i].start,excluding:id,in:graph)
        let endBall = endpointBall(graph.lines[i].end,excluding:id,in:graph)
        for shared in [startBall,endBall].compactMap({ $0 }) where !members.contains(shared) && shared != key { members.append(shared) }
        members.append(key)
        members.sort { lhs,rhs in
            func fraction(_ k: String) -> Float {
                if k == startBall { return -1 }; if k == endBall { return 2 }
                return FormationGeometry.projection(k == key ? p : (vm.scene.allBallNodes[k]?.position ?? p),a:a,b:b).fraction
            }
            return fraction(lhs)<fraction(rhs)
        }
        graph.lines[i].balls = members
    }
    private func placements(for graph: FormationDrawing) -> [String:SCNVector3]? {
        var result: [String:SCNVector3] = [:]
        for line in graph.lines where !line.balls.isEmpty {
            guard let a = graph.vertex(line.start,y:ballY),let b = graph.vertex(line.end,y:ballY),
                  var points = FormationGeometry.line(a:a,b:b,count:line.balls.count) else { return nil }
            // A shared joint ball remains at its vertex when its other branch is emptied.
            if line.balls.count == 1 {
                if endpointBall(line.start,excluding:line.id,in:graph) == line.balls[0] { points = [a] }
                else if endpointBall(line.end,excluding:line.id,in:graph) == line.balls[0] { points = [b] }
            }
            for (key,p) in zip(line.balls,points) {
                if let old = result[key], distance(old,p)>0.00001 { return nil }
                result[key] = p
            }
        }
        return result
    }
    private func applyPositions(_ positions: [String:SCNVector3]) {
        for (key,p) in positions { vm.scene.allBallNodes[key]?.position = p }
        vm.invalidateEditedShotHistory(); vm.recompute(interactive:true)
    }
    func placeForEditing(_ source: String, world: SCNVector3?) {
        guard editTool == nil || editTool == .line else { return }
        let before = editState
        let isNew = !PositionPlayBall.isCue(source) && !PositionPlayBall.isInstance(source)
        guard permitTarget(source) else { return }
        let key = isNew ? PositionPlayBall.instanceKey(number:PositionPlayBall.number(for:source) ?? 1) : source
        var graph = drawing
        let target = world.flatMap { snapEnabled ? nearestLine($0) : nil } ?? (world == nil ? selectedLine : nil)
        let destination: SCNVector3
        if let line = target, let a = vertex(line.start),let b = vertex(line.end) {
            destination = world ?? FormationGeometry.projection(a,a:a,b:b).point
            attach(key,to:line.id,at:destination,graph:&graph)
        } else {
            guard let p = world.map(bounded) ?? emptyPosition(excluding:isNew ? nil:key) else { notice = "台面没有可用空位"; return }
            destination = p
            for i in graph.lines.indices { graph.lines[i].balls.removeAll { $0 == key } }
        }
        guard var proposed = placements(for:graph) else { notice = "线段空间不足，请调整端点"; return }
        if target == nil { proposed[key] = destination }
        guard validPlacements(proposed) else { notice = "球位重叠，请调整端点或放球位置"; return }
        if isNew { keys.append(key); vm.configureCustomBalls(keys) }
        vm.placeFromPalette(key,atWorld:proposed[key] ?? destination)
        drawing = graph; applyPositions(proposed)
        editTool = nil; pendingVertex = nil; focusKey = key
        selectedLineID = target?.id
        changed(); refreshDrawing(); record(before)
    }
    func editorDragBegan(_ node: SCNNode) {
        dragBefore = editState; axisLock = nil; notice = nil
        if precisionHandles.contains(node) { focusKey = nil; return }
        focusKey = vm.scene.ballKey(for:node)
    }
    func editorDragMoved(_ node: SCNNode, world: SCNVector3) {
        guard world.x.isFinite,world.z.isFinite else { return }
        if let index = measurementNodes.firstIndex(of:node),measurement.indices.contains(index) {
            measurement[index] = measurementPoint(world,index:index); refreshDrawing(); return
        }
        if let id = vertexNodes.first(where: { $0.value === node })?.key {
            moveVertex(id,to:world); return
        }
        guard let key = vm.scene.ballKey(for:node) else { return }
        var graph = drawing
        let p = bounded(world)
        let line = snapEnabled ? nearestLine(p) : nil
        if let line { attach(key,to:line.id,at:p,graph:&graph) }
        else { for i in graph.lines.indices { graph.lines[i].balls.removeAll { $0 == key } } }
        guard var proposed = placements(for:graph) else { return }
        if line == nil { proposed[key] = p }
        guard validPlacements(proposed) else { notice = "球位重叠，请调整位置"; return }
        drawing = graph; selectedLineID = line?.id; applyPositions(proposed); notice = nil; refreshDrawing()
    }
    func moveVertex(_ id: UUID, to raw: SCNVector3) {
        guard let index = drawing.vertices.firstIndex(where: { $0.id == id }) else { return }
        var p = bounded(raw)
        if let line = selectedLine, let anchor = vertex(line.start == id ? line.end : line.start) { p = bounded(magnet(p,anchor:anchor)) }
        var graph = drawing
        graph.vertices[index].x = p.x; graph.vertices[index].z = p.z
        guard graph.lines.allSatisfy({ line in
            guard let a = graph.vertex(line.start,y:ballY),let b = graph.vertex(line.end,y:ballY) else { return false }
            return distance(a,b)>0.001
        }),let proposed = placements(for:graph), validPlacements(proposed) else {
            notice = "球位重叠或线段过短，请调整端点"; return
        }
        drawing = graph; applyPositions(proposed); notice = nil; refreshDrawing()
    }
    func editorDragEnded(_ node: SCNNode) {
        if let before = dragBefore { record(before) }; dragBefore = nil; axisLock = nil
        refreshDrawing()
    }
    func removeForEditing(_ key: String) {
        guard !PositionPlayBall.isCue(key) else { return }
        let before = dragBefore ?? editState
        var graph = drawing
        for i in graph.lines.indices { graph.lines[i].balls.removeAll { $0 == key } }
        guard let proposed = placements(for:graph),validPlacements(proposed,excluding:[key]) else {
            notice = "移除后球位重叠，请先调整辅助线"; return
        }
        vm.removeFromTable(key); keys.removeAll { $0 == key }; vm.configureCustomBalls(keys)
        drawing = graph; applyPositions(proposed); focusKey = nil; changed(); refreshDrawing(); record(before)
    }
    func refreshDrawing() {
        constructionNodes.forEach { $0.removeFromParentNode() }; constructionNodes = []
        let ids = Set(drawing.vertices.map(\.id))
        for id in Array(vertexNodes.keys) where !ids.contains(id) { vertexNodes.removeValue(forKey:id)?.removeFromParentNode() }
        for point in drawing.vertices {
            let node = vertexNodes[point.id] ?? makeHandle("formation.vertex.\(point.id)")
            vertexNodes[point.id] = node; node.position = point.world(y:ballY)
            let selected = selectedLine.map { $0.start == point.id || $0.end == point.id } ?? false
            node.opacity = selected || editTool == .line ? 1 : 0.5
        }
        for line in drawing.lines {
            guard let a = vertex(line.start),let b = vertex(line.end) else { continue }
            draw(a,b,selected:line.id == selectedLineID)
        }
        if let pendingVertex, !ids.contains(pendingVertex.id) {
            let node = makeHandle("formation.pending"); node.position = pendingVertex.world(y:ballY); constructionNodes.append(node)
        }
        while measurementNodes.count > measurement.count { measurementNodes.removeLast().removeFromParentNode() }
        for (i,p) in measurement.enumerated() {
            if measurementNodes.count <= i { measurementNodes.append(makeHandle("formation.measure.\(i)")) }
            measurementNodes[i].position = p
            measurementNodes[i].geometry?.firstMaterial?.diffuse.contents = measurementColor
        }
        if measurement.count >= 2 { draw(measurement[0],measurement[1],color:measurementColor,layer:.aiming) }
        if measurement.count == 3 {
            draw(measurement[1],measurement[2],color:measurementColor,layer:.aiming)
            let arc = FormationGeometry.angleArc(measurement[0],vertex:measurement[1],measurement[2])
            for (a,b) in zip(arc,arc.dropFirst()) { draw(a,b,color:measurementAnnotationColor,layer:.aiming) }
        }

    }
    private func makeHandle(_ name: String) -> SCNNode {
        let node = SCNNode(geometry:SCNSphere(radius:0.018))
        node.name = name
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        node.geometry?.firstMaterial?.lightingModel = .constant
        // Handles stay visible when a ball occupies the endpoint; only these small controls ignore depth.
        node.geometry?.firstMaterial?.readsFromDepthBuffer = false
        node.geometry?.firstMaterial?.writesToDepthBuffer = false
        node.renderingOrder = 100
        vm.scene.rootNode.addChildNode(node); return node
    }
    private func draw(_ a: SCNVector3,_ b: SCNVector3,selected:Bool = true, color: UIColor = .white, layer: AngleTrainingScene.TableAssistLayer = .reference) {
        constructionNodes.append(vm.scene.addLine(from:a,to:b,color:color.withAlphaComponent(selected ? 1:0.65),radius:0.003,placement:.table,layer:layer))
    }
    func emptyPosition(excluding key: String?) -> SCNVector3? {
        let step = 2 * BallPhysics.radius + 0.004
        for z in stride(from:-AngleSceneCalculator.innerWidth/2+step,through:AngleSceneCalculator.innerWidth/2-step,by:step) {
            for x in stride(from:-AngleSceneCalculator.innerLength/2+step,through:AngleSceneCalculator.innerLength/2-step,by:step) {
                let p = SCNVector3(x,ballY,z)
                if validPlacements([key ?? "new":p]) { return p }
            }
        }
        return nil
    }
}
