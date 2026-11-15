try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
func imageFor(_ contents:Any?)throws->CGImage {
 var image: NSImage?
 if let value=contents as? NSImage {image=value}
 else if let value=contents as? URL {
  var components=try unwrap(URLComponents(url:value,resolvingAgainstBaseURL:false),"Texture URL")
  let items=components.queryItems ?? []
  if let offsetString=items.first(where:{$0.name=="offset"})?.value,
     let sizeString=items.first(where:{$0.name=="size"})?.value,
     let offset=Int(offsetString),let size=Int(sizeString) {
   components.query=nil
   let file=try Data(contentsOf:unwrap(components.url,"Texture archive URL"),options:.mappedIfSafe)
   try need(offset>=0 && size>0 && offset<=file.count-size,"Embedded image byte range")
   image=NSImage(data:file.subdata(in:offset..<(offset+size)))
  } else {image=NSImage(contentsOf:value)}
 }
 else if let value=contents as? String {image=NSImage(contentsOfFile:value)}
 else if let value=contents as? Data {image=NSImage(data:value)}
 else if let value=contents, CFGetTypeID(value as CFTypeRef)==CGImage.typeID{return (value as! CGImage)}
 return try unwrap(image?.cgImage(forProposedRect:nil,context:nil,hints:nil),"Decode actual material image: \(String(describing:contents.map{type(of:$0)}))")
}
let probeScene=try makeScene(package)
var resources=[[String:Any]]()
for (index,material) in probeScene.mats.enumerated() {
 for (name,property) in [("normal",material.normal),("roughness",material.roughness)] {
  print("Texture source \(name): \(String(describing:property.contents))");fflush(stdout)
  let image=try imageFor(property.contents)
  resources.append(["material":index,"name":name,"contentsType":String(describing:type(of:property.contents!)),"width":image.width,"height":image.height,"bitsPerPixel":image.bitsPerPixel,"bitsPerComponent":image.bitsPerComponent,"colorSpace":String(describing:image.colorSpace?.name),"bytesPerRow":image.bytesPerRow,"minification":property.minificationFilter.rawValue,"magnification":property.magnificationFilter.rawValue,"mip":property.mipFilter.rawValue,"anisotropy":property.maxAnisotropy,"normalIntensity":material.normal.intensity])
 }
}
try write(["device":device.name,"resources":resources,"scope":"Actual imported TaiNi material after frozen production appearance settings"],"resources.json")
print("Resource inspection: \(resources.count) active texture properties");fflush(stdout)
if experimentRound != "probe" {
 let original=try String(contentsOf:package.appendingPathComponent("candidate.surface"),encoding:.utf8)
 let emitter=String(original[original.range(of:"float3 v62EmitterCenter(")!.lowerBound..<original.range(of:"float v62RectIrradiance(")!.lowerBound])
 let c1=try unwrap(StaticClothIrradiance.replacingDiffuse(in:original),"C1 source")
 let baseline=try unwrap(ClothShadowProgram.replacingLocalBalls(in:c1),"H9 source")
 let field=try StaticClothIrradiance.acquire(emitter:emitter,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:repository.appendingPathComponent("QiuJi/Resources/StaticClothIrradiance-v1.bin"))
 let headroom=pow(2.0,0.1)-1
 let fragment="""
 #pragma body
 float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
 if(outputPeak>1.0){float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));_output.color.rgb*=mapped/outputPeak;}
 """
 try baseline.write(to:output.appendingPathComponent("baseline.surface"),atomically:true,encoding:.utf8)
 func reduce(_ source:CGImage,_ size:Int)throws->CGImage {
  if size==source.width{return source}
  try need(source.width==source.height && source.width%size==0 && source.bitsPerPixel==32 && source.bitsPerComponent==8,"RGBA8 integer reduction")
  let data=try unwrap(source.dataProvider?.data,"Image bytes"),bytes=CFDataGetBytePtr(data)!
  let scale=source.width/size,area=scale*scale
  var output=[UInt8](repeating:0,count:size*size*4)
  for y in 0..<size {for x in 0..<size {for c in 0..<4 {
   var sum=0
   for dy in 0..<scale {for dx in 0..<scale {sum += Int(bytes[(y*scale+dy)*source.bytesPerRow+(x*scale+dx)*4+c])}}
   output[(y*size+x)*4+c]=UInt8((sum+area/2)/area)
  }}}
  let provider=try unwrap(CGDataProvider(data:Data(output) as CFData),"Reduced provider")
  return try unwrap(CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,space:unwrap(source.colorSpace,"Source color space"),bitmapInfo:source.bitmapInfo,provider:provider,decode:source.decode,shouldInterpolate:source.shouldInterpolate,intent:source.renderingIntent),"Reduced image")
 }
 let prepareStart=CACurrentMediaTime()
 let originals=try [imageFor(probeScene.mats[0].normal.contents),imageFor(probeScene.mats[0].roughness.contents)]
 var images=[Int:[NSImage]]()
 for size in [2048,1024,512] {images[size]=try originals.map{NSImage(cgImage:try reduce($0,size),size:NSSize(width:size,height:size))}}
 try write(["prepareMS":(CACurrentMediaTime()-prepareStart)*1000,"sizes":[2048,1024,512],"filter":"Integer box average of raw RGBA bytes; same color space/bitmap metadata; no source asset writes"],"preparation.json")
 let variants:[(String,Int,CGFloat?)]=[("reload2048",2048,nil),("maps1024",1024,nil),("maps512",512,nil),("anisotropy4",0,4),("anisotropy1",0,1)]
 var results=[[String:Any]]()
 for (name,size,anisotropy) in variants {
  for pose in ["single-low","single-near","scatter-overview"] {
   try autoreleasepool {
    let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
    for m in scene.mats{m.shaderModifiers=[.surface:baseline,.fragment:fragment];field.install(on:m)}
    let properties=scene.mats.flatMap{[$0.normal,$0.roughness]}
    let originalContents=properties.map{$0.contents},originalAnisotropy=properties.map{$0.maxAnisotropy}
    func apply(_ candidate:Bool) {
     for (i,p) in properties.enumerated() {
      p.contents=(candidate && size>0) ? images[size]![i%2]:originalContents[i]
      p.maxAnisotropy=(candidate ? anisotropy:nil) ?? originalAnisotropy[i]
     };SCNTransaction.flush()
    }
    var comparisons=[[String:Any]](),maximum=0,aaMaximum=0
    for frame in 0..<6 {
     _=input(scene,pose,frame)
     apply(false);_=try target.batch(3);let a=try target.read();_=try target.frame();let aa=try target.read()
     apply(true);_=try target.batch(3);let b=try target.read()
     let delta=difference(a,b),noise=difference(a,aa)
     maximum=max(maximum,delta["maximumChannelDifference"]!);aaMaximum=max(aaMaximum,noise["maximumChannelDifference"]!)
     comparisons.append(["frame":frame,"delta":delta,"aa":noise])
     try target.save(a,"\(name)-\(pose)-\(frame)-baseline");try target.save(b,"\(name)-\(pose)-\(frame)-candidate")
    }
    try need(aaMaximum==0,"A/A resource control")
    if name=="reload2048" {try need(maximum==0,"Same-size texture reload changed appearance")}
    print("\(name) \(pose) max=\(maximum) AA=\(aaMaximum)");fflush(stdout)
    var times=[[String:Any]]()
    for kind in ["AA","AB"] {for cycle in 0..<6 {for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
     apply(kind=="AB" && arm);_=input(scene,pose,0);_=try target.batch(4)
     var samples=[FrameTime]()
     for frame in 0..<24 {_=input(scene,pose,frame%6);samples.append(try target.frame())}
     times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","gpuMS":samples.map{$0.gpu},"cpuEncodeMS":samples.map{$0.encode},"wallMS":samples.map{$0.syncWall},"frames":samples.map{$0.json}])
    }}}
    results.append(["variant":name,"pose":pose,"width":maxWidth,"maximumChannelDifference":maximum,"tolerance":1,"diagnosticOnly":true,"comparisons":comparisons,"times":times])
    try write(results,"results.json");print("\(name) \(pose) timing complete");fflush(stdout)
   }
  }
 }
}
