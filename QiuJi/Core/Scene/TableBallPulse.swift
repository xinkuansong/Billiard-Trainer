import SceneKit
import ObjectiveC
import simd

/// Preserve the imported model's physical scale through feedback and interruption.
enum TableBallPulse {
    static let actionKey = "libraryPulse"
    private static let dragKey = "dragPulse"
    private static var baselineKey: UInt8 = 0
    private final class Baseline: NSObject {
        let scale: SCNVector3
        let pivot: simd_float4x4
        init(_ node: SCNNode) { scale = node.scale; pivot = node.simdPivot }
    }

    private static func baseline(_ node: SCNNode) -> Baseline {
        if let saved = objc_getAssociatedObject(node, &baselineKey) as? Baseline { return saved }
        let saved = Baseline(node)
        objc_setAssociatedObject(node, &baselineKey, saved, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return saved
    }

    private static func baseScale(_ node: SCNNode) -> SCNVector3 { baseline(node).scale }

    /// Grow above the support plane. The visual pivot absorbs the lift; the root
    /// position remains the physical ball centre used by aiming and simulation.
    private static func applyScale(_ scale: SCNVector3, to node: SCNNode) {
        let saved = baseline(node)
        node.scale = scale
        let factor = saved.scale.y != 0 ? scale.y / saved.scale.y : 1
        let lift = BallPhysics.radius * max(0, factor - 1)
        // Imported balls can have any spin orientation. Convert world-up through
        // the current linear transform instead of lifting along the ball's local Y.
        let local = node.simdWorldTransform.inverse * SIMD4<Float>(0, lift, 0, 0)
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(-local.x, -local.y, -local.z, 1)
        node.simdPivot = saved.pivot * translation
    }

    static func restore(_ node: SCNNode) {
        let base = baseScale(node)
        node.removeAction(forKey: actionKey)
        node.removeAction(forKey: dragKey)
        node.scale = base
        node.simdPivot = baseline(node).pivot
    }

    private static func scaleAction(from: SCNVector3, to: SCNVector3, duration: TimeInterval) -> SCNAction {
        .customAction(duration: duration) { node, elapsed in
            let t = min(1, Float(elapsed) / Float(duration))
            let u = t * t * (3 - 2 * t)
            applyScale(SCNVector3(from.x+(to.x-from.x)*u,
                                 from.y+(to.y-from.y)*u,
                                 from.z+(to.z-from.z)*u), to: node)
        }
    }

    static func pulse(_ node: SCNNode) {
        restore(node)
        let base = baseScale(node)
        let enlarged = SCNVector3(base.x*1.7,base.y*1.7,base.z*1.7)
        node.runAction(.sequence([
            scaleAction(from:base,to:enlarged,duration:0.18),
            scaleAction(from:enlarged,to:base,duration:0.24)
        ]), forKey:actionKey)
    }

    static func beginDrag(_ node: SCNNode) {
        restore(node)
        let base = baseScale(node)
        let enlarged = SCNVector3(base.x*1.15,base.y*1.15,base.z*1.15)
        node.runAction(scaleAction(from:base,to:enlarged,duration:0.1),forKey:dragKey)
    }

    static func endDrag(_ node: SCNNode) {
        let current = node.presentation.scale
        node.removeAction(forKey:dragKey)
        node.runAction(scaleAction(from:current,to:baseScale(node),duration:0.15),forKey:dragKey)
    }
}
