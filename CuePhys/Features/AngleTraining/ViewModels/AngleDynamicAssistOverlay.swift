import SceneKit
import UIKit
import simd

/// Display-only additions owned by AngleDynamicViewModel. The shared ghost ring,
/// model assets, ball registry and shot calculation remain untouched.
@MainActor
final class AngleDynamicAssistOverlay {
    private weak var scene: AngleTrainingScene?
    let root = SCNNode()
    private let ghostRoot = SCNNode()
    private let aimRoot = SCNNode()
    private let potRoot = SCNNode()
    private var showsGhost = false
    private var showsAim = false
    private var showsPot = false
    private var input: Input?
    private var renderedInput: Input?

    private struct Input: Equatable {
        let cue: SIMD3<Float>
        let ghost: SIMD3<Float>
        let pocket: SIMD3<Float>
    }

    init() {
        root.name = "angleDynamic.assists"
        ghostRoot.name = "angleDynamic.ghost3D"
        aimRoot.name = "angleDynamic.aimPipe"
        potRoot.name = "angleDynamic.potPipe"
        [ghostRoot, aimRoot, potRoot].forEach { root.addChildNode($0) }
        root.isHidden = true
    }

    func attach(to scene: AngleTrainingScene) {
        self.scene = scene
        scene.rootNode.addChildNode(root)
    }

    func setVisibility(ghost: Bool, aim: Bool, pot: Bool) {
        showsGhost = ghost; showsAim = aim; showsPot = pot
        refresh()
    }

    func hide() {
        input = nil
        root.isHidden = true
    }

    func update(cue: SCNVector3, ghost: SCNVector3, pocket: SCNVector3) {
        input = Input(cue: SIMD3(cue.x, cue.y, cue.z), ghost: SIMD3(ghost.x, ghost.y, ghost.z),
                      pocket: SIMD3(pocket.x, pocket.y, pocket.z))
        refresh()
    }

    private func refresh() {
        guard let scene, let input, showsGhost || showsAim || showsPot else {
            root.isHidden = true
            return
        }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        defer { SCNTransaction.commit() }
        root.isHidden = false
        ghostRoot.isHidden = !showsGhost
        aimRoot.isHidden = !showsAim
        potRoot.isHidden = !showsPot
        if showsGhost {
            if ghostRoot.childNodes.isEmpty { makeGhost() }
            ghostRoot.simdPosition = input.ghost
        }
        if input != renderedInput {
            aimRoot.childNodes.forEach { $0.removeFromParentNode() }
            potRoot.childNodes.forEach { $0.removeFromParentNode() }
            renderedInput = input
        }
        guard showsAim || showsPot,
              let outline = Self.pipeOutline(cue: input.cue, ghost: input.ghost, pocket: input.pocket,
                                             radius: AngleSceneCalculator.ballRadius) else { return }
        if showsAim && aimRoot.childNodes.isEmpty {
            makePipe(outline.aim, direction: input.ghost - input.cue, color: .white, parent: aimRoot, scene: scene)
        }
        if showsPot && potRoot.childNodes.isEmpty {
            makePipe(outline.pot, direction: input.pocket - input.ghost, color: .black, parent: potRoot, scene: scene)
        }
    }

