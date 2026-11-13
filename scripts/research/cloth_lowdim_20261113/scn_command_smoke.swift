import Foundation
import AppKit
import SceneKit
import Metal
import QuartzCore
import Darwin

// Host submission smoke only: no production scene/shader changes and no A/B performance claim.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let began = CACurrentMediaTime()
DispatchQueue.global().asyncAfter(deadline: .now() + 55) {
    fputs("SceneKit smoke watchdog exceeded 55 seconds\n", stderr)
    _exit(124)
}
func require(_ value: Bool, _ message: String) throws {
    if !value { throw NSError(domain: "SCNCommandSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw NSError(domain: "SCNCommandSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: message]) }
    return value
}
func json(_ value: Any, _ name: String) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent(name))
}
func completed(_ command: MTLCommandBuffer) throws {
    try require(command.status == .completed, "Command failed: \(String(describing: command.error))")
}

let device = try unwrap(MTLCreateSystemDefaultDevice(), "No Metal device")
let queue = try unwrap(device.makeCommandQueue(), "No command queue")
let scene = SCNScene()
scene.background.contents = NSColor(srgbRed: 0.025, green: 0.025, blue: 0.025, alpha: 1)
let cloth = SCNMaterial()
cloth.lightingModel = .physicallyBased
cloth.diffuse.contents = NSColor(srgbRed: 0.06, green: 0.55, blue: 0.12, alpha: 1)
cloth.roughness.contents = 0.7
cloth.metalness.contents = 0.0
let box = SCNBox(width: 3, height: 0.1, length: 1.5, chamferRadius: 0)
box.materials = [cloth]
scene.rootNode.addChildNode(SCNNode(geometry: box))
let sphere = SCNSphere(radius: 0.2)
sphere.segmentCount = 32
sphere.firstMaterial!.lightingModel = .physicallyBased
sphere.firstMaterial!.diffuse.contents = NSColor.white
sphere.firstMaterial!.roughness.contents = 0.3
let ball = SCNNode(geometry: sphere)
ball.position = SCNVector3(0.3, 0.25, 0)
scene.rootNode.addChildNode(ball)
let lamp = SCNNode()
lamp.light = SCNLight(); lamp.light!.type = .omni; lamp.light!.intensity = 1200
lamp.position = SCNVector3(-1, 3, 2)
scene.rootNode.addChildNode(lamp)
let camera = SCNCamera()
camera.wantsHDR = true; camera.wantsExposureAdaptation = false; camera.exposureOffset = -0.1
camera.minimumExposure = -2; camera.maximumExposure = 2
camera.screenSpaceAmbientOcclusionIntensity = 0
camera.zNear = 0.01; camera.zFar = 50; camera.fieldOfView = 50
let eye = SCNNode(); eye.camera = camera; eye.position = SCNVector3(0, 2, 3.5)
eye.look(at: SCNVector3(0, 0, 0)); scene.rootNode.addChildNode(eye)
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene; renderer.pointOfView = eye
renderer.autoenablesDefaultLighting = false; renderer.isPlaying = false
let width = 700, height = 400, rowBytes = ((700 * 4 + 255) / 256) * 256
let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
descriptor.usage = [.renderTarget, .shaderRead]; descriptor.storageMode = .private
let color = try unwrap(device.makeTexture(descriptor: descriptor), "No color target")
descriptor.textureType = .type2DMultisample; descriptor.sampleCount = 4
let multisample = try unwrap(device.makeTexture(descriptor: descriptor), "No MSAA target")
descriptor.pixelFormat = .depth32Float_stencil8; descriptor.usage = .renderTarget
let depth = try unwrap(device.makeTexture(descriptor: descriptor), "No depth/stencil")
let staging = try unwrap(device.makeBuffer(length: rowBytes * height, options: .storageModeShared), "No staging")
var timings = [[String: Any]]()

