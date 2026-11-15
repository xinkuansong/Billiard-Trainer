import Foundation
import CryptoKit
import Metal
func require(_ value: Bool,_ message: String) throws {if !value {throw NSError(domain:message,code:1)}}
func unwrap<T>(_ value:T?) throws -> T {guard let value else {throw NSError(domain:"nil",code:1)};return value}
enum ClothResearchShaders {static func sha256(_ s:String)->String {SHA256.hash(data:Data(s.utf8)).map {String(format:"%02x",$0)}.joined()}}
    func stripClothSamples(_ source: String, width: Int) throws -> String {
        try require([1, 2].contains(width) &&
                    ClothResearchShaders.sha256(source) == ClothShadowProgram.outputSHA256,
                    "H16 strip requires the frozen production rig and source")
        let anchor = "for(int ix=0;ix<samplesX;++ix) {"
        try require(source.components(separatedBy: anchor).count == 2 &&
                    source.components(separatedBy: "uint remainingShadowBalls=nearLampMasks[panel];").count == 2,
                    "H16 strip source anchors")
        let predicate = width == 1
            ? "abs(dot(h16Plane0,h16Delta))<=h16Radius"
            : "dot(h16Plane0,h16Delta)<=h16Radius && dot(h16Plane1,h16Delta)<=h16Radius"
        let planes = width == 1
            ? "float3 h16Plane0=normalize(float3(h16H,-h16X0,0.0));"
            : """
              float h16X1=h16Light.x+v62EmitterU(panel).x*(2.0*(float(ix+1)+0.5)/float(samplesX)-1.0)-p.x;
              float3 h16Plane0=normalize(float3(-h16H,h16X0,0.0));
              float3 h16Plane1=normalize(float3(h16H,-h16X1,0.0));
              """
        let replacement = """
        uint h16StripMask=nearLampMasks[panel];
        for(int ix=0;ix<samplesX;++ix) {
         if(ix%\(width)==0) {
          h16StripMask=nearLampMasks[panel];
          if(diagnosticConeEligible && h16StripMask!=0u) {
           float3 h16Light=v62EmitterCenter(panel);
           float h16H=h16Light.y-p.y;
           if(h16H>lightCellRadius) {
            float h16X0=h16Light.x+v62EmitterU(panel).x*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)-p.x;
            \(planes)
            uint h16Remaining=h16StripMask;h16StripMask=0u;
            while(h16Remaining!=0u) {
             uint h16Index=ctz(h16Remaining);h16Remaining &= h16Remaining-1u;
             float4 h16Ball=contactUniforms.contactBalls[h16Index];
             float3 h16Center=float3(h16Ball.x,0.8+h16Ball.z,h16Ball.y);
             float3 h16Delta=h16Center-p;
             float h16U=clamp((h16Delta.y+0.028575+0.000001)/(h16H-lightCellRadius),0.0,1.0);
             float h16Scale=max(1.0,max(length(p),max(length(h16Center),length(h16Light))));
             float h16Radius=0.028575+0.000001+lightCellRadius*h16U+64.0*1.1920928955078125e-7*h16Scale;
             if(\(predicate)) h16StripMask |= 1u<<h16Index;
            }
           }
          }
         }
        """
        return source.replacingOccurrences(of: anchor, with: replacement)
            .replacingOccurrences(of: "uint remainingShadowBalls=nearLampMasks[panel];",
                                  with: "uint remainingShadowBalls=h16StripMask;")
    }

