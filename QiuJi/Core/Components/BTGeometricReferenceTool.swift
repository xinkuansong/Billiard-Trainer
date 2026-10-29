import SwiftUI
import SceneKit

/// A per-shot draft. Never writes the physical shot, reference prediction or score.
@MainActor
final class GeometricReferenceTool: ObservableObject {
    struct Draft: Equatable, Codable {
        var context: GeometricRailReference.Context?
        var reflections = 0
        var first: GeometricRailReference.Point?
    }
    struct Snapshot: Codable {
        let draft: Draft
        let previous: Draft?
        let identity, previousIdentity: String?
        let visible, needsFirstPoint, previousNeedsFirstPoint: Bool
    }
    var snapshot: Snapshot { .init(draft: draft, previous: previous, identity: identity,
        previousIdentity: previousIdentity, visible: visible, needsFirstPoint: needsFirstPoint,
        previousNeedsFirstPoint: previousNeedsFirstPoint) }
    func restore(_ value: Snapshot) {
        draft = value.draft; previous = value.previous; identity = value.identity
        previousIdentity = value.previousIdentity; needsFirstPoint = value.needsFirstPoint
        previousNeedsFirstPoint = value.previousNeedsFirstPoint; frozen = false; dragging = false
        if value.visible { render() } else { hide() }
    }
    @Published private(set) var draft = Draft()
    @Published private(set) var visible = false
    @Published private(set) var dragging = false
    @Published private(set) var needsFirstPoint = false
    private(set) var frozen = false
    private var previousNeedsFirstPoint = false
    private var previous: Draft?
    private var previousIdentity: String?
    private var identity: String?
    private weak var scene: AngleTrainingScene?
    private let changed: () -> Void
    private var lines: [SCNNode] = []
    let handle: SCNNode

    init(scene: AngleTrainingScene, changed: @escaping () -> Void = {}) {
        self.scene = scene; self.changed = changed
        let sphere = SCNSphere(radius: CGFloat(BallPhysics.radius))
        sphere.segmentCount = 24
        let material = SCNMaterial()
        material.diffuse.contents = TrajectoryStyle.TrainingAssist.routeReference.withAlphaComponent(0.65)
        material.lightingModel = .constant
        material.writesToDepthBuffer = false
        sphere.materials = [material]
        handle = SCNNode(geometry: sphere)
        handle.name = "geometryReference.handle"; handle.castsShadow = false; handle.isHidden = true
    }
    var draggableNodes: [SCNNode] { visible && !frozen ? [handle] : [] }
    var points: [GeometricRailReference.Point] {
        guard let context = draft.context, let first = draft.first else { return [] }
        return GeometricRailReference.path(context: context, first: first, reflections: draft.reflections)
    }
    func update(identity: String, cue: SCNVector3, target: SCNVector3, pocketIndex: Int) {
        guard let scene, !frozen else { return }
        if self.identity != identity { nextShot(); self.identity = identity }
        guard (0..<6).contains(pocketIndex) else { reset(); return }
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: scene.surfaceY)
        let context = GeometricRailReference.Context(cue: cue, target: target, pocket: aim)
        guard context != draft.context else { return }
        draft.context = context
        if draft.reflections > 0 {
            draft.first = draft.first.flatMap { context?.constrain($0) } ?? context?.defaultFirst
            render()
        }
    }
    func select(_ count: Int) {
        guard !frozen, (0...5).contains(count) else { return }
        draft.reflections = count
        if count > 0 && draft.first == nil {
            draft.first = draft.context?.defaultFirst
            // Straight shots and a tangent aimed into a mouth have no valid
            // default cushion contact. Expose a movable seed, explicitly marked
            // as requiring the player's first-point selection.
            needsFirstPoint = draft.first == nil
            if draft.first == nil, let context = draft.context {
                let direction = context.tangent ?? .init(-context.incoming.y, context.incoming.x)
                let seed = GeometricRailReference.boundaryHit(from: context.ghost, direction: direction)?.point ?? context.ghost
                draft.first = context.constrain(seed)
            }
        }
        render(); changed()
    }
    func beginDrag() { guard visible, !frozen else { return }; dragging = true; changed() }
    func drag(to world: SCNVector3) {
        guard !frozen, draft.reflections > 0,
              let point = draft.context?.constrain(GeometricRailReference.point(world)) else { return }
        draft.first = point; needsFirstPoint = false; render(); changed()
    }
    func endDrag() { dragging = false; changed() }
    func freeze() { previousNeedsFirstPoint = needsFirstPoint; previous = draft; previousIdentity = identity; frozen = true; endDrag() }
    func cancelFreeze() { frozen = false; render(); changed() }
    func complete() { frozen = false; dragging = false; hide(); changed() }
    func restore() {
        guard let previous else { return }
        draft = previous; needsFirstPoint = previousNeedsFirstPoint; identity = previousIdentity; frozen = false; render(); changed()
    }
    /// A new multi-ball stroke keeps only the preceding shot's undo snapshot.
    func nextShot() { draft = Draft(); frozen = false; dragging = false; needsFirstPoint = false; hide(); changed() }
    func reset() { previous = nil; identity = nil; nextShot() }
    private func hide() {
        lines.forEach { $0.removeFromParentNode() }; lines = []
        handle.isHidden = true; visible = false
    }
    private func render() {
        hide()
        guard let scene, draft.reflections > 0, let first = draft.first else { return }
        let y = scene.surfaceY + BallPhysics.radius
        func world(_ p: GeometricRailReference.Point) -> SCNVector3 { .init(Float(p.x), y, Float(p.y)) }
        let route = points
        guard route.count >= 2 else { return }
        // Short dashes distinguish this ideal construction from centre-ball physics.
        for (a, b) in zip(route, route.dropFirst()) {
            let node = scene.addDashedLine(from: world(a), to: world(b),
                color: TrajectoryStyle.TrainingAssist.routeReference, radius: 0.002,
                dash: TrajectoryStyle.hintDash, gap: TrajectoryStyle.hintGap,
                placement: .table, layer: .reference)
            node.name = "geometryReference.route"; lines.append(node)
        }
        handle.position = world(first); scene.rootNode.addChildNode(handle)
        handle.isHidden = false; visible = true
    }
    #if DEBUG
    var diagnostic: [String: Any] {
        ["count": draft.reflections, "visible": visible, "frozen": frozen,
         "first": draft.first.map { [$0.x, $0.y] } ?? [],
         "points": points.map { [$0.x, $0.y] },
         "allowed": draft.first.flatMap { draft.context?.allows($0) } ?? false,
         "pocket": draft.context.map { [$0.pocket.x, $0.pocket.y] } ?? [],
         "ghost": draft.context.map { [$0.ghost.x, $0.ghost.y] } ?? [],
         "cue": draft.context.map { [$0.cue.x, $0.cue.y] } ?? []]
    }
    #endif
}

