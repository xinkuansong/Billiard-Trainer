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

let a=pixels(CommandLine.arguments[1]),b=pixels(CommandLine.arguments[2])
var changed=Set<Int>()
for i in 0..<(a.0*a.1) { if (0..<4).contains(where:{ abs(Int(a.2[i*4+$0])-Int(b.2[i*4+$0]))>1 }) {changed.insert(i)} }
var groups:[[String:Int]]=[]
while let seed=changed.first {
 var queue=[seed],index=0;changed.remove(seed)
 while index<queue.count {let p=queue[index];index+=1
  for dy in -1...1 { for dx in -1...1 {
   let x=p%a.0+dx,y=p/a.0+dy,n=y*a.0+x
   if x>=0 && x<a.0 && y>=0 && y<a.1 && changed.remove(n) != nil {queue.append(n)}
  } }
 }
 groups.append(["pixels":queue.count,"x0":queue.map{$0%a.0}.min()!,"x1":queue.map{$0%a.0}.max()!,"y0":queue.map{$0/a.0}.min()!,"y1":queue.map{$0/a.0}.max()!])
}
let data=try JSONSerialization.data(withJSONObject:groups.sorted{ $0["pixels"]! > $1["pixels"]! },options:.sortedKeys)
print(String(data:data,encoding:.utf8)!)
