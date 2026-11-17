struct RailBedBVH {
    typealias V = SIMD3<Double>
    struct Triangle {
        let a: V, b: V, c: V
        var lo: V { simd_min(a,simd_min(b,c)) }
        var hi: V { simd_max(a,simd_max(b,c)) }
        var center: V { (a+b+c)/3 }
        func hits(_ p: V,_ d: V) -> Bool {
            let e1=b-a,e2=c-a,h=simd_cross(d,e2),det=simd_dot(e1,h)
            if abs(det)<1e-13 {return false}
            let f=1/det,s=p-a,u=f*simd_dot(s,h)
            if u < -1e-10 || u > 1+1e-10 {return false}
            let q=simd_cross(s,e1),v=f*simd_dot(d,q)
            if v < -1e-10 || u+v > 1+1e-10 {return false}
            let t=f*simd_dot(e2,q)
            return t>1e-8 && t<1-1e-8
        }
    }
    struct Node {let lo:V,hi:V,left:Int,right:Int,start:Int,end:Int}
    let triangles:[Triangle]
    var nodes=[Node](),order=[Int]()
    init(_ triangles:[Triangle]) {
        self.triangles=triangles
        if !triangles.isEmpty {_=build(Array(triangles.indices))}
    }
    mutating func build(_ ids:[Int]) -> Int {
        var lo=V(repeating:Double.infinity),hi=V(repeating:-Double.infinity)
        for i in ids {lo=simd_min(lo,triangles[i].lo);hi=simd_max(hi,triangles[i].hi)}
        let index=nodes.count
        nodes.append(Node(lo:lo,hi:hi,left:-1,right:-1,start:0,end:0))
        if ids.count<=6 {
            let start=order.count;order.append(contentsOf:ids)
            nodes[index]=Node(lo:lo,hi:hi,left:-1,right:-1,start:start,end:order.count)
        } else {
            let span=hi-lo;let axis=span.x>span.y ? (span.x>span.z ? 0:2):(span.y>span.z ? 1:2)
            let sorted=ids.sorted {triangles[$0].center[axis]<triangles[$1].center[axis]}
            let mid=sorted.count/2
            let left=build(Array(sorted[..<mid])),right=build(Array(sorted[mid...]))
            nodes[index]=Node(lo:lo,hi:hi,left:left,right:right,start:0,end:0)
        }
        return index
    }
    func occluded(_ p:V,_ d:V) -> Bool {
        if nodes.isEmpty {return false}
        return hitNode(0,p,d,V(1/d.x,1/d.y,1/d.z))
    }
    func hitNode(_ i:Int,_ p:V,_ d:V,_ inv:V) -> Bool {
        let node=nodes[i];var near=0.0,far=1.0
        for k in 0..<3 {
            if abs(d[k])<1e-14 {
                if p[k]<node.lo[k] || p[k]>node.hi[k] {return false}
            } else {
                let a=(node.lo[k]-p[k])*inv[k],b=(node.hi[k]-p[k])*inv[k]
                near=max(near,min(a,b));far=min(far,max(a,b))
                if near>far {return false}
            }
        }
        if node.left<0 {
            for j in node.start..<node.end where triangles[order[j]].hits(p,d) {return true}
            return false
        }
        return hitNode(node.left,p,d,inv) || hitNode(node.right,p,d,inv)
    }
}

    func testExportRailVisibility() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "Appearance")
        // Bake only table geometry above the actual aligned cloth plane.
        // Values are irradiance-weighted visibility of the existing light panels.
        let bakeStart=CACurrentMediaTime()
        let table=try XCTUnwrap(scene.tableNode)
        let bedY=try XCTUnwrap(MobileClothAlignment.measuredBedY(in:scene))
        var names=Set<String>()
        table.enumerateChildNodes {n,_ in for m in n.geometry?.materials ?? [] {if let name=m.name {names.insert(name)}}}
        let mesh=try PocketContactMesh.load(table:table,worldRoot:scene.rootNode,pocketID:"rail-shadow-bake",center:SCNVector3Zero,surfaceY:scene.surfaceY,bedY:bedY,alignCloth:true,coverage:.fullTable,materials:names)
        let receiverY=Double(scene.surfaceY)+0.00001
        let triangles=mesh.patches.map {RailBedBVH.Triangle(a:$0.triangle.a,b:$0.triangle.b,c:$0.triangle.c)}.filter {$0.hi.y>receiverY}
        try require(!triangles.isEmpty,"Raised table occluders found")
        let bvh=RailBedBVH(triangles)
        let width=1024,height=512,hx=Double(AngleSceneCalculator.innerLength)/2,hz=Double(AngleSceneCalculator.innerWidth)/2
        let panels=MobileReferenceLighting.rig.panels
        var potential=[Bool](repeating:false,count:width*height)
        // Conservative projected bounds limit work without assuming four straight rails.
        for triangle in triangles {
            let vertices=[triangle.a,triangle.b,triangle.c]
            var clipped=[SIMD3<Double>]()
            for j in 0..<3 {
                let a=vertices[j],b=vertices[(j+1)%3]
                if a.y>=receiverY {clipped.append(a)}
                if (a.y>=receiverY) != (b.y>=receiverY) {clipped.append(a+(b-a)*((receiverY-a.y)/(b.y-a.y)))}
            }
            if clipped.isEmpty {continue}
            var lo=SIMD2<Double>(repeating:Double.infinity),hi=SIMD2<Double>(repeating:-Double.infinity)
            for panel in panels {for light in panel.corners {for v in clipped {
                let q=light+(v-light)*((receiverY-light.y)/(v.y-light.y))
                lo=simd_min(lo,SIMD2(q.x,q.z));hi=simd_max(hi,SIMD2(q.x,q.z))
            }}}
            let x0=max(0,min(width-1,Int(floor((lo.x+hx)/(2*hx)*Double(width)))-1))
            let x1=max(0,min(width-1,Int(ceil((hi.x+hx)/(2*hx)*Double(width)))+1))
            let y0=max(0,min(height-1,Int(floor((lo.y+hz)/(2*hz)*Double(height)))-1))
            let y1=max(0,min(height-1,Int(ceil((hi.y+hz)/(2*hz)*Double(height)))+1))
            for y in y0...y1 {for x in x0...x1 {potential[y*width+x]=true}}
        }
        let samplesX=16,samplesZ=8
        var lights=[(SIMD3<Double>,Double)]()
        for panel in panels {for x in 0..<samplesX {for z in 0..<samplesZ {
            let lp=panel.center+panel.u*(2*(Double(x)+0.5)/Double(samplesX)-1)+panel.v*(2*(Double(z)+0.5)/Double(samplesZ)-1)
            lights.append((lp,panel.area*panel.gain))
        }}}
        // Acceleration is checked against direct triangle intersection at representative rays.
        for p in [SIMD3<Double>(0,receiverY,0),SIMD3<Double>(0.6,receiverY,-hz+0.003),SIMD3<Double>(0,receiverY,-hz+0.003),SIMD3<Double>(hx-0.01,receiverY,hz-0.01)] {
            for i in stride(from:0,to:lights.count,by:17) {
                let d=lights[i].0-p
                try require(bvh.occluded(p,d)==triangles.contains(where:{$0.hits(p,d)}),"BVH matches brute force table rays")
            }
        }
        var visibility=[Float](repeating:1,count:width*height)
        for y in 0..<height {for x in 0..<width where potential[y*width+x] {
            let p=SIMD3<Double>((Double(x)+0.5)/Double(width)*2*hx-hx,receiverY,(Double(y)+0.5)/Double(height)*2*hz-hz)
            var total=0.0,visible=0.0
            for (light,area) in lights {
                let d=light-p,r2=simd_length_squared(d)
                let weight=area*d.y*d.y/(r2*r2)
                total+=weight
                if !bvh.occluded(p,d) {visible+=weight}
            }
            visibility[y*width+x]=Float(visible/total)
        }}
        try require(visibility.allSatisfy{$0.isFinite && $0>=0 && $0<=1},"Finite visibility within zero to one")
        try require(visibility[(height/2)*width+width/2]==1,"Table centre has no rail shadow")
        let raw = visibility.withUnsafeBytes { Data($0) }
        let rawAttachment = XCTAttachment(data: raw, uniformTypeIdentifier: "public.data")
        rawAttachment.name = "MobileRailDirectVisibility.f32"
        rawAttachment.lifetime = .keepAlways
        add(rawAttachment)
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r32Float,width:width,height:height,mipmapped:false)
        descriptor.usage = .shaderRead;descriptor.storageMode = .shared
        let railTexture=try XCTUnwrap(device.makeTexture(descriptor:descriptor))
        visibility.withUnsafeBytes {railTexture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*4)}
        var rgba=[UInt8](repeating:255,count:width*height*4)
        for i in visibility.indices {let c=UInt8((visibility[i]*255).rounded());rgba[4*i]=c;rgba[4*i+1]=c;rgba[4*i+2]=c}
        let provider=try XCTUnwrap(CGDataProvider(data:Data(rgba) as CFData))
        let diagnostic=try XCTUnwrap(CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
        let mapAttachment=XCTAttachment(image:UIImage(cgImage:diagnostic));mapAttachment.name="rail-bed-shadow-visibility";mapAttachment.lifetime = .keepAlways;add(mapAttachment)
        attachStrictReport(["width":width,"height":height,"triangles":triangles.count,"nodes":bvh.nodes.count,"raysPerTexel":lights.count,"potentialTexels":potential.filter{$0}.count,"minimum":visibility.min()!,"bakeSeconds":CACurrentMediaTime()-bakeStart,"receiverY":receiverY],name:"rail-bed-shadow-bake.json")

    }
