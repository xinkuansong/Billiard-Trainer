import Foundation
import SceneKit
import AppKit
import Metal
import QuartzCore
import simd
import Darwin

let package = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let maxWidth = Int(CommandLine.arguments[3])!
let timeout = Double(CommandLine.arguments[4])!
let packageManifest = try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("manifest.json"))) as! [String:Any]
let candidateIdentity = packageManifest["candidate"] as! String
let processStart = CACurrentMediaTime()
DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
    fputs("Native scene benchmark watchdog expired\n", stderr); _exit(124)
}
func fail(_ s: String) throws -> Never { throw NSError(domain: "NativeSceneBenchmark", code: 1, userInfo: [NSLocalizedDescriptionKey:s]) }
func need(_ value: Bool, _ message: String) throws { if !value { try fail(message) } }
func unwrap<T>(_ value: T?, _ message: String) throws -> T { guard let value else { try fail(message) }; return value }
func write(_ value: Any, _ name: String) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted,.sortedKeys]).write(to: output.appendingPathComponent(name), options: .atomic)
}
func median(_ values: [Double]) -> Double {
    let v=values.sorted(), n=values.count; return n % 2 == 0 ? (v[n/2-1]+v[n/2])/2 : v[n/2]
}
func percentile(_ values: [Double], _ q: Double) -> Double { let v=values.sorted(); return v[min(v.count-1,Int(ceil(Double(v.count)*q))-1)] }
func distribution(_ values: [Double]) -> [String:Any] {
    ["n":values.count,"p50":median(values),"p95":percentile(values,0.95),"p99":percentile(values,0.99),"min":values.min()!,"max":values.max()!]
}
func done(_ command: MTLCommandBuffer) throws {
    try need(command.status == .completed, "Metal command failed: \(String(describing: command.error))")
    try need(command.gpuStartTime > 0 && command.gpuEndTime > command.gpuStartTime, "Missing/nonpositive real GPU timestamps")
}
func thermalOK() throws {
    let state=ProcessInfo.processInfo.thermalState
    try need(state != .serious && state != .critical, "Thermal state serious/critical: stop ranking")
}
let device = try unwrap(MTLCreateSystemDefaultDevice(), "No Metal device")
struct SceneFixture {
    let scene: SCNScene, table: SCNNode, mats: [SCNMaterial], eye: SCNNode, camera: SCNCamera, renderer: SCNRenderer
    let alignment: [String:Any]
}
// __SCENE_SETUP__

