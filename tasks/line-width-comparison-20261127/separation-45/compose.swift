import AppKit
let base=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
for mode in ["2D","3D"] {
    let names=["A","B","C"]
    let images=try names.map { name -> NSImage in
        guard let image=NSImage(contentsOf:base.appendingPathComponent("separation-\(mode)-\(name).png")) else { throw NSError(domain:"Missing screenshot",code:1) }
        return image
    }
    let rep=try NSBitmapImageRep(data:Data(contentsOf:base.appendingPathComponent("separation-\(mode)-A.png")))!
    let w=rep.pixelsWide,h=rep.pixelsHigh,header=58,total=(h+header)*3
    let canvas=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:total,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:canvas)
    NSColor(calibratedWhite:0.065,alpha:1).setFill();NSRect(x:0,y:0,width:w,height:total).fill()
    let labels=["A  当前主线 5.6 mm", "B  候选主线 4.5 mm", "C  候选主线 4 mm"]
    for i in 0..<3 {
        let bottom=total-(i+1)*(h+header)
        images[i].draw(in:NSRect(x:0,y:bottom,width:w,height:h),from:.zero,operation:.copy,fraction:1,respectFlipped:false,hints:[.interpolation:NSImageInterpolation.none])
        (labels[i] as NSString).draw(at:NSPoint(x:24,y:bottom+h+15),withAttributes:[.font:NSFont.systemFont(ofSize:25,weight:.semibold),.foregroundColor:NSColor.white])
    }
    NSGraphicsContext.restoreGraphicsState()
    try canvas.representation(using:.png,properties:[:])!.write(to:base.appendingPathComponent("comparison-separation-\(mode).png"))
    print("\(mode): \(w)x\(total)")
}
