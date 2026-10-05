import CoreGraphics
import Foundation
import SceneKit

/// Shared world↔loupe mapping for `topDown2DRotated` aim closeup (问题集合 v23).
///
/// **Coordinate contract** (same as `AngleSceneCalculator.bearingDeg` / flat labels):
/// - Planar input: `CGPoint(x: worldX, y: worldZ)`, meters
/// - Screen-up = world **+X**
/// - Screen-right = world **+Z**
///
/// Do **not** use landscape top-down mapping (+X→right, −Z→up) here — AimPoint 2D
/// and most solver stages use the rotated camera.
enum AimCloseupCoords {

    /// Map a world XZ point into loupe/view space (origin = top-leading of `size`
    /// when used for a full view; for the circular loupe, pass the loupe size and
    /// center via `focus` + uniform `scale`).
    static func mapRotated(
        world: CGPoint,
        focus: CGPoint,
        origin: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        let dX = world.x - focus.x
        let dZ = world.y - focus.y
        return CGPoint(
            x: origin.x + dZ * scale,
            y: origin.y - dX * scale
        )
    }
}

// The loupe retains its canonical 2D drawing space. Legacy callers preserve
// the camera projection; Daily Clearance uses a camera-oriented isometry of
// the cloth plane so circular ball outlines retain their physical tangency.
extension AimCloseupSnapshot {
    @MainActor
    func projected(in view: SCNView, surfaceY: Float, destinationRect: CGRect? = nil,
                   preservesPlanarTangency: Bool = false) -> AimCloseupSnapshot? {
        guard let camera = view.pointOfView, view.bounds.width > 1, view.bounds.height > 1 else { return nil }
        let destination = destinationRect ?? view.bounds
        guard destination.width > 1, destination.height > 1 else { return nil }
        let y = surfaceY + Float(ballRadius)
        func world(_ p: CGPoint) -> SCNVector3 { SCNVector3(Float(p.x), y, Float(p.y)) }
        func screen(_ p: CGPoint) -> CGPoint {
            let s = view.projectPoint(world(p))
            return CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
        }
        let f3 = view.projectPoint(world(focus))
        guard f3.z > 0, f3.z < 1 else { return nil }
        let f = screen(focus)
        // A sphere's apparent radius follows the camera's right vector, not a
        // flattened table axis. Use the same uniform scale for all layers.
        let right = camera.presentation.convertVector(SCNVector3(1, 0, 0), to: nil)
        let up = camera.presentation.convertVector(SCNVector3(0, 1, 0), to: nil)
        let horizontalLength = hypot(CGFloat(right.x), CGFloat(right.z))
        let rx = horizontalLength > 1e-6 ? CGFloat(right.x) / horizontalLength : 1
        let rz = horizontalLength > 1e-6 ? CGFloat(right.z) / horizontalLength : 0
        // A rotation/reflection in the cloth plane preserves all lengths and angles.
        // Choose the perpendicular pointing toward screen-down; never foreshorten
        // center spacing while continuing to draw circular balls and ghost rings.
        let downAlignment = rz * CGFloat(up.x) - rx * CGFloat(up.z)
        let downSign: CGFloat = downAlignment >= 0 ? 1 : -1
        let origin = world(focus)
        let edge = view.projectPoint(SCNVector3(origin.x + right.x * Float(ballRadius),
                                              origin.y + right.y * Float(ballRadius),
                                              origin.z + right.z * Float(ballRadius)))
        let pointsPerMeter = hypot(CGFloat(edge.x) - f.x, CGFloat(edge.y) - f.y) / ballRadius
        guard pointsPerMeter.isFinite, pointsPerMeter > 0.001 else { return nil }
        func local(_ p: CGPoint) -> CGPoint {
            if preservesPlanarTangency {
                let dx = p.x - focus.x, dz = p.y - focus.y
                return CGPoint(x: -(-rz * dx + rx * dz) * downSign, y: rx * dx + rz * dz)
            }
            let s = screen(p)
            return CGPoint(x: -(s.y - f.y) / pointsPerMeter,
                           y: (s.x - f.x) / pointsPerMeter)
        }
        func segment(_ s: AimCloseupSegment?) -> AimCloseupSegment? {
            s.map { AimCloseupSegment(start: local($0.start), end: local($0.end)) }
        }
        func norm(_ p: CGPoint) -> CGPoint {
            let s = screen(p)
            return CGPoint(x: (s.x-destination.minX) / destination.width, y: (s.y-destination.minY) / destination.height)
        }
        func radiusScale(at p: CGPoint) -> CGFloat {
            if preservesPlanarTangency { return 1 }
            let w = world(p)
            let center = screen(p)
            let edge = view.projectPoint(SCNVector3(w.x + right.x * Float(ballRadius),
                                                  w.y + right.y * Float(ballRadius),
                                                  w.z + right.z * Float(ballRadius)))
            return hypot(CGFloat(edge.x) - center.x, CGFloat(edge.y) - center.y) / (pointsPerMeter * ballRadius)
        }
        var result = self
        result.cueRadiusScale = cue.map(radiusScale) ?? 1
        result.ghostRadiusScale = ghost.map(radiusScale) ?? 1
        result.focus = .zero
        result.cue = cue.map(local)
        result.ghost = ghost.map(local)
        result.aimPointMarker = aimPointMarker.map(local)
        result.contactMarker = contactMarker.map(local)
        result.aimLine = segment(aimLine)
        result.potLine = segment(potLine)
        result.auxLine = segment(auxLine)
        result.idealLine = segment(idealLine)
        result.focusNorm = norm(focus)
        if let pot = potLine {
            result.sightKeepout = .init(potStartNorm: norm(pot.start), potEndNorm: norm(pot.end),
                                       aimStartNorm: aimLine.map { norm($0.start) },
                                       aimEndNorm: aimLine.map { norm($0.end) })
        } else if let aim = aimLine {
            result.sightKeepout = .init(potStartNorm: norm(focus), potEndNorm: norm(focus),
                                       aimStartNorm: norm(aim.start), aimEndNorm: norm(aim.end),
                                       pocketRadius: 0)
        }
        return result
    }
}