struct FrameTime {
    let gpuStart: Double, gpuEnd: Double, encode: Double, syncWall: Double, fullWall: Double, clearGPU: Double
    var gpu: Double { (gpuEnd-gpuStart)*1000 }
    var json: [String:Any] { ["gpuStartTime":gpuStart,"gpuEndTime":gpuEnd,"gpuMS":gpu,"cpuEncodeMS":encode,"renderSyncWallMS":syncWall,"fullSyncWallIncludingSentinelMS":fullWall,"sentinelGPU_MS":clearGPU] }
}
final class Target {
    let renderer: SCNRenderer, queue: MTLCommandQueue, color: MTLTexture, msaa: MTLTexture, depth: MTLTexture, staging: MTLBuffer
    let w: Int, h: Int, strideBytes: Int
    init(_ renderer: SCNRenderer, _ width: Int, _ height: Int) throws {
        self.renderer=renderer; w=width; h=height; strideBytes=((width*4+255)/256)*256
        queue=try unwrap(device.makeCommandQueue(), "No scene queue")
        let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:w,height:h,mipmapped:false)
        d.usage=[.renderTarget,.shaderRead]; d.storageMode = .private
        color=try unwrap(device.makeTexture(descriptor:d),"No resolved color")
        d.textureType = .type2DMultisample; d.sampleCount=4
        msaa=try unwrap(device.makeTexture(descriptor:d),"No MSAA color")
        d.pixelFormat = .depth32Float_stencil8; d.usage = .renderTarget
        depth=try unwrap(device.makeTexture(descriptor:d),"No depth/stencil")
        staging=try unwrap(device.makeBuffer(length:strideBytes*h,options:.storageModeShared),"No readback staging")
        try need(color.allocatedSize > 0 && msaa.allocatedSize > 0 && depth.allocatedSize > 0 && staging.allocatedSize > 0,"Native resource accounting unavailable")
    }
    var bytes: [String:Int] { ["resolve":color.allocatedSize,"MSAA4":msaa.allocatedSize,"depthStencil4":depth.allocatedSize,"staging":staging.allocatedSize,"totalExplicitTarget":color.allocatedSize+msaa.allocatedSize+depth.allocatedSize+staging.allocatedSize] }
    func frame() throws -> FrameTime {
        try thermalOK()
        let fullStart=CACurrentMediaTime()
        let clear=try unwrap(queue.makeCommandBuffer(),"No sentinel command")
        let cp=MTLRenderPassDescriptor(); cp.colorAttachments[0].texture=color
        cp.colorAttachments[0].loadAction = .clear; cp.colorAttachments[0].storeAction = .store
        cp.colorAttachments[0].clearColor=MTLClearColorMake(1,0,1,1)
        let ce=try unwrap(clear.makeRenderCommandEncoder(descriptor:cp),"No sentinel encoder")
        ce.endEncoding(); clear.commit(); clear.waitUntilCompleted(); try done(clear)
        let start=CACurrentMediaTime(), command=try unwrap(queue.makeCommandBuffer(),"No scene command")
        let p=MTLRenderPassDescriptor()
        p.colorAttachments[0].texture=msaa; p.colorAttachments[0].resolveTexture=color
        p.colorAttachments[0].loadAction = .clear; p.colorAttachments[0].storeAction = .multisampleResolve
        p.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,1)
        p.depthAttachment.texture=depth; p.depthAttachment.loadAction = .clear; p.depthAttachment.storeAction = .dontCare; p.depthAttachment.clearDepth=1
        p.stencilAttachment.texture=depth; p.stencilAttachment.loadAction = .clear; p.stencilAttachment.storeAction = .dontCare; p.stencilAttachment.clearStencil=0
        renderer.render(atTime:1,viewport:CGRect(x:0,y:0,width:w,height:h),commandBuffer:command,passDescriptor:p)
        let encoded=CACurrentMediaTime()
        command.commit(); command.waitUntilCompleted(); let end=CACurrentMediaTime(); try done(command)
        return FrameTime(gpuStart:command.gpuStartTime,gpuEnd:command.gpuEndTime,encode:(encoded-start)*1000,syncWall:(end-start)*1000,fullWall:(end-fullStart)*1000,clearGPU:(clear.gpuEndTime-clear.gpuStartTime)*1000)
    }
    func batch(_ n: Int) throws -> [FrameTime] {
        var result=[FrameTime](); for _ in 0..<n { result.append(try autoreleasepool { try frame() }) }; return result
    }
    func read() throws -> Data {
        let cb=try unwrap(queue.makeCommandBuffer(),"No readback command"), blit=try unwrap(cb.makeBlitCommandEncoder(),"No readback encoder")
        blit.copy(from:color,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:w,height:h,depth:1),to:staging,destinationOffset:0,destinationBytesPerRow:strideBytes,destinationBytesPerImage:strideBytes*h)
        blit.endEncoding();cb.commit();cb.waitUntilCompleted();try done(cb)
        var result=Data(capacity:w*h*4)
        for row in 0..<h { result.append(staging.contents().advanced(by:row*strideBytes).assumingMemoryBound(to:UInt8.self),count:w*4) }
        return result
    }
    func save(_ data: Data, _ name: String) throws {
        try data.write(to:output.appendingPathComponent(name+".bgra8"))
        let provider=try unwrap(CGDataProvider(data:data as CFData),"No PNG provider")
        let cg=try unwrap(CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),"No CG image")
        try unwrap(NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]),"No PNG").write(to:output.appendingPathComponent(name+".png"))
    }
}
func counts(_ data: Data) -> [String:Int] {
    let a=[UInt8](data);var red=0,green=0,magenta=0;var unique=Set<UInt32>()
    for i in stride(from:0,to:a.count,by:4) { let b=Int(a[i]),g=Int(a[i+1]),r=Int(a[i+2]);if r>100 && r>2*g && r>2*b{red+=1};if g>35 && g*10>r*11 && g*10>b*11{green+=1};if r>230 && g<30 && b>230{magenta+=1};unique.insert(UInt32(r<<16|g<<8|b)) }
    return ["red":red,"green":green,"magenta":magenta,"uniqueRGB":unique.count]
}

