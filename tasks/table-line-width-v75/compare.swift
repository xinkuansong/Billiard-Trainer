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
let a=pixels(CommandLine.arguments[1]),b=pixels(CommandLine.arguments[2]);precondition(a.0==b.0 && a.1==b.1)
let diffs=zip(a.2,b.2).map{abs(Int($0)-Int($1))}
print("pixels=\(a.0*a.1) changedChannels=\(diffs.filter{$0>0}.count) max=\(diffs.max()!) mean=\(Double(diffs.reduce(0,+))/Double(diffs.count))")
