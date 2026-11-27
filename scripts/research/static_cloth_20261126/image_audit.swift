import AppKit
import Foundation

// Independent PNG decode, crop/difference inspection; never edits evidence images.
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["QIUJI_TEST_EVIDENCE"]!)
let attachmentRoot = input.appendingPathComponent("attachments")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: attachmentRoot.appendingPathComponent("manifest.json"))) as! [[String:Any]]
var images = [String:URL]()
for test in manifest {
    for item in test["attachments"] as! [[String:Any]] {
        let name = item["suggestedHumanReadableName"] as! String
        let file = item["exportedFileName"] as! String
        if file.hasSuffix(".png") {
            var key=name.replacingOccurrences(of:"_[0-9]+_[0-9A-Fa-f-]{36}",with:"",options:.regularExpression)
            if key.hasSuffix(".png") {key=String(key.dropLast(4))}
            precondition(images[key]==nil,"Duplicate image identity")
            images[key] = attachmentRoot.appendingPathComponent(file)
        }
    }
}
func decode(_ url:URL) throws -> (Int,Int,[UInt8],CGImage) {
    let bitmap = NSBitmapImageRep(data:try Data(contentsOf:url))!
    let image=bitmap.cgImage!, w=image.width, h=image.height
    var pixels=[UInt8](repeating:0,count:w*h*4)
    pixels.withUnsafeMutableBytes { bytes in
        let context=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
    }
    return (w,h,pixels,image)
}
var pairs=[(String,URL,URL)]()
for key in images.keys.sorted() {
    if key.hasSuffix("-A"),let b=images[String(key.dropLast(2))+"-B"] {
        pairs.append((String(key.dropLast(2)),images[key]!,b))
        if key.hasSuffix("-failure-A") {
            for suffix in ["restored","extra-1","extra-2","extra-3"] {
                if let other=images[String(key.dropLast(1))+suffix] {
                    pairs.append((String(key.dropLast(1))+suffix,images[key]!,other))
                }
            }
        }
    } else if key.hasSuffix("-current"),let b=images[String(key.dropLast(8))+"-candidate"] {
        pairs.append((String(key.dropLast(8)),images[key]!,b))
    }
}
var rows=[[String:Any]]()
for (name,aURL,bURL) in pairs {
    let (w,h,a,_) = try decode(aURL), (bw,bh,b,_) = try decode(bURL)
    precondition(w==bw && h==bh)
    var count=0, maximum=0, green=0, overOne=0, points=[[Int]](), overOnePoints=[[Int]]()
    for i in stride(from:0,to:a.count,by:4) {
        let delta=(0..<3).map { abs(Int(a[i+$0])-Int(b[i+$0])) }.max()!
        if Int(a[i+1])>Int(a[i])+15 && Int(a[i+1])>Int(a[i+2])+15 { green+=1 }
        maximum=max(maximum,delta)
        if delta>0 { count+=1; if points.count<16 {points.append([(i/4)%w,(i/4)/w,delta])} }
        if delta>1 {
            overOne+=1
            if overOnePoints.count<64 {overOnePoints.append([(i/4)%w,(i/4)/w,delta])}
        }
    }
    rows.append(["case":name,"width":w,"height":h,"maximum":maximum,"changedPixels":count,
        "overOne":overOne,"greenReceiverProxyPixels":green,"firstDifferenceCoordinates":points,
        "firstOverOneCoordinates":overOnePoints])
}
try JSONSerialization.data(withJSONObject:["pairs":rows,"scope":"Independent decoded RGB pixels; green proxy is not a geometric cloth mask"],options:[.prettyPrinted,.sortedKeys])
    .write(to:output.appendingPathComponent("image-audit.json"))
// Six representative pockets: original above candidate, each at native scale before downsampling.
let selected=(0..<6).compactMap { i -> (String,URL,URL)? in pairs.first { $0.0=="pocket-\(i)-5" } }
if selected.count==6 {
    let w=1800,h=1380
    let context=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,
        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor.darkGray.cgColor);context.fill(CGRect(x:0,y:0,width:w,height:h))
    for (index,entry) in selected.enumerated() {
        for (arm,url) in [entry.1,entry.2].enumerated() {
            let (_,_,_,image)=try decode(url)
            let x=(index%3)*600,y=h-(index/3)*690-(arm+1)*343
            context.draw(image,in:CGRect(x:x,y:y,width:600,height:343))
        }
    }
    let bitmap=NSBitmapImageRep(cgImage:context.makeImage()!)
    try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("six-pockets-A-above-B.png"))
}
print("Independently audited \(rows.count) image pairs")
