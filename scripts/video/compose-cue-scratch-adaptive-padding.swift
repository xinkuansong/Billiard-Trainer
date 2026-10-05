import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
func load(_ path:String) throws -> CGImage {
 guard let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else {throw NSError(domain:path,code:1)}
 return image
}
let root=URL(fileURLWithPath:CommandLine.arguments[1]),out=root.appendingPathComponent("padding-comparison-adaptive-panel")
let ids=["M067","M071","M007","M030","M033","M053"]
var records:[[String:Any]]=[]
for percent in [5,10,15,20] {
 let folder=out.appendingPathComponent(String(format:"%02d-percent",percent))
 try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
 for i in 0...6 {
  let isCover=i==0,id=isCover ? "cover" : ids[i-1]
  let source=root.appendingPathComponent(isCover ? "topdown-r4-rail-labels/封面.png" : "topdown-r5-adaptive-panel/\(id).png")
  let original=try load(source.path),ow=original.width,oh=original.height
  let p=Double(percent)/100
  let padx=Int(ceil(Double(ow)*p/(1-2*p))),pady=Int(ceil(Double(oh)*p/(1-2*p)))
  let w=ow+padx*2,h=oh+pady*2
  let bg=try load(root.appendingPathComponent("padding-comparison/"+(isCover ? "M067-scene.png" : "\(id)-scene.png")).path)
  let maxW=2400,maxH=4000
  let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:original.colorSpace ?? CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.interpolationQuality = .high
  ctx.draw(bg,in:CGRect(x:Double(w-maxW)/2,y:Double(h-maxH)/2,width:Double(maxW),height:Double(maxH)))
  ctx.interpolationQuality = .none;ctx.setBlendMode(.copy)
  ctx.draw(original,in:CGRect(x:padx,y:pady,width:ow,height:oh))
  let name=isCover ? "00-封面.png" : String(format:"%02d-",i)+"\(id).png"
  let file=folder.appendingPathComponent(name)
  let destination=CGImageDestinationCreateWithURL(file as CFURL,UTType.png.identifier as CFString,1,nil)!
  CGImageDestinationAddImage(destination,ctx.makeImage()!,nil)
  guard CGImageDestinationFinalize(destination) else {fatalError("PNG write failed")}
  records.append(["percent":percent,"id":id,"path":file.path,"source":source.path,"width":w,"height":h,"originalRect":[padx,pady,ow,oh]])
 }
}
try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("variants.json"))
print("Exported \(records.count) protected-original PNGs.")
