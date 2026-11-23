#if DEBUG || RENDER_QUALITY_VALIDATION
import SceneKit

/// Explicit launch-argument fixture; normal questions retain their random layout.
enum RenderQualityFixture {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-v62.fixture") }

    static func question(surfaceY: Float) -> AngleQuestion {
        let cue = SCNVector3(-0.45, surfaceY + AngleSceneCalculator.ballRadius, 0)
        let target = SCNVector3(0.35, cue.y, 0.12)
        let pocketIndex = 3
        let pocket = AngleCalculator.pockets[pocketIndex]
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY)
        let outward = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let ghost = SIMD2<Float>(target.x,target.z) - 2 * AngleSceneCalculator.ballRadius * outward
        let incoming = simd_normalize(ghost - SIMD2<Float>(cue.x,cue.z))
        let angle = acos(Double(max(-1,min(1,simd_dot(incoming,outward))))) * 180 / .pi
        return AngleQuestion(targetBall: AngleSceneCalculator.sceneToNormalized(position: target),
                             cueBall: AngleSceneCalculator.sceneToNormalized(position: cue),
                             pocket: pocket, actualAngle: angle, pocketType: pocket.type, pocketIndex: pocketIndex)
    }
}
#endif