func calibrate() throws {
    let source="""
    #include <metal_stdlib>
    using namespace metal;
    vertex float4 vertex_main(uint i [[vertex_id]]) {
      float2 p[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};return float4(p[i],0,1);
    }
    fragment half4 fragment_main(float4 p [[position]],constant uint &iterations [[buffer(0)]]) {
      float x=0.01+p.x*0.00012+p.y*0.00017;
      for(uint i=0;i<iterations;i++){x=sin(x*1.0101+0.0001*float(i))*0.999+0.02;}
      return half4(half(x),half(x*0.7),half(x*0.3),1);
    }
    """
    let library=try device.makeLibrary(source:source,options:nil), p=MTLRenderPipelineDescriptor()
    p.vertexFunction=library.makeFunction(name:"vertex_main");p.fragmentFunction=library.makeFunction(name:"fragment_main");p.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline=try device.makeRenderPipelineState(descriptor:p), queue=try unwrap(device.makeCommandQueue(),"No calibration queue")
    let td=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:512,height:512,mipmapped:false);td.storageMode = .private;td.usage = .renderTarget
    let texture=try unwrap(device.makeTexture(descriptor:td),"No calibration target")
    try need(texture.allocatedSize>0,"Synthetic target allocation must be real")
    func sample(_ iterations: UInt32) throws -> [String:Any] {
        let command=try unwrap(queue.makeCommandBuffer(),"No fill command"), pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=texture;pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
        let start=CACurrentMediaTime(), encoder=try unwrap(command.makeRenderCommandEncoder(descriptor:pass),"No fill encoder")
        var n=iterations;encoder.setRenderPipelineState(pipeline);encoder.setFragmentBytes(&n,length:4,index:0);encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding()
        let encoded=CACurrentMediaTime();command.commit();command.waitUntilCompleted();try done(command)
        return ["iterations":iterations,"gpuMS":(command.gpuEndTime-command.gpuStartTime)*1000,"gpuStartTime":command.gpuStartTime,"gpuEndTime":command.gpuEndTime,"cpuEncodeMS":(encoded-start)*1000,"syncWallMS":(CACurrentMediaTime()-start)*1000]
    }
    for _ in 0..<4 { _=try sample(32);_=try sample(1024) }
    var samples=[[String:Any]](),ratios=[Double]()
    for cycle in 0..<9 {
        var low=[Double](),high=[Double]()
        for n:UInt32 in cycle%2==0 ? [32,1024,1024,32] : [1024,32,32,1024] {
            var row=try sample(n);row["cycle"]=cycle;samples.append(row)
            if n==32 {low.append(row["gpuMS"] as! Double)} else {high.append(row["gpuMS"] as! Double)}
        }
        ratios.append(median(high)/median(low))
    }
    let buffer=try unwrap(device.makeBuffer(length:256,options:.storageModeShared),"No fill readback"), cb=try unwrap(queue.makeCommandBuffer(),"No fill readback command"), blit=try unwrap(cb.makeBlitCommandEncoder(),"No fill readback encoder")
    blit.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:256,y:256,z:0),sourceSize:MTLSize(width:1,height:1,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:256,destinationBytesPerImage:256)
    blit.endEncoding();cb.commit();cb.waitUntilCompleted();try done(cb)
    let bits=Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:UInt16.self),count:4))
    let passed=median(ratios)>1.5 && ratios.allSatisfy{$0>1.2} && bits[0] != 0 && bits[3]==0x3c00
    try write(["passed":passed,"scope":"Fullscreen native Metal fragment recurrence; iterations32 versus1024, same512x512 RGBA16F target; diagnostic proves timestamps respond to work, not an App workload", "targetAllocatedBytes":texture.allocatedSize,"pairedRatios":ratios,"medianHeavyLightRatio":median(ratios),"lastPixelHalfBits":bits,"raw":samples],"fill-calibration.json")
    try need(passed,"Native GPU timestamp workload calibration failed; no scene ranking")
}