func sentinel() throws {
    let command = try unwrap(queue.makeCommandBuffer(), "No clear command")
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = color
    pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 1, 1)
    let encoder = try unwrap(command.makeRenderCommandEncoder(descriptor: pass), "No clear encoder")
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted(); try completed(command)
}
func render(_ count: Int, _ phase: String) throws {
    SCNTransaction.flush()
    try sentinel()
    for frame in 0..<count {
        try autoreleasepool {
            let start = CACurrentMediaTime()
            let command = try unwrap(queue.makeCommandBuffer(), "No render command")
            command.label = "scn-command-smoke-\(phase)-\(frame)"
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = multisample; pass.colorAttachments[0].resolveTexture = color
            pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            pass.depthAttachment.texture = depth; pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.storeAction = .dontCare; pass.depthAttachment.clearDepth = 1
            pass.stencilAttachment.texture = depth; pass.stencilAttachment.loadAction = .clear
            pass.stencilAttachment.storeAction = .dontCare; pass.stencilAttachment.clearStencil = 0
            renderer.render(atTime: 1, viewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: command, passDescriptor: pass)
            let encoded = CACurrentMediaTime()
            command.commit(); command.waitUntilCompleted(); try completed(command)
            let span = (command.gpuEndTime - command.gpuStartTime) * 1000
            try require(command.gpuStartTime > 0 && span.isFinite && span > 0, "Nonpositive/unavailable GPU span")
            timings.append(["phase": phase, "frame": frame, "status": "completed", "gpuStartTime": command.gpuStartTime,
                            "gpuEndTime": command.gpuEndTime, "gpuSpanMS": span,
                            "cpuEncodeMS": (encoded-start)*1000, "cpuWallMS": (CACurrentMediaTime()-start)*1000])
            try json(timings, "raw-timings.json")
            print("\(phase) frame=\(frame) gpuMS=\(span)"); fflush(stdout)
        }
    }
}
func readback(_ name: String) throws -> [UInt8] {
    let command = try unwrap(queue.makeCommandBuffer(), "No readback command")
    let blit = try unwrap(command.makeBlitCommandEncoder(), "No readback encoder")
    blit.copy(from: color, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
              sourceSize: MTLSize(width: width, height: height, depth: 1), to: staging, destinationOffset: 0,
              destinationBytesPerRow: rowBytes, destinationBytesPerImage: rowBytes*height)
    blit.endEncoding(); command.commit(); command.waitUntilCompleted(); try completed(command)
    let padded = Data(bytes: staging.contents(), count: rowBytes*height)
    var tight = [UInt8](); tight.reserveCapacity(width*height*4)
    for row in 0..<height { tight.append(contentsOf: padded[(row*rowBytes)..<(row*rowBytes+width*4)]) }
    try Data(tight).write(to: output.appendingPathComponent(name + ".bgra8"))
    let provider = try unwrap(CGDataProvider(data: padded as CFData), "No image provider")
    let cg = try unwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: rowBytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent), "No image")
    try unwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]), "No PNG").write(to: output.appendingPathComponent(name + ".png"))
    return tight
}
func counts(_ pixels: [UInt8]) -> [String: Int] {
    var green = 0, red = 0, magenta = 0, nonblack = 0
    var colors = Set<UInt32>()
    for i in stride(from: 0, to: pixels.count, by: 4) {
        let b = Int(pixels[i]), g = Int(pixels[i+1]), r = Int(pixels[i+2])
        if g > 35 && g*10 > r*11 && g*10 > b*11 { green += 1 }
        if r > 100 && r > g*2 && r > b*2 { red += 1 }
        if r > 230 && g < 30 && b > 230 { magenta += 1 }
        if max(r,g,b) > 30 { nonblack += 1 }
        colors.insert(UInt32(r << 16 | g << 8 | b))
    }
    return ["green": green, "red": red, "magenta": magenta, "nonblack": nonblack, "uniqueColors": colors.count]
}
do {
    try render(32, "reference")
    let baseline = try readback("reference"), before = counts(baseline)
    try require(before["green"]! > width*height/100 && before["uniqueColors"]! > 100 && before["magenta"]! == 0, "Reference target is blank, sentinel, or missing visible green geometry")
    cloth.shaderModifiers = [.fragment: "#pragma body\n_output.color = float4(1.0, 0.0, 0.0, 1.0);"]
    try render(4, "red-control")
    let red = try readback("red-control"), controlled = counts(red)
    try require(red != baseline && controlled["red"]! > before["red"]! + width*height/100, "Red control not applied")
    cloth.shaderModifiers = nil
    try render(4, "restored")
    let restored = try readback("restored")
    try require(restored == baseline, "Restore differs from baseline")
    try json(["passed": true, "device": device.name, "platform": ProcessInfo.processInfo.operatingSystemVersionString,
              "purpose": "Independent SceneKit host submission smoke, not candidate performance or App FPS",
              "submission": "One render per independent command buffer, immediately commit/wait before next render",
              "continuousReferenceFrames": 32, "allPositiveGPUFrames": timings.count, "width": width, "height": height,
              "sampleCount": 4, "wantsHDR": camera.wantsHDR, "wantsExposureAdaptation": camera.wantsExposureAdaptation,
              "reference": before, "redControl": controlled, "restoredBitwiseExact": true,
              "wallSeconds": CACurrentMediaTime()-began], "result.json")
} catch {
    try? json(["passed": false, "error": String(describing: error), "completedRenderFrames": timings.count,
               "wallSeconds": CACurrentMediaTime()-began], "result.json")
    throw error
}
