import Foundation
import CryptoKit
import Metal
func require(_ value: Bool,_ message: String) throws {if !value {throw NSError(domain:message,code:1)}}
func unwrap<T>(_ value:T?) throws -> T {guard let value else {throw NSError(domain:"nil",code:1)};return value}
enum ClothResearchShaders {static func sha256(_ s:String)->String {SHA256.hash(data:Data(s.utf8)).map {String(format:"%02x",$0)}.joined()}}
    func groupedClothSamples(_ source: String, width: Int) throws -> String {
        try require([2, 4].contains(width) &&
            ClothResearchShaders.sha256(source) == ClothShadowProgram.outputSHA256,
            "H16 requires current production C1/H9 source")
        let begin = try unwrap(source.range(of: "for(int ix=0;ix<samplesX;++ix) {"))
        let end = try unwrap(source.range(of: "E=temporalFieldDiffuse", range: begin.upperBound..<source.endIndex))
        let old = String(source[begin.lowerBound..<end.lowerBound])
        try require(old.contains("uint remainingShadowBalls=nearLampMasks[panel];") &&
                    old.contains("float4 shadowBall=contactUniforms.contactBalls[shadowIndex];"),
                    "H16 requires original ascending per-lamp blocker mask")
        let weightedStart = try unwrap(old.range(of: "float3 weighted="))
        let weightedEnd = try unwrap(old.range(of: ";\n", range: weightedStart.upperBound..<old.endIndex))
        let originalWeighted = String(old[weightedStart.lowerBound...weightedEnd.lowerBound])
        let vector = "float\(width)"
        let offsets = (0..<width).map { "\(Double($0) + 0.5)" }.joined(separator: ",")
        var body = """
        // H16: independent sample lanes; no cross-lane reduction.
        for(int ix=0;ix<samplesX;++ix) {
         for(int iz=0;iz<samplesZ;iz+=\(width)) {
          float h16U=2.0*(float(ix)+0.5)/float(samplesX)-1.0;
          \(vector) h16V=2.0*(float(iz)+\(vector)(\(offsets)))/float(samplesZ)-1.0;
          float3 h16C=v62EmitterCenter(panel),h16EU=v62EmitterU(panel),h16EV=v62EmitterV(panel);
          \(vector) dx=h16C.x+h16EU.x*h16U+h16EV.x*h16V-p.x;
          \(vector) dy=h16C.y+h16EU.y*h16U+h16EV.y*h16V-p.y;
          \(vector) dz=h16C.z+h16EU.z*h16U+h16EV.z*h16V-p.z;
          \(vector) h16R2=dx*dx+dy*dy+dz*dz;
          \(vector) h16R=sqrt(h16R2);
          \(vector) lx=dx/h16R,ly=dy/h16R,lz=dz/h16R;
          \(vector) h16Visibility=1.0;
          if(nearLampMasks[panel]!=0u) {
           uint remainingShadowBalls=nearLampMasks[panel];
           while(remainingShadowBalls!=0u) {
            uint shadowIndex=ctz(remainingShadowBalls);
            remainingShadowBalls &= remainingShadowBalls-1u;
            float4 shadowBall=contactUniforms.contactBalls[shadowIndex];
            if(shadowBall.w>0.0) {
             float3 toCenter=float3(shadowBall.x,0.8+shadowBall.z,shadowBall.y)-p;
             \(vector) t=toCenter.x*lx+toCenter.y*ly+toCenter.z*lz;
             \(vector) perpendicular2=dot(toCenter,toCenter)-t*t;
             \(vector) filterRadius=max(\(vector)(0.000001),lightCellRadius*t/h16R);
             \(vector) distanceToRay=sqrt(max(\(vector)(0.0),perpendicular2));
             \(vector) blocked=1.0-smoothstep(0.028575-filterRadius,0.028575+filterRadius,distanceToRay);
             \(vector) transmission=1.0-min(1.0,shadowBall.w/0.85)*blocked;
             h16Visibility *= select(\(vector)(1.0),transmission,(t>0.0) & (t*t<h16R2));
            }
           }
          }
          \(vector) h16NL=max(\(vector)(0.001),n.x*lx+n.y*ly+n.z*lz);
          \(vector) hx=lx+v.x,hy=ly+v.y,hz=lz+v.z;
          \(vector) h16InverseH=rsqrt(hx*hx+hy*hy+hz*hz);
          hx*=h16InverseH;hy*=h16InverseH;hz*=h16InverseH;
          \(vector) nh=max(\(vector)(0.0),n.x*hx+n.y*hy+n.z*hz);
          \(vector) vh=max(\(vector)(0.0),v.x*hx+v.y*hy+v.z*hz);
          \(vector) denom=nh*nh*(a2-1.0)+1.0;
          \(vector) h16D=a2/(3.14159265*denom*denom);
          \(vector) h16G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*h16NL/(h16NL+sqrt(a2+(1.0-a2)*h16NL*h16NL));
          \(vector) h16F=0.012+0.988*pow(1.0-vh,\(vector)(5.0));

        """
        for lane in 0..<width {
            body += """
              if(iz+\(lane)<samplesZ) {
               float3 l=float3(lx[\(lane)],ly[\(lane)],lz[\(lane)]);
               float r2=h16R2[\(lane)],visibility=h16Visibility[\(lane)],nl=h16NL[\(lane)];
               float D=h16D[\(lane)],G=h16G[\(lane)],F=h16F[\(lane)];
               \(originalWeighted)
               unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);
              }

            """
        }
        body += " }\n}\n}\n"
        var result = source
        result.replaceSubrange(begin.lowerBound..<end.lowerBound, with: body)
        return result
    }

let root=URL(fileURLWithPath:CommandLine.arguments[1]),out=URL(fileURLWithPath:CommandLine.arguments[2])
let guarded=try String(contentsOf:root.appendingPathComponent("output/render-lowdim-20261113/native-scene-guardcombo-package-r2/candidate.surface"),encoding:.utf8)
let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:guarded))
let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1))
let device=try unwrap(MTLCreateSystemDefaultDevice())
let emitterStart=try unwrap(baseline.range(of:"float3 v62EmitterCenter("))
let emitterEnd=try unwrap(baseline.range(of:"float v62RectIrradiance("))
let emitter=String(baseline[emitterStart.lowerBound..<emitterEnd.lowerBound])
for width in [0,2,4] {
 let source=try width==0 ? baseline : groupedClothSamples(baseline,width:width)
 try source.write(to:out.appendingPathComponent("width-\(width).surface"),atomically:true,encoding:.utf8)
 let start=try unwrap(source.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards))
 let end=try unwrap(source.range(of:"E=temporalFieldDiffuse",range:start.upperBound..<source.endIndex))
 let loop=String(source[start.lowerBound..<end.lowerBound])
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
  uint2 nearLampMasks=uint2(shadowPossible ? 65535u:0u);
  float3 E=0,unoccludedE=0,S=0;
  \(loop)
  output[gid*3]=float4(E,1);output[gid*3+1]=float4(unoccludedE,1);output[gid*3+2]=float4(S,1);
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
