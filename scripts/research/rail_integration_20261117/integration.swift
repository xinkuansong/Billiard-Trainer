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

    func testRailAppearanceIntegration() throws {
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

        let size = CGSize(width: 1600, height: 1000)
        scene.cameraRig?.viewportSize = size
        scene.setCameraMode(.perspective3D, animated: false)
        scene.hideAllBalls()
        let keys = ["cueBall", "_15", "_2"]
        for (i,key) in keys.enumerated() {
            scene.showBall(key: key, scenePosition: SCNVector3((Float(i)-1)*0.16, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
        }
        var mats = [SCNMaterial](), seen = Set<ObjectIdentifier>()
        func collect(_ n: SCNNode, clothOnly: Bool) {
            for m in n.geometry?.materials ?? [] where (!clothOnly || m.name == "TaiNi") && seen.insert(ObjectIdentifier(m)).inserted { mats.append(m) }
        }
        scene.tableNode?.enumerateChildNodes { n,_ in collect(n, clothOnly: true) }
        try require(!mats.isEmpty, "Cloth materials found")
        let productionModifiers = mats.map { $0.shaderModifiers ?? [:] }
        let productionProperties = mats.map { $0.value(forKey: "bedRailVisibility") }
        for m in mats {
            try require(m.value(forKey: "bedRailVisibility") != nil, "Production resource installed")
            MobileRailAppearance.remove(from: m)
        }
        let originals = mats.map { $0.shaderModifiers ?? [:] }
        let target = try RenderTarget(device: device, scene: scene, size: size)
        let camera = try XCTUnwrap(scene.cameraNode)
        let exposure = camera.camera!.exposureOffset
        // Keep the original dark cushion face; only the existing rounded nose
        // receives a weak diffuse transition. No whole-side lift or bed bounce.
        let lip = """
        if(p.y>0.8005) {
            float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
            float railLip=smoothstep(-0.30,-0.05,railG.y)*(1.0-smoothstep(0.30,0.70,railG.y));
            float3 railSoftNormal=normalize(n+float3(0,0.18,0));
            float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-v62PanelDiffuse(p,n),float3(0.0));
            _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;
        }
        """
        // Local shadow tone adjustment, not a change to light power or exposure.
        // Preserve the bed, bright cushion top, and the bottom contact strip.
        let shadowLift = """
        if(p.y>0.8005) {
            float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
            float railSide=1.0-smoothstep(-0.15,0.35,railG.y);
            float railFoot=smoothstep(0.802,0.814,p.y);
            float3 railIncident=E/3.14159265+0.26*_surface.ambientOcclusion;
            float railPeak=max(railIncident.r,max(railIncident.g,railIncident.b));
            float railDark=1.0-smoothstep(0.30,0.65,railPeak);
            _surface.emission.rgb*=1.0+0.16*railSide*railFoot*railDark;
        }
        """
        func install(_ mode: String) throws {
            for (i,m) in mats.enumerated() {
                var mods = originals[i]
                let original = try XCTUnwrap(mods[.surface])
                if ["lift","bed"].contains(mode) {
                    let geo=mods[.geometry] ?? "#pragma body"
                    mods[.geometry]=geo+"\nfloat4 railUVWorld=scn_node.modelTransform*_geometry.position; if(railUVWorld.y>0.8005) _geometry.texcoords[0]*=1.5;"
                    if ["lift","bed"].contains(mode) {
                        let anchor="_surface.diffuse.rgb=float3(0.0);"
                        try require(original.components(separatedBy:anchor).count==2,"Unique cloth output anchor")
                        mods[.surface]=original.replacingOccurrences(of:anchor,with:lip+"\n"+shadowLift+"\n"+anchor)
                    }
                    if mode == "bed" {
                        var combined=try XCTUnwrap(mods[.surface])
                        let declaration="#pragma arguments\ntexture2d<float> bedRailVisibility;\n#pragma body"
                        combined=combined.replacingOccurrences(of:"#pragma body",with:declaration)
                        let shade="_surface.emission.rgb = "
                        try require(combined.components(separatedBy:shade).count==2,"Unique cloth irradiance consumer")
                        let attenuation="if(abs(p.y-0.8)<0.0005) { constexpr sampler bedShadowSampler(coord::normalized,address::clamp_to_edge,filter::linear); float2 bedShadowUV=(p.xz+float2(1.27,0.635))/float2(2.54,1.27); E*=bedRailVisibility.sample(bedShadowSampler,bedShadowUV).r; }\n"
                        mods[.surface]=combined.replacingOccurrences(of:shade,with:attenuation+shade)
                        m.setValue(SCNMaterialProperty(contents:railTexture),forKey:"bedRailVisibility")
                    }
                } else if mode == "normal" {
                    mods[.fragment]="#pragma body\nfloat3 diagnosticNormal=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz); _output.color=float4(diagnosticNormal*0.5+0.5,1.0);"
                } else if mode == "mask" {
                    mods[.surface]=original.replacingOccurrences(of:"_surface.diffuse.rgb=float3(0.0);",with:"if(p.y>0.8005) _surface.emission.rgb=float3(2.0,0.0,2.0);\n_surface.diffuse.rgb=float3(0.0);")
                } else if mode == "wholeClothMask" {
                    mods[.fragment]="#pragma body\n_output.color=float4(1.0,0.0,1.0,1.0);"
                }
                m.shaderModifiers=mods
            }
            SCNTransaction.flush()
        }
        var report = [[String: Any]]()
        for view in ["low", "oblique", "detail", "pocket", "top"] {
            try install("original")
            if view == "top" { scene.setCameraMode(.topDown2D, animated: false) }
            else if view == "detail" || view == "pocket" {
                scene.setCameraMode(.perspective3D, animated:false)
                let detailX:Float = view == "pocket" ? 0 : 0.6
                let aim=SIMD3<Float>(detailX,0.823,-0.635)
                let eye=SIMD3<Float>(detailX,1.03,-0.18)
                let delta=eye-aim
                let pose=TwoViewCamera.Pose.looking(eye:eye,yaw:.pi/2,pitch:-atan2(delta.y,delta.z),fov:45)
                camera.simdTransform=pose.transform
                camera.camera!.fieldOfView=45
                camera.camera!.usesOrthographicProjection=false
                try require(simd_length(pose.forward-simd_normalize(aim-eye))<0.00001,"Detail camera aims at actual long cushion")
            }
            else {
                scene.setCameraMode(.perspective3D, animated: false)
                let height: Float = view == "low" ? 0.20 : 0.45
                let radius: Float = 1.50
                let yaw: Float = view == "low" ? .pi/2 : .pi/4
                let eye = SIMD3<Float>(cos(yaw)*radius, scene.surfaceY+height, sin(yaw)*radius)
                let pose = TwoViewCamera.Pose.looking(eye: eye, yaw: yaw, pitch: -atan2(height,radius), fov: 50)
                camera.simdTransform = pose.transform
                camera.camera!.fieldOfView = 50
                camera.camera!.usesOrthographicProjection = false
                try require(simd_length(pose.forward - simd_normalize(SIMD3<Float>(0,scene.surfaceY,0)-eye)) < 0.00001, "Camera aims at cloth centre")
            }
            for (i,m) in mats.enumerated() {
                m.shaderModifiers=productionModifiers[i]
                m.setValue(productionProperties[i],forKey:"bedRailVisibility")
            }
            SCNTransaction.flush()
            _ = try target.render(frames: 8)
            let production = try target.readback()
            attach(production,"rail-integrated-\(view)")
            try require(production.magentaPixels == 0,"Production shader compiled")
            try install("original")
            SCNTransaction.flush()
            _ = try target.render(frames: 8)
            let baseline = try target.readback()
            attach(baseline, "rail-bed-shadow-\(view)-A-original")
            try install("mask"); _ = try target.render(frames: 4)
            let mask = try target.readback()
            attach(mask,"rail-bed-shadow-\(view)-diagnostic-surfaceMask")
            var targetPixels = Set<Int>()
            for p in stride(from: 0, to: baseline.bgra.count, by: 4) {
                if (0..<3).contains(where: { baseline.bgra[p+$0] != mask.bgra[p+$0] }) { targetPixels.insert(p) }
            }
            try install("wholeClothMask"); _=try target.render(frames:4)
            let wholeMask=try target.readback()
            var wholePixels=Set<Int>()
            for p in stride(from:0,to:baseline.bgra.count,by:4) {
                if (0..<3).contains(where:{baseline.bgra[p+$0] != wholeMask.bgra[p+$0]}) {wholePixels.insert(p)}
            }
            for (name,mode) in [("B-lift","lift"),("C-bedShadow","bed")] {
                try install(mode); _ = try target.render(frames: 5)
                let frame = try target.readback()
                attach(frame, "rail-bed-shadow-\(view)-\(name)")
                if mode == "bed" {
                    let productionDifference = difference(production,frame)
                    try require(productionDifference.maximum == 0, "Production matches approved geometry-baked preview exactly")
                }
                let delta = difference(baseline,frame)
                var outside = 0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !targetPixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outside += 1}
                }
                try require(frame.magentaPixels == 0, "Valid static bed shadow output")
                var outsideCloth=0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !wholePixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outsideCloth+=1}
                }
                try require(outsideCloth==0,"Non-cloth material pixels unchanged")
                try require(camera.camera!.exposureOffset == exposure, "Exposure unchanged")
                report.append(["view":view,"variant":name,"mode":mode,"changedPixels":delta.changedPixels,"maximumChannelDelta":delta.maximum,"outsideClothChangedPixels":outsideCloth,"outsideRailChangedPixels":outside])
            }
            if view == "oblique" {
                for mode in ["normal"] {
                    try install(mode); _ = try target.render(frames:5)
                    attach(try target.readback(),"rail-bed-shadow-\(view)-diagnostic-\(mode)")
                }
            }
            try install("original"); _ = try target.render(frames: 5)
            try require(difference(baseline,try target.readback()).maximum == 0,"Exact original restoration")
        }
        attachStrictReport(["scope":"Current production SceneKit on native Mac; no SwiftUI HUD or phone acceptance", "exposure":exposure,"room":"tournament","size":[1600,1000],"targetMaterials":mats.count,"rows":report],name:"rail-bed-shadow-preview.json")

    }
