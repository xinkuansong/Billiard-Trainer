import SwiftUI
import SceneKit

/// One independent, on-demand viewport. Changes never touch a training scene.
struct AppearanceCombinationPreview: UIViewRepresentable {
    @ObservedObject private var prefs = UserPreferences.shared
    let label: String
    let identifier: String
    var showsRoomOverview = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = context.coordinator.scene
        scene.setupScene(mobileRendering: true)
        scene.hideAllBalls()
        scene.setCameraMode(.perspective3D, animated: false)
        // Keep the material-preview direction and scale, but move the orthographic
        // ray origins inside the room so the near wall cannot occlude the table.
        scene.cameraNode.position = SCNVector3(1.595, 1.8425, 1.925)
        scene.cameraNode.look(at: SCNVector3(0, 0.55, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 1.35
        if showsRoomOverview {
            scene.cameraNode.position = SCNVector3(3.2, 1.8, 1.2)
            scene.cameraNode.look(at: SCNVector3(0, 1.15, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            scene.cameraNode.camera?.usesOrthographicProjection = false
            scene.cameraNode.camera?.fieldOfView = 60
        }
        scene.installReferenceRoom(style: prefs.roomStyle)
        view.scene = scene
        view.pointOfView = scene.cameraNode
        view.antialiasingMode = .multisampling4X
        view.isPlaying = false
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityTraits = .image
        view.layer.cornerRadius = BTRadius.md
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let scene = context.coordinator.scene
        scene.applyTableStyle(prefs.tableStyle, showsSights: prefs.showsTableSights)
        scene.applyClothColor(prefs.clothColor)
        scene.installReferenceRoom(style: prefs.roomStyle)
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = label
        // Report the installed materials, not just the preference values.
        view.accessibilityValue = [
            "球房：" + (scene.installedReferenceRoomStyle?.displayName ?? "默认"),
            "球桌：" + scene.installedTableStyle.displayName,
            "台呢：" + scene.installedClothColor.displayName,
            scene.showsTableSights ? "颗星参考点显示" : "颗星参考点隐藏"
        ].joined(separator: "，")
        view.setNeedsDisplay()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SCNView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return CGSize(width: width, height: width * 0.64)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.scene = nil
    }

    final class Coordinator {
        let scene = AngleTrainingScene()
    }
}

#Preview("Light") {
    AppearanceCombinationPreview(label: "当前搭配预览", identifier: "appearance.preview")
        .padding().preferredColorScheme(.light)
}
#Preview("Dark") {
    AppearanceCombinationPreview(label: "当前搭配预览", identifier: "appearance.preview")
        .padding().preferredColorScheme(.dark)
}
