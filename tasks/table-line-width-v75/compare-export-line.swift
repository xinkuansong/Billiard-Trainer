import Foundation
import AppKit
import CoreGraphics
func pixels(_ path:String)->(Int,Int,[UInt8]) {
 let image=NSImage(contentsOfFile:path)!
 var rect=CGRect(origin:.zero,size:image.size)
 let cg=image.cgImage(forProposedRect:&rect,context:nil,hints:nil)!
 let w=cg.width,h=cg.height
 var data=[UInt8](repeating:0,count:w*h*4)
 data.withUnsafeMutableBytes { bytes in
  let ctx=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(cg,in:CGRect(x:0,y:0,width:w,height:h))
 }
 return(w,h,data)
}

let a=pixels(CommandLine.arguments[1]),b=pixels(CommandLine.arguments[2]);var diffs:[Int]=[]
for y in 0..<a.1 {for x in 0..<a.0 {
 if (230...260).contains(x) && (525...555).contains(y) {continue}
 for c in 0..<4 {let i=(y*a.0+x)*4+c;diffs.append(abs(Int(a.2[i])-Int(b.2[i])))}
}}
print("outside cue-ball ROI (230...260,525...555): changedChannels=\(diffs.filter{$0>0}.count) max=\(diffs.max()!) mean=\(Double(diffs.reduce(0,+))/Double(diffs.count))")
