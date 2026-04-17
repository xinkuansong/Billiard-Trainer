import Foundation
import SceneKit

/// Maps between AngleCalculator's normalised 2D coordinates (x: 0→1, y: 0→0.5)
/// and SceneKit world coordinates used by AngleTrainingScene.
enum AngleSceneCalculator {

    // MARK: - Table dimensions (Chinese 8-ball, metres)

    static let innerLength: Float = 2.54
    static let innerWidth: Float  = 1.27
    static let ballRadius: Float  = 0.028575  // 57.15mm diameter

    // MARK: - Coordinate mapping

    /// Convert AngleCalculator normalised point to SceneKit world position.
    /// Normalised x ∈ [0, 1] maps to scene X ∈ [-innerLength/2, +innerLength/2].
    /// Normalised y ∈ [0, 0.5] maps to scene Z ∈ [-innerWidth/2, +innerWidth/2].
    static func normalizedToScene(point: CGPoint, surfaceY: Float) -> SCNVector3 {
        let sceneX = Float(point.x) * innerLength - innerLength / 2
        let sceneZ = Float(point.y) * 2.0 * innerWidth - innerWidth / 2
        return SCNVector3(sceneX, surfaceY + ballRadius, sceneZ)
    }

    /// Convert SceneKit world position back to normalised point.
    static func sceneToNormalized(position: SCNVector3) -> CGPoint {
        let nx = (position.x + innerLength / 2) / innerLength
        let ny = (position.z + innerWidth / 2) / (2.0 * innerWidth)
        return CGPoint(x: CGFloat(nx), y: CGFloat(ny))
    }

    /// Ghost ball center: `targetCenter - 2R * normalize(pocket - targetCenter)`.
    /// Per 45-aiming-principles.mdc, the ghost ball sits on the pocket-line extension
    /// opposite to the pocket, at distance 2R from the target ball.
    static func ghostBallPosition(
        targetBall: SCNVector3,
        pocket: SCNVector3,
        ballRadius: Float
    ) -> SCNVector3 {
        let dx = pocket.x - targetBall.x
        let dz = pocket.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.0001 else { return targetBall }
        let dirX = dx / dist
        let dirZ = dz / dist
        return SCNVector3(
            targetBall.x - 2 * ballRadius * dirX,
            targetBall.y,
            targetBall.z - 2 * ballRadius * dirZ
        )
    }

    /// d/R = 2sin(α). Lateral displacement in ball-radius units.
    static func lateralDisplacement(cutAngle: Double) -> Double {
        2.0 * sin(cutAngle * .pi / 180.0)
    }

    /// Lateral displacement in millimetres: d = 2R × sin(α).
    static func lateralDisplacementMM(cutAngle: Double, ballRadius: Double) -> Double {
        2.0 * ballRadius * sin(cutAngle * .pi / 180.0)
    }

    /// Contact point offset = sin(α), as fraction of R (derived quantity).
    static func contactPointOffset(cutAngle: Double) -> Double {
        sin(cutAngle * .pi / 180.0)
    }

    // MARK: - Pocket positions (SceneKit world coords)

    /// Six pocket positions at table surface level.
    static func pocketPositions(surfaceY: Float) -> [SCNVector3] {
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let y = surfaceY
        return [
            SCNVector3(-halfL, y, -halfW),  // 左上 (top-left)
            SCNVector3( halfL, y, -halfW),  // 右上 (top-right)
            SCNVector3(-halfL, y,  halfW),  // 左下 (bottom-left)
            SCNVector3( halfL, y,  halfW),  // 右下 (bottom-right)
            SCNVector3(     0, y, -halfW),  // 上中 (top-center)
            SCNVector3(     0, y,  halfW),  // 下中 (bottom-center)
        ]
    }

    // MARK: - Cut angle (degrees)