/// Live scene points converted to the actual SwiftUI overlay rect, including 3D's full-screen viewport.
@MainActor
enum DailyCloseupProjection {
    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count >= 3 else { return sorted }
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
        }
        func half(_ values: [CGPoint]) -> [CGPoint] {
            var hull: [CGPoint] = []
            for p in values {
                while hull.count >= 2 && cross(hull[hull.count-2],hull[hull.count-1],p) <= 0 { hull.removeLast() }
                hull.append(p)
            }
            return hull
        }
        return Array(half(sorted).dropLast()) + Array(half(Array(sorted.reversed())).dropLast())
    }

    /// Clip in camera depth before projecting: a visible trajectory may continue
    /// behind a low 3D camera, without invalidating its visible portion.
    static func clippedSegment(_ a: SCNVector3, _ b: SCNVector3, camera: SCNNode) -> (SCNVector3, SCNVector3)? {
        guard let optics = camera.camera else { return nil }
        let da = -camera.presentation.convertPosition(a, from: nil).z
        let db = -camera.presentation.convertPosition(b, from: nil).z
        let near = Float(optics.zNear) * 1.001, far = Float(optics.zFar) * 0.999
        var lower: Float = 0, upper: Float = 1
        let delta = db - da
        if abs(delta) < 1e-8 {
            guard da >= near, da <= far else { return nil }
        } else {
            let t0 = (near - da) / delta, t1 = (far - da) / delta
            lower = max(lower, min(t0, t1)); upper = min(upper, max(t0, t1))
            guard lower <= upper else { return nil }
        }
        func point(_ t: Float) -> SCNVector3 {
            SCNVector3(a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t, a.z + (b.z-a.z)*t)
        }
        return (point(lower), point(upper))
    }

    static func destinationRect(in view: SCNView, frameInWindow: CGRect?) -> CGRect {
        guard let frameInWindow, let window = view.window else { return view.bounds }
        return view.convert(frameInWindow, from: window)
    }

    static func topDownPlayingRect(scene: AngleTrainingScene, view: SCNView, destination: CGRect) -> CGRect {
        let x = AngleSceneCalculator.innerLength/2, z = AngleSceneCalculator.innerWidth/2
        let a = view.projectPoint(SCNVector3(-x,scene.surfaceY,-z))
        let b = view.projectPoint(SCNVector3(x,scene.surfaceY,z))
        return CGRect(x:CGFloat(min(a.x,b.x))-destination.minX,y:CGFloat(min(a.y,b.y))-destination.minY,
                      width:CGFloat(abs(b.x-a.x)),height:CGFloat(abs(b.y-a.y)))
    }

    static func obstacles(snapshot: AimCloseupSnapshot, scene: AngleTrainingScene,
                          view: SCNView, destination: CGRect) -> AimCloseupObstacles {
        var result = AimCloseupObstacles()
        func project(_ p: SCNVector3) -> CGPoint? {
            let value = view.projectPoint(p)
            guard value.x.isFinite, value.y.isFinite, value.z > 0, value.z < 1 else { return nil }
            return CGPoint(x: CGFloat(value.x)-destination.minX, y: CGFloat(value.y)-destination.minY)
        }
        func line(_ a: SCNVector3, _ b: SCNVector3) {
            if let camera = view.pointOfView,
               let (a, b) = clippedSegment(a, b, camera: camera),
               let start = project(a), let end = project(b) {
                result.segments.append(.init(start: start, end: end))
            }
        }
        func segment(_ s: AimCloseupSegment?) {
            guard let s else { return }
            // Assists are drawn on the cloth; sphere/ghost protection is separate.
            line(SCNVector3(Float(s.start.x),scene.surfaceY,Float(s.start.y)),
                 SCNVector3(Float(s.end.x),scene.surfaceY,Float(s.end.y)))
        }
        segment(snapshot.aimLine)
        segment(snapshot.potLine)
        segment(scene.idealObjectLine)
        for (a,b) in zip(scene.closeupCuePath,scene.closeupCuePath.dropFirst()) {
            line(SCNVector3(a.x,scene.surfaceY,a.z),SCNVector3(b.x,scene.surfaceY,b.z))
        }
        if let number = snapshot.targetBallNumber, let path = scene.closeupObjectPaths["_\(number)"] {
            for (a,b) in zip(path,path.dropFirst()) {
                line(SCNVector3(a.x,scene.surfaceY,a.z),SCNVector3(b.x,scene.surfaceY,b.z))
            }
        }
        func bounds(_ node: SCNNode) -> CGRect? {
            let (lo,hi) = node.boundingBox
            var points: [CGPoint] = []
            for x in [lo.x,hi.x] { for y in [lo.y,hi.y] { for z in [lo.z,hi.z] {
                if let p = project(node.presentation.convertPosition(SCNVector3(x,y,z),to:nil)) { points.append(p) }
            } } }
            guard let first = points.first else { return nil }
            return points.dropFirst().reduce(CGRect(origin:first,size:.zero)) { rect,p in
                CGRect(x:min(rect.minX,p.x),y:min(rect.minY,p.y),
                       width:max(rect.maxX,p.x)-min(rect.minX,p.x),height:max(rect.maxY,p.y)-min(rect.minY,p.y))
            }
        }
        for node in scene.closeupPocketNodes {
            if let rect = bounds(node) { result.rectangles.append(rect.insetBy(dx:-6,dy:-6)) }
        }
        if let cue = scene.cueStick?.rootNode, !cue.isHidden, cue.presentation.opacity > 0.01,
           let camera = view.pointOfView {
            // Project the complete oriented mesh envelope, not a large axis-aligned
            // screen rectangle or a guessed direction-only shaft. Clip its edges
            // first so a butt extending behind the camera remains well defined.
            let (lo,hi) = cue.boundingBox
            let vertices = (0..<8).map { index in
                cue.presentation.convertPosition(SCNVector3(index & 4 == 0 ? lo.x : hi.x,
                    index & 2 == 0 ? lo.y : hi.y,index & 1 == 0 ? lo.z : hi.z),to:nil)
            }
            var projected: [CGPoint] = []
            for i in 0..<8 {
                for axis in [1,2,4] where i & axis == 0 {
                    if let (a,b) = clippedSegment(vertices[i],vertices[i|axis],camera:camera) {
                        if let p = project(a) { projected.append(p) }
                        if let p = project(b) { projected.append(p) }
                    }
                }
            }
            let hull = convexHull(projected)
            if hull.count >= 3 { result.polygons.append(.init(vertices:hull)) }
        }
        for (key,node) in scene.allBallNodes where !node.isHidden {
            guard let rect = bounds(node) else { continue }
            let disc = AimCloseupObstacles.Disc(center:CGPoint(x:rect.midX,y:rect.midY),radius:hypot(rect.width,rect.height)/2+4)
            let p = node.position
            if key == PositionPlayBall.cueKey || hypot(CGFloat(p.x)-snapshot.focus.x,CGFloat(p.z)-snapshot.focus.y) < snapshot.ballRadius {
                result.discs.append(disc)
            } else { result.otherBalls.append(disc) }
        }
        if let ghost = scene.ghostBallNode, !ghost.isHidden, let rect = bounds(ghost) {
            result.discs.append(.init(center:CGPoint(x:rect.midX,y:rect.midY),radius:hypot(rect.width,rect.height)/2+6))
        }
        return result
    }
}