struct BTGeometricReferenceButton: View {
    @ObservedObject var tool: GeometricReferenceTool
    var enabled: Bool
    var size: CGFloat
    var identifier: String
    var prepare: () -> Void
    @State private var showsChoices = false
    @ScaledMetric(relativeTo: .body) private var choicesWidth = 112

    var body: some View {
        Button { showsChoices.toggle() } label: {
            VStack(spacing: 0) {
                Text("测量").font(.btCaption)
                if tool.draft.reflections > 0 {
                    Text(tool.needsFirstPoint ? "拖动选点" : "\(tool.draft.reflections)库").font(.btCaption2)
                }
            }
            .foregroundStyle(HUDStyle.valueMeasured)
            .frame(width: size, height: size)
            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: BTRadius.md)) }
            .overlay(RoundedRectangle(cornerRadius: BTRadius.md).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { TeachingMenuIndicator().allowsHitTesting(false) }
        .disabled(!enabled).opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("测量").accessibilityValue(tool.draft.reflections == 0 ? "关闭" : "\(tool.draft.reflections)库")
        .accessibilityHint(tool.needsFirstPoint ? "请拖动假想球选择第一库吃库点" : "拖动第一库假想球调整参考线路")
        .accessibilityIdentifier(identifier)
        .popover(isPresented: $showsChoices, attachmentAnchor: .rect(.bounds), arrowEdge: .leading) {
            VStack(spacing: 0) {
                ForEach(0...5, id: \.self) { count in
                    Button {
                        prepare(); tool.select(count); showsChoices = false
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            BTSelectionIndicator(isSelected: tool.draft.reflections == count)
                            Text(count == 0 ? "关闭" : "\(count)库").foregroundStyle(.btText)
                            Spacer(minLength: 0)
                        }
                        .font(.btBody)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(identifier).\(count)")
                    .accessibilityValue(tool.draft.reflections == count ? "已选" : "未选")
                    .accessibilityAddTraits(tool.draft.reflections == count ? .isSelected : [])
                }
            }
            .padding(.vertical, Spacing.xs)
            .frame(width: choicesWidth)
            .fixedSize(horizontal: false, vertical: true)
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: enabled) { _, active in if !active { showsChoices = false } }
    }
}

/// Native menu labels retain their symbol; choices remain mutually exclusive.
struct BTChoiceMenuItem: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: selected ? "checkmark" : "square") }
            .accessibilityValue(selected ? "已选" : "未选")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("Geometric reference · Light") {
    BTGeometricReferenceButton(tool: GeometricReferenceTool(scene: AngleTrainingScene()),
        enabled: true, size: 48, identifier: "preview.geometry", prepare: {})
        .padding().preferredColorScheme(.light)
}
#Preview("Geometric reference · Dark") {
    BTGeometricReferenceButton(tool: GeometricReferenceTool(scene: AngleTrainingScene()),
        enabled: true, size: 48, identifier: "preview.geometry", prepare: {})
        .padding().preferredColorScheme(.dark)
}
