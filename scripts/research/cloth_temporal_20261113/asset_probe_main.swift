import Foundation
import Metal
import CryptoKit
func need(_ ok:Bool,_ message:String)throws{if !ok{throw NSError(domain:"FieldAssetProbe",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
let root=URL(fileURLWithPath:CommandLine.arguments[1]),mode=CommandLine.arguments[2],out=URL(fileURLWithPath:CommandLine.arguments[3])
try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
let base=try String(contentsOf:root.appendingPathComponent("output/render-lowdim-20261113/native-scene-guardcombo-package-r2/candidate.surface"),encoding:.utf8)
let emitter=String(base[base.range(of:"float3 v62EmitterCenter(")!.lowerBound..<base.range(of:"float v62RectIrradiance(")!.lowerBound])
let asset=root.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin")
let device=MTLCreateSystemDefaultDevice()!
var path:URL?=asset
if mode=="missing"{path=nil}
if mode=="corrupt" || mode=="truncated" {
 var bytes=try Data(contentsOf:asset)
 if mode=="corrupt"{bytes[128] ^= 1}else{bytes.removeLast()}
 path=out.appendingPathComponent("broken.bin");try bytes.write(to:path!)
}
var report:[String:Any]=["mode":mode,"supports32BitFloatFiltering":device.supports32BitFloatFiltering]
if mode != "valid" {
 var rejected=false
 do {_=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:path)} catch{rejected=true;report["error"]=String(describing:error)}
 try need(rejected,"Invalid asset accepted");report["rejected"]=rejected
} else {
 weak var released:StaticClothIrradiance?
 try autoreleasepool {
  let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:path)
  released=field
  let second=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:path)
  try need(field === second,"Resource not shared")
  var data=Data()
  for texture in field.fields {
   var bytes=Data(count:64*32*16*16)
   bytes.withUnsafeMutableBytes{texture.getBytes($0.baseAddress!,bytesPerRow:64*16,bytesPerImage:64*32*16,from:MTLRegionMake3D(0,0,0,64,32,16),mipmapLevel:0,slice:0)}
   data.append(bytes)
  }
  let source=try Data(contentsOf:asset)
  try need(data==source,"Texture readback differs from validated field")
  let shader=StaticClothIrradiance.replacingDiffuse(in:base)!
  let measured=try String(contentsOf:root.appendingPathComponent("output/render-activity-20261113/c1-app-integration/native-700/actual-candidate.surface"),encoding:.utf8)
  try need(shader==measured,"Measured shader drift")
  report["textureBytesExact"]=true;report["shaderExact"]=true;report["shared"]=true
  report["prepareMS"]=field.preparationMilliseconds;report["runtimeGenerationMS"]=field.generationMilliseconds;report["allocatedBytes"]=field.allocatedBytes
 }
 try need(released==nil,"Resource lifetime leak");report["lastOwnerReleased"]=true
}
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
print(report)
