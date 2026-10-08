import SwiftUI
import SceneKit

/// Teaching adapter for the C56 table template; no daily rules or score session.
struct ShotSimulationView: View {
    static var defaultBoard: BoardSnapshot {
        let y = BTTablePhysics.surfaceY + AngleSceneCalculator.ballRadius
        let cueN = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(-0.35, y, 0.22))
        let tgtN = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(0.55, y, -0.18))
        return BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: Double(cueN.x), y: Double(cueN.y)),
            "_8": CanvasPoint(x: Double(tgtN.x), y: Double(tgtN.y)),
        ])
    }

    var body: some View { FreePlayView(entryMode: .shotSimulation) }
}

#Preview("Light") { NavigationStack { ShotSimulationView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { ShotSimulationView() }.preferredColorScheme(.dark) }
