import AppKit
import Foundation
let evidence=URL(fileURLWithPath:ProcessInfo.processInfo.environment["QIUJI_TEST_EVIDENCE"]!)
func files(_ path:String)throws->[String:URL]{
 let root=URL(fileURLWithPath:path).appendingPathComponent("attachments")
 let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("manifest.json"))) as! [[String:Any]]
 var result=[String:URL]()
 for test in manifest {for item in test["attachments"] as! [[String:Any]] {
  let f=item["exportedFileName"] as! String
  if !f.hasSuffix(".png"){continue}
  var n=(item["suggestedHumanReadableName"] as! String).replacingOccurrences(of:"_[0-9]+_[0-9A-Fa-f-]{36}",with:"",options:.regularExpression)
  if n.hasSuffix(".png"){n=String(n.dropLast(4))}
  precondition(result[n]==nil);result[n]=root.appendingPathComponent(f)
 }};return result
}
func decode(_ url:URL)throws->(Int,Int,[UInt8],CGImage){
 let image=NSBitmapImageRep(data:try Data(contentsOf:url))!.cgImage!,w=image.width,h=image.height
 var pixels=[UInt8](repeating:0,count:w*h*4)
 pixels.withUnsafeMutableBytes{b in
  let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
 };return(w,h,pixels,image)
}
let original=try files(CommandLine.arguments[1]),masks=try files(CommandLine.arguments[2])
var rows=[[String:Any]]()
let names=original.keys.filter{$0.hasSuffix("-A") || $0.hasSuffix("-current")}.sorted()
for aKey in names {
 let current=aKey.hasSuffix("-current"),base=String(aKey.dropLast(current ? 8:2)),bKey=base+(current ? "-candidate":"-B")
 guard let bURL=original[bKey],let mURL=masks[bKey] else{fatalError("Missing matching image: \(bKey)")}
 let(w,h,a,aImage)=try decode(original[aKey]!), (bw,bh,b,bImage)=try decode(bURL),(mw,mh,mask,_)=try decode(mURL)
 precondition(w==bw && w==mw && h==bh && h==mh)
 // The final rendered/decoded tag varies across the bed; its pipeline cause is not established.
 // Classify the deliberately separated magenta/cyan labels, verify no original
 // pixels match magenta, then erode one pixel to exclude mixed MSAA edges.
 func pink(_ pixels:[UInt8],_ i:Int)->Bool {pixels[i]>180 && pixels[i+1]<80 && pixels[i+2]>180}
 let flags=(0..<(w*h)).map{pink(mask,$0*4)}
 let baselineFalsePositives=(0..<(w*h)).filter{pink(a,$0*4)}.count
 precondition(baselineFalsePositives==0,"Tag colour collides with original scene")
 let classified=flags.filter{$0}.count
 if current {precondition(classified>1000,"Actual bed mask must be populated")}
 var histogram=[Int](repeating:0,count:256),count=0,sum=0,maxPoints=[[Int]](),maxDelta=0
 for y in 1..<(h-1){for x in 1..<(w-1){
  if (-1...1).allSatisfy({dy in (-1...1).allSatisfy{dx in flags[(y+dy)*w+x+dx]}}) {
   let i=(y*w+x)*4,d=(0..<3).map{abs(Int(a[i+$0])-Int(b[i+$0]))}.max()!
   histogram[d]+=1;sum+=d;count+=1
   if d>maxDelta{maxDelta=d;maxPoints=[]}
   if d==maxDelta && maxPoints.count<8{maxPoints.append([x,y])}
  }
 }}
 if count==0 {precondition(base.contains("-0.3999-"),"Unexpected empty receiver region")}
 func quantile(_ f:Double)->Int{let goal=max(1,Int(ceil(Double(count)*f)));var n=0;for i in 0..<256{n+=histogram[i];if n>=goal{return i}};return 0}
 rows.append(["case":base,"classifiedMaskPixels":classified,"baselineTagFalsePositives":baselineFalsePositives,"maximumCoordinates":maxPoints,"roiPixels":count,"changedPixels":count-histogram[0],"overTwo":histogram.dropFirst(3).reduce(0,+),"meanMaxRGBDifference":count>0 ? Double(sum)/Double(count):0,"p95":quantile(0.95),"p99":quantile(0.99),"maximum":quantile(1),"histogram":histogram])
 if current {
  let c=CGContext(data:nil,width:w*2,height:h,bitsPerComponent:8,bytesPerRow:w*8,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.draw(aImage,in:CGRect(x:0,y:0,width:w,height:h));c.draw(bImage,in:CGRect(x:w,y:0,width:w,height:h))
  let bitmap=NSBitmapImageRep(cgImage:c.makeImage()!)
  try bitmap.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent(base+"-A-left-B-right.png"))
 }
}
try JSONSerialization.data(withJSONObject:["rows":rows,"scope":"Actual same-surface bed eligibility tag: render-tolerant magenta classification, zero original tag collisions, 1px erosion. Not a green-cloth proxy. Original left, candidate right."],options:[.prettyPrinted,.sortedKeys]).write(to:evidence.appendingPathComponent("response-review.json"))
print("Reviewed \(rows.count) actual receiver pairs")