let reference=try String(contentsOf:package.appendingPathComponent("reference.surface"),encoding:.utf8)
let candidate=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
let plainURL=package.appendingPathComponent("plain-safe.surface")
let plainSafe=FileManager.default.fileExists(atPath:plainURL.path) ? try String(contentsOf:plainURL,encoding:.utf8) : nil
let headroom=pow(2.0,0.1)-1
let fragment="""
#pragma body
float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
"""
func configure(_ fixture: SceneFixture, _ kind: String) -> [SIMD4<Float>] {
    let R:Float=0.028575
    let points:[SIMD2<Float>]=kind=="single-near" ? [SIMD2(0,0),SIMD2(0.05715,0)] : [-0.9,-0.3,0.3,0.9].flatMap{x in [-0.45,-0.15,0.15,0.45].map{z in SIMD2<Float>(Float(x),Float(z))}}
    var balls=Array(repeating:SIMD4<Float>(0,0,0,0),count:16)
    for (i,p) in points.enumerated() {
        balls[i]=SIMD4(p.x,p.y,R,0.85)
        let sphere=SCNSphere(radius:CGFloat(R));sphere.segmentCount=48
        let m=SCNMaterial();m.diffuse.contents=NSColor(srgbRed:0.8,green:0.8,blue:0.8,alpha:1);m.roughness.contents=Float(0.34);m.lightingModel = .physicallyBased;sphere.materials=[m]
        let node=SCNNode(geometry:sphere);node.simdPosition=SIMD3(p.x,0.8+R,p.y);fixture.scene.rootNode.addChildNode(node)
    }
    let blob=balls.withUnsafeBytes{Data($0)}
    for m in fixture.mats {m.setValue(blob as NSData,forKey:"contactUniforms")}
    fixture.eye.simdPosition=kind=="single-near" ? SIMD3(0.16,1.15,0.3) : SIMD3(1.8,2.7,2.1)
    fixture.eye.simdLook(at:SIMD3(0,0.8,0));return balls
}
func install(_ scene: SceneFixture, _ mode: String) {
    for m in scene.mats {
        var mods=m.shaderModifiers ?? [:]
        mods[.surface]=mode=="candidate" ? candidate : (mode=="plain-safe" ? plainSafe! : reference+(mode=="red-control" ? "\n_surface.emission.rgb=float3(1,0,0);" : ""))
        mods[.fragment]=fragment;m.shaderModifiers=mods
    }
    SCNTransaction.flush()
}