    /// X-Z plane, metres. Both ball-width strips meet at G with a shared miter;
    /// this is the same boundary intersection used by the existing pipe demo.
    static func pipeOutline(cue: SIMD3<Float>, ghost: SIMD3<Float>, pocket: SIMD3<Float>,
                            radius: Float) -> (aim: [SIMD3<Float>], pot: [SIMD3<Float>])? {
        let incoming = SIMD3(ghost.x - cue.x, 0, ghost.z - cue.z)
        let outgoing = SIMD3(pocket.x - ghost.x, 0, pocket.z - ghost.z)
        let aLength = simd_length(incoming), pLength = simd_length(outgoing)
        guard aLength.isFinite, pLength.isFinite, aLength > 0.000001, pLength > 0.000001 else { return nil }
        let a = incoming / aLength, p = outgoing / pLength
        let aSide = SIMD3(-a.z, 0, a.x), pSide = SIMD3(-p.z, 0, p.x)
        let denominator = 1 + simd_dot(aSide, pSide)
        guard denominator > 0.000001 else { return nil }
        let miter = (aSide + pSide) * (radius / denominator)
        // For very short segments the miter may pass the endpoint. Intersect a
        // convex extended strip with its endpoint plane instead of folding a quad.
        func cap(_ polygon: [SIMD3<Float>], at point: SIMD3<Float>, normal: SIMD3<Float>) -> [SIMD3<Float>] {
            var result: [SIMD3<Float>] = []
            for i in polygon.indices {
                let from = polygon[i], to = polygon[(i + 1) % polygon.count]
                let d0 = simd_dot(from - point, normal), d1 = simd_dot(to - point, normal)
                if d0 >= 0 { result.append(from) }
                if (d0 >= 0) != (d1 >= 0) { result.append(from + (to - from) * (d0 / (d0 - d1))) }
            }
            return result
        }
        // Keep both source cap vertices strictly outside the clipping plane;
        // near-zero signed distances would make its parallel edge ill-conditioned.
        let start = ghost - a * (max(aLength, abs(simd_dot(miter, a))) + radius)
        let end = ghost + p * (max(pLength, abs(simd_dot(miter, p))) + radius)
        let aim = cap([start - aSide * radius, start + aSide * radius, ghost + miter, ghost - miter], at: cue, normal: a)
        let pot = cap([ghost - miter, ghost + miter, end + pSide * radius, end - pSide * radius], at: pocket, normal: -p)
        return (aim, pot)
    }

    private func makePipe(_ outline: [SIMD3<Float>], direction: SIMD3<Float>, color: UIColor, parent: SCNNode,
                          scene: AngleTrainingScene) {
        guard outline.count >= 3 else { return }
        let v = outline.map { SCNVector3($0) }
        let triangles = (1..<(v.count - 1)).map { [v[0], v[$0], v[$0 + 1]] }
        if let fill = scene.makeTableFill(triangles: triangles,
                                          color: color.withAlphaComponent(0.20)) {
            parent.addChildNode(fill)
        }
        let side = simd_normalize(SIMD3(-direction.z, 0, direction.x))
        for i in outline.indices {
            let next = (i + 1) % outline.count
            // Only the two long boundaries are stroked; endpoint/joint caps are open.
            let delta = outline[next] - outline[i]
            guard simd_length(delta) > 0.000001, abs(simd_dot(delta, side)) < 0.000001 else { continue }
            let edge = scene.addLine(from: v[i], to: v[next], color: color, radius: 0.0005,
                                     placement: .table, layer: .aiming)
            parent.addChildNode(edge)
        }
    }

    private func makeGhost() {
        let radius = AngleSceneCalculator.ballRadius
        // Preserve the frosted shader from installOverlapGhost (V022/V023).
        // Do not copy the demo's ring hiding, ring recoloring or extra footprint.
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float3 N = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
        float3 V = normalize((scn_frame.inverseViewTransform * float4(-_surface.position, 0.0)).xyz);
        float3 L = normalize(float3(-0.55, 0.80, -0.35));
        float diffuse = max(dot(N, L), 0.0);
        float highlight = pow(max(dot(N, normalize(L + V)), 0.0), 28.0);
        float rim = pow(1.0 - abs(dot(N, V)), 3.0);
        float shade = 0.20 + 0.67 * diffuse;
        float3 color = float3(0.90, 0.96, 1.0) * shade + float3(0.6) * highlight;
        float alpha = clamp(0.43 + 0.18 * rim + 0.24 * highlight, 0.0, 0.85);
        _output.color = float4(min(color, float3(1.0)) * alpha, alpha);
        """]
        sphere.materials = [material]
        let shell = SCNNode(geometry: sphere)
        shell.castsShadow = false
        ghostRoot.addChildNode(shell)

        let contact = SCNPlane(width: CGFloat(radius * 2), height: CGFloat(radius * 2))
        let shadow = SCNMaterial()
        shadow.lightingModel = .constant
        shadow.writesToDepthBuffer = false
        shadow.blendMode = .alpha
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = false
        shadow.diffuse.contents = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
            .image { renderer in
                let colors = [UIColor.black.withAlphaComponent(0.58).cgColor,
                              UIColor.black.withAlphaComponent(0.30).cgColor, UIColor.clear.cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                                 locations: [0, 0.38, 1]) else { return }
                renderer.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
                    endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
            }
        contact.materials = [shadow]
        let contactNode = SCNNode(geometry: contact)
        contactNode.eulerAngles.x = -.pi / 2
        contactNode.position.y = -radius + 0.0002
        contactNode.castsShadow = false
        ghostRoot.addChildNode(contactNode)
    }
}
