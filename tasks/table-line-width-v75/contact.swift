import AppKit
import Foundation
let out=CommandLine.arguments[1], paths=Array(CommandLine.arguments.dropFirst(2))
let w:CGFloat=640,h:CGFloat=330,cols=2,rows=(paths.count+1)/2
let image=NSImage(size:NSSize(width:w*2,height:h*CGFloat(rows)))
image.lockFocus();NSColor.black.setFill();NSRect(origin:.zero,size:image.size).fill()
for (i,p) in paths.enumerated(){
 let x=CGFloat(i%cols)*w,y=CGFloat(rows-1-i/cols)*h
 let source=NSImage(contentsOfFile:p)!, scale=min(w/source.size.width,(h-24)/source.size.height)
 let size=NSSize(width:source.size.width*scale,height:source.size.height*scale)
 source.draw(in:NSRect(x:x,y:y,width:size.width,height:size.height))
 (URL(fileURLWithPath:p).deletingPathExtension().lastPathComponent as NSString).draw(at:NSPoint(x:x+8,y:y+h-22),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.white])
}
image.unlockFocus()
let data=NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!
try data.write(to:URL(fileURLWithPath:out))