var rows=[[String:Any]]()
do {
    try thermalOK(); try need(device.supportsTextureSampleCount(4),"MSAA4 unsupported")
    try calibrate()
    print("native GPU fill calibration passed");fflush(stdout)
    for width in [700,1400,2800] where width<=maxWidth {
        for kind in ["single-near","scatter-overview"] {
            try autoreleasepool {
                let id="\(kind)-\(width)x\(width*4/7)"
                print("setup \(id)");fflush(stdout)
                let s=try makeScene(package), balls=configure(s,kind), target=try Target(s.renderer,width,width*4/7)
                try need(s.mats.allSatisfy{$0.shaderModifiers?[.geometry] != nil},"Lost production geometry lift")
                let frozenEye=s.eye.simdTransform
                var validation=[[String:Any]]()
                func capture(_ mode:String,_ frames:Int,_ suffix:String) throws -> Data {
                    install(s,mode);let ts=try target.batch(frames),data=try target.read();try target.save(data,id+"-"+suffix)
                    validation.append(["mode":mode,"label":suffix,"frames":ts.map{$0.json},"pixels":counts(data)])
                    try write(validation,id+"-validation.json");return data
                }
                let baseline=try capture("reference",8,"reference"), before=counts(baseline)
                try need(before["green"]!>width*(width*4/7)/100 && before["uniqueRGB"]!>100 && before["magenta"]!<10,"Empty/invalid target \(id)")
                let repeatR=try capture("reference",1,"repeat-reference");try need(repeatR==baseline,"Reference nondeterministic \(id)")
                let control=try capture("red-control",4,"red-control")
                try need(control != baseline && counts(control)["red"]!>before["red"]!+width*(width*4/7)/100,"Red control inactive \(id)")
                if plainSafe != nil {
                    let plain=try capture("plain-safe",8,"plain-safe");try need(plain==baseline,"Plain safe differs from original BGRA \(id)")
                    let repeatPlain=try capture("plain-safe",1,"repeat-plain-safe");try need(repeatPlain==plain,"Plain safe nondeterministic \(id)")
                }
                let cand=try capture("candidate",8,"candidate");try need(cand==baseline,"Candidate differs from original BGRA \(id)")
                let repeatC=try capture("candidate",1,"repeat-candidate");try need(repeatC==cand,"Candidate nondeterministic \(id)")
                let restored=try capture("reference",4,"restored");try need(restored==baseline,"Restore mismatch \(id)")
                var raw=[[String:Any]](),pairs=[[String:Any]]()
                let pairDefs:[[String]]=plainSafe == nil ? [["reference","candidate"]] : [["reference","plain-safe"],["reference","candidate"],["plain-safe","candidate"]]
                for cycle in 0..<9 {
                    // Rotate pair order to avoid always running one comparison later.
                    for pairSlot in 0..<pairDefs.count {
                        let pairIndex=(cycle+pairSlot)%pairDefs.count, definition=pairDefs[pairIndex]
                        let first=definition[0],second=definition[1],pairID=first+"_vs_"+second
                        let order=(cycle+pairIndex)%2==0 ? [first,second,second,first] : [second,first,first,second]
                        var a=[Double](),b=[Double]()
                        for (slot,mode) in order.enumerated() {
                            install(s,mode);_=try target.batch(2)
                            let batchStart=CACurrentMediaTime(),times=try target.batch(6),batchEnd=CACurrentMediaTime()
                            let proof=try target.read()
                            if proof != baseline {try target.save(proof,id+"-failure-\(cycle)-\(pairID)-\(slot)");try fail("Measured target changed \(id) cycle\(cycle) pair\(pairID) slot\(slot)")}
                            try need(s.eye.simdTransform==frozenEye,"Camera moved")
                            let mean=times.map{$0.gpu}.reduce(0,+)/6
                            if mode==first {a.append(mean)} else {b.append(mean)}
                            raw.append(["cycle":cycle,"pair":pairID,"pairSlot":pairSlot,"slot":slot,"mode":mode,"gpuMeanMS":mean,"cpuEncodeMeanMS":times.map{$0.encode}.reduce(0,+)/6,"renderSyncWallMeanMS":times.map{$0.syncWall}.reduce(0,+)/6,"fullSyncWallMeanMS":times.map{$0.fullWall}.reduce(0,+)/6,"batchWallMSIncludingHarness":(batchEnd-batchStart)*1000,"sameTargetBitwiseExact":true,"frames":times.map{$0.json}])
                            try write(raw,id+"-raw-timings.json")
                        }
                        let change=(median(b)/median(a)-1)*100,drift=abs(a[1]-a[0])/median(a)*100,secondDrift=abs(b[1]-b[0])/median(b)*100
                        pairs.append(["cycle":cycle,"pair":pairID,"pairSlot":pairSlot,"firstArm":first,"secondArm":second,"order":order,"firstArmMeanMS":a,"secondArmMeanMS":b,"pairedChangePercent":change,"firstArmEndpointDriftPercent":drift,"secondArmEndpointDriftPercent":secondDrift])
                        print("\(id) cycle=\(cycle) pair=\(pairID) change=\(change)% drift=\(drift)%");fflush(stdout)
                    }
                }
                var comparisons=[String:Any]()
                for definition in pairDefs {
                    let pairID=definition[0]+"_vs_"+definition[1], ps=pairs.filter{$0["pair"] as! String==pairID}
                    let changes=ps.map{$0["pairedChangePercent"] as! Double},drifts=ps.map{$0["firstArmEndpointDriftPercent"] as! Double},secondDrifts=ps.map{$0["secondArmEndpointDriftPercent"] as! Double}
                    var comparison:[String:Any]=["pairedChangeMedianPercent":median(changes),"pairedChangeRangePercent":[changes.min()!,changes.max()!],"firstArmEndpointDriftMedianPercent":median(drifts),"firstArmEndpointDriftMaxPercent":drifts.max()!,"secondArmEndpointDriftMedianPercent":median(secondDrifts),"secondArmEndpointDriftMaxPercent":secondDrifts.max()!,"pairs":ps]
                    for mode in definition {
                        let rs=raw.filter{$0["pair"] as! String==pairID && $0["mode"] as! String==mode}
                        let frames=rs.flatMap{$0["frames"] as! [[String:Any]]}
                        comparison[mode]=["gpuBatchMeanMedianMS":median(rs.map{$0["gpuMeanMS"] as! Double}),"cpuEncodeBatchMeanMedianMS":median(rs.map{$0["cpuEncodeMeanMS"] as! Double}),"renderSyncWallBatchMeanMedianMS":median(rs.map{$0["renderSyncWallMeanMS"] as! Double}),"fullSyncWallBatchMeanMedianMS":median(rs.map{$0["fullSyncWallMeanMS"] as! Double}),"perFrameGPU_MS":distribution(frames.map{$0["gpuMS"] as! Double}),"perFrameCPUEncodeMS":distribution(frames.map{$0["cpuEncodeMS"] as! Double}),"perFrameRenderSyncWallMS":distribution(frames.map{$0["renderSyncWallMS"] as! Double}),"perFrameFullSyncWallMS":distribution(frames.map{$0["fullSyncWallIncludingSentinelMS"] as! Double})]
                    }
                    comparisons[pairID]=comparison
                }
                let row:[String:Any]=["id":id,"width":width,"height":width*4/7,"pixels":width*width*4/7,"balls":balls.map{[$0.x,$0.y,$0.z,$0.w]},"bytes":target.bytes,"validationPassed":true,"measuredTargetChecks":raw.count,"comparisons":comparisons,"alignment":s.alignment,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue]
                rows.append(row);try write(rows,"scene-results.json")
            }
        }
    }
    try write(["passed":true,"device":device.name,"registryID":String(device.registryID),"os":ProcessInfo.processInfo.operatingSystemVersionString,"scope":"Native macOS isolated actual USDZ/TaiNi production cloth shader/material/geometry lift; imported other table materials, diagnostic white spheres, environment intensity1; no production room/R sphere reflection/UI/lifecycle. Not full App or iPhone performance.","candidate":candidateIdentity,"configurations":rows.count,"timing":"9 alternating ABBA/BAAB; each switch2 warmup frames then6 independently committed/waited SCNRenderer render(atTime:1) frames; GPU render-only span, CPU encode, render sync wall, full sync wall including sentinel are separate. Same last target readback outside timing. No FPS conversion.","resourceScope":"Explicit target allocations only; SceneKit internal HDR textures, USDZ textures and driver caches not enumerable here; candidate adds no texture/buffer.","sceneSettings":["HDR":true,"exposureAdaptation":false,"exposureOffset":-0.1,"SSAO":0,"MSAA":4,"normalIntensity":0.65,"environmentIntensity":1.0],"wallSeconds":CACurrentMediaTime()-processStart],"result.json")
} catch {
    try? write(["passed":false,"error":String(describing:error),"completedConfigurations":rows.count,"wallSeconds":CACurrentMediaTime()-processStart],"result.json")
    fputs("FAILED: \(error)\n",stderr);exit(1)
}