    /// Cut angle α between the pocket line (target→pocket) and the strike line (cue→ghost).
    /// Returns value in degrees [0, 90].
    static func cutAngle(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Double {
        let pocketDirX = Double(pocket.x - targetBall.x)
        let pocketDirZ = Double(pocket.z - targetBall.z)
        let pocketDist = sqrt(pocketDirX * pocketDirX + pocketDirZ * pocketDirZ)
        guard pocketDist > 0.0001 else { return 0 }

        let ghost = ghostBallPosition(targetBall: targetBall, pocket: pocket, ballRadius: ballRadius)
        let strikeDirX = Double(ghost.x - cueBall.x)
        let strikeDirZ = Double(ghost.z - cueBall.z)
        let strikeDist = sqrt(strikeDirX * strikeDirX + strikeDirZ * strikeDirZ)
        guard strikeDist > 0.0001 else { return 0 }

        let pnX = pocketDirX / pocketDist
        let pnZ = pocketDirZ / pocketDist
        let snX = strikeDirX / strikeDist
        let snZ = strikeDirZ / strikeDist

        let dot = max(-1, min(1, pnX * snX + pnZ * snZ))
        let angle = acos(dot) * 180.0 / .pi
        return min(angle, 90)
    }

    // MARK: - Feasibility

    static let maxCutAngle: Double = 80

    /// Whether a pocket is viable for the given ball configuration.
    static func isFeasible(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Bool {
        let angle = cutAngle(cueBall: cueBall, targetBall: targetBall, pocket: pocket)
        if angle >= maxCutAngle { return false }
        if isCueBallBlocking(cueBall: cueBall, targetBall: targetBall, pocket: pocket) { return false }
        return true
    }

    /// Whether the cue ball sits on the pocket line between target and pocket,
    /// blocking the target ball's path into the pocket.
    static func isCueBallBlocking(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) -> Bool {
        let lineX = pocket.x - targetBall.x
        let lineZ = pocket.z - targetBall.z
        let lineLenSq = lineX * lineX + lineZ * lineZ
        guard lineLenSq > 0.0001 else { return false }

        let toX = cueBall.x - targetBall.x
        let toZ = cueBall.z - targetBall.z
        let t = (toX * lineX + toZ * lineZ) / lineLenSq
        guard t > 0, t < 1 else { return false }

        let projX = targetBall.x + t * lineX
        let projZ = targetBall.z + t * lineZ
        let distSq = (cueBall.x - projX) * (cueBall.x - projX) + (cueBall.z - projZ) * (cueBall.z - projZ)
        return distSq < (2.5 * ballRadius) * (2.5 * ballRadius)
    }

    // MARK: - Contact point position

    /// Contact point on the target ball surface, in the direction from cue ball.
    static func contactPointPosition(cueBall: SCNVector3, targetBall: SCNVector3) -> SCNVector3 {
        let dx = cueBall.x - targetBall.x
        let dz = cueBall.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.001 else { return targetBall }
        return SCNVector3(
            targetBall.x + ballRadius * (dx / dist),
            targetBall.y,
            targetBall.z + ballRadius * (dz / dist)
        )
    }

    // MARK: - Ball overlap / distance checks

    /// Horizontal distance between two ball positions (ignoring Y).
    static func horizontalDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }

    /// Whether two balls overlap (center distance < 2R).
    static func ballsOverlap(_ a: SCNVector3, _ b: SCNVector3) -> Bool {
        horizontalDistance(a, b) < 2 * ballRadius
    }

    /// Clamp a position so it stays >= 2R from the other ball and inside table bounds.
    static func clampBallPosition(_ pos: SCNVector3, otherBall: SCNVector3, surfaceY: Float) -> SCNVector3 {
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let r = ballRadius
        var x = max(-halfL + r, min(halfL - r, pos.x))
        var z = max(-halfW + r, min(halfW - r, pos.z))

        let dx = x - otherBall.x
        let dz = z - otherBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        let minDist: Float = 2 * r + 0.001
        if dist < minDist, dist > 0.0001 {
            x = otherBall.x + (dx / dist) * minDist
            z = otherBall.z + (dz / dist) * minDist
            x = max(-halfL + r, min(halfL - r, x))
            z = max(-halfW + r, min(halfW - r, z))
        }

        return SCNVector3(x, surfaceY + ballRadius, z)
    }

    /// Clamp a position so it stays > 2R from any pocket center.
    static func clampAwayFromPockets(_ pos: SCNVector3, surfaceY: Float) -> SCNVector3 {
        let pockets = pocketPositions(surfaceY: surfaceY)
        var x = pos.x
        var z = pos.z
        let minDist: Float = 2 * ballRadius + 0.005
        for p in pockets {
            let dx = x - p.x
            let dz = z - p.z
            let dist = sqrtf(dx * dx + dz * dz)
            if dist < minDist, dist > 0.0001 {
                x = p.x + (dx / dist) * minDist
                z = p.z + (dz / dist) * minDist
            }
        }
        let halfL = innerLength / 2
        let halfW = innerWidth / 2
        let r = ballRadius
        x = max(-halfL + r, min(halfL - r, x))
        z = max(-halfW + r, min(halfW - r, z))
        return SCNVector3(x, pos.y, z)
    }

    // MARK: - Thickness name (通称)

    static func thicknessName(cutAngle: Double) -> String {
        if cutAngle < 2 { return "全球" }
        if abs(cutAngle - 7.5) < 3 { return "≈1/4 球" }
        if abs(cutAngle - 10) < 2 { return "≈1/3 球" }
        if abs(cutAngle - 30) < 5 { return "半球" }
        if abs(cutAngle - 48.6) < 5 { return "3/4 球" }
        if cutAngle > 80 { return "极薄球" }
        return "—"
    }
}
