import Foundation
import AppKit
let base=URL(fileURLWithPath:CommandLine.arguments[1])
let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:base.appendingPathComponent("plot.json"))) as! [[String:Any]]
let w=1280,h=780
let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
NSColor.white.setFill();NSBezierPath(rect:NSRect(x:0,y:0,width:w,height:h)).fill()
for (i,row) in rows.enumerated() {
 let x=Double(i%2)*630+35,y=Double(1-i/2)*370+30
 let r=NSRect(x:x,y:y,width:580,height:290)
 NSColor(calibratedRed:0.93,green:0.96,blue:0.93,alpha:1).setFill();NSBezierPath(rect:r).fill()
 NSColor.lightGray.setStroke();let grid=NSBezierPath();grid.lineWidth=0.4
 for k in 0...20 {let t=Double(k)/20;grid.move(to:NSPoint(x:x+t*580,y:y));grid.line(to:NSPoint(x:x+t*580,y:y+290));grid.move(to:NSPoint(x:x,y:y+t*290));grid.line(to:NSPoint(x:x+580,y:y+t*290))};grid.stroke()
 NSColor.black.withAlphaComponent(0.5).setFill()
 for p in row["points"] as! [[Double]] {NSBezierPath(ovalIn:NSRect(x:x+(p[0]+1.27)/2.54*580-2,y:y+(p[1]+0.635)/1.27*290-2,width:4,height:4)).fill()}
 (row["title"] as! String).draw(at:NSPoint(x:x,y:y+303),withAttributes:[.font:NSFont.systemFont(ofSize:19),.foregroundColor:NSColor.black])
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:base.appendingPathComponent("distribution.png"))
