import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
func load(_ path:String) throws -> CGImage {
    guard let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { throw NSError(domain:"image",code:1) }
    return image
}
let args=CommandLine.arguments
let original=try load(args[1]), background=try load(args[2])
let w=1255,h=2230,x=157,y=279
let space=original.colorSpace ?? CGColorSpace(name:CGColorSpace.sRGB)!
let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.draw(background,in:CGRect(x:0,y:0,width:w,height:h))
ctx.interpolationQuality = .none
ctx.setBlendMode(.copy)
ctx.draw(original,in:CGRect(x:x,y:y,width:original.width,height:original.height))
let image=ctx.makeImage()!
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:args[3]) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,image,nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG write failed") }
print("Saved cover: \(w)x\(h), original \(original.width)x\(original.height) at (\(x),\(y)).")