let root=URL(fileURLWithPath:CommandLine.arguments[1]),out=URL(fileURLWithPath:CommandLine.arguments[2])
let guarded=try String(contentsOf:root.appendingPathComponent("output/render-lowdim-20261113/native-scene-guardcombo-package-r2/candidate.surface"),encoding:.utf8)
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guarded))
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1))
let device=try unwrap(MTLCreateSystemDefaultDevice())
let emitterStart=try unwrap(baseline.range(of:"float3 v62EmitterCenter("))
let emitterEnd=try unwrap(baseline.range(of:"float v62RectIrradiance("))
let emitter=String(baseline[emitterStart.lowerBound..<emitterEnd.lowerBound])
for width in [0,1,2] {
 let source=try width==0 ? baseline : stripClothSamples(baseline,width:width)
 try source.write(to:out.appendingPathComponent("width-\(width).surface"),atomically:true,encoding:.utf8)
 let start=try unwrap(source.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards))
 let end=try unwrap(source.range(of:"E=temporalFieldDiffuse",range:start.upperBound..<source.endIndex))
 var loop=String(source[start.lowerBound..<end.lowerBound])
 if width != 0 {
  let oracle="""
  float visibility=1.0;
  uint rejected=nearLampMasks[panel] & ~h16StripMask;
  while(rejected!=0u) {
   uint index=ctz(rejected);rejected &= rejected-1u;probePruned+=1;
   float4 ball=contactUniforms.contactBalls[index];
   float3 center=float3(ball.x,0.8+ball.z,ball.y),toCenter=center-p;
   float t=dot(toCenter,l),perpendicular2=dot(toCenter,toCenter)-t*t;
   if(ball.w>0.0 && t>0.0 && t*t<r2) {
    float filterRadius=max(0.000001,lightCellRadius*t/sqrt(r2));
    float distanceToRay=sqrt(max(0.0,perpendicular2));
    float blocked=1.0-smoothstep(0.028575-filterRadius,0.028575+filterRadius,distanceToRay);
    if(blocked>0.0) probeMissed+=1;
   }
  }
  """
  loop=loop.replacingOccurrences(of:"float visibility=1.0;",with:oracle)
 }
 let metal="""
 #include <metal_stdlib>
 using namespace metal;
 struct Contact {float4 contactBalls[16];};
 \(emitter)
 kernel void probe(constant Contact &contactUniforms [[buffer(0)]],device float4 *output [[buffer(1)]],uint gid [[thread_position_in_grid]]) {
  float3 p=float3(0.01*float(gid%256)-1.27,0.65+float((gid/256)%16)*0.015,0.005*float((gid*7)%256)-0.635);
  float3 n=normalize(float3(0.1*sin(float(gid)),1,0.1*cos(float(gid))));
  float3 v=normalize(float3(0.2,0.3+float(gid%32)*0.04,0.7));
  float nv=max(0.001,dot(n,v)),alpha=0.15+float(gid%64)*0.012,a2=alpha*alpha;
  bool shadowPossible=(gid%3)!=0;
  bool diagnosticConeEligible=(gid%11)!=0;
  uint probePruned=0,probeMissed=0;
  uint2 nearLampMasks=uint2(shadowPossible ? 65535u:0u);
  float3 E=0,unoccludedE=0,S=0;
  \(loop)
  output[gid*3]=float4(E,float(probePruned));output[gid*3+1]=float4(unoccludedE,float(probeMissed));output[gid*3+2]=float4(S,1);
 }
 """
 try metal.write(to:out.appendingPathComponent("width-\(width).metal"),atomically:true,encoding:.utf8)
 let options=MTLCompileOptions();options.fastMathEnabled=true
 let library=try device.makeLibrary(source:metal,options:options)
 let pipeline=try device.makeComputePipelineState(function:try unwrap(library.makeFunction(name:"probe")))
 let count=8192
 var balls=[SIMD4<Float>]()
 for i in 0..<16 {balls.append(SIMD4(Float(i/4)*0.6-0.9,Float(i%4)*0.3-0.45,0.028575+Float(i%3)*0.1,0.85))}
 let ballBuffer=try unwrap(device.makeBuffer(bytes:&balls,length:256))
 let result=try unwrap(device.makeBuffer(length:count*3*16))
 let queue=try unwrap(device.makeCommandQueue()),command=try unwrap(queue.makeCommandBuffer()),encoder=try unwrap(command.makeComputeCommandEncoder())
 encoder.setComputePipelineState(pipeline);encoder.setBuffer(ballBuffer,offset:0,index:0);encoder.setBuffer(result,offset:0,index:1)
 encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1));encoder.endEncoding();command.commit();command.waitUntilCompleted()
 try require(command.status == .completed,"preflight GPU command")
 let data=Data(bytes:result.contents(),count:count*3*16)
 try data.write(to:out.appendingPathComponent("width-\(width).bin"))
 print("H16 preflight width=\(width) compiled and executed \(count) points")
}
