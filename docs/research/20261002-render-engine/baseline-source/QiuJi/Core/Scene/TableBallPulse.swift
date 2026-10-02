import SceneKit

/// Shared library/palette ball pulse (C17): absolute scale 1.7 / 0.18s → 1.0 / 0.24s.
enum TableBallPulse {
    static let actionKey = "libraryPulse"

    static func pulse(_ node: SCNNode) {
        node.removeAction(forKey: actionKey)
        let up = SCNAction.scale(to: 1.7, duration: 0.18)
        up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24)
        down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: actionKey)
    }
}
