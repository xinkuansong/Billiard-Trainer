import SwiftUI
import SceneKit

/// Shared constraint-draw gesture overlay for Silu / PlanThree (C17).
/// Captures drag in a named coordinate space, unprojects via the scene frame,
/// and forwards normalized canvas points to the host VM.
struct SolveConstraintDrawingOverlay: View {
    let coordinateSpaceName: String
    let sceneFrame: CGRect
    let unproject: (CGPoint) -> SCNVector3?
    let onDrag: (_ start: CanvasPoint, _ current: CanvasPoint, _ ended: Bool) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                    .onChanged { value in
                        handle(start: value.startLocation, current: value.location, ended: false)
                    }
                    .onEnded { value in
                        handle(start: value.startLocation, current: value.location, ended: true)
                    }
            )
    }

    private func handle(start: CGPoint, current: CGPoint, ended: Bool) {
        guard sceneFrame != .zero,
              let s = normalized(from: start),
              let c = normalized(from: current) else { return }
        onDrag(s, c, ended)
    }

    private func normalized(from point: CGPoint) -> CanvasPoint? {
        let local = CGPoint(x: point.x - sceneFrame.minX, y: point.y - sceneFrame.minY)
        guard let world = unproject(local) else { return nil }
        let n = AngleSceneCalculator.sceneToNormalized(position: world)
        return CanvasPoint(x: Double(n.x), y: Double(n.y))
    }
}
