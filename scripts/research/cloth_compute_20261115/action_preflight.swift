import SceneKit
import Metal
let device = MTLCreateSystemDefaultDevice()!
let scene = SCNScene(), node = SCNNode()
scene.rootNode.addChildNode(node)
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene; renderer.isPlaying = false
var calls = 0
node.runAction(.customAction(duration: 600) { node, elapsed in
    calls += 1
    node.simdPosition.y = Float(1-cos(Double(elapsed)*4))*0.018
})
SCNTransaction.flush()
for time in [1.0, 1.11, 1.22, 1.33] {
    renderer.update(atTime: time)
    print(time, calls, node.presentation.simdPosition.y);fflush(stdout)
}
precondition(node.presentation.simdPosition.y > 0.001, "Action did not advance with explicit update")
