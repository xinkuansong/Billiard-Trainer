import SceneKit

/// S267 reference lighting, production since the v62 closeout (ADR-P5-01).
/// Original assets and physics are unchanged. Shader sources are generated from
/// output/render-quality-v62/S287-adaptive-sampling; keep that derivation evidence.
enum MobileReferenceLighting {
    /// Fixed calibrated scene contract. Environment fits must be regenerated if
    /// its environment or table geometry changes; this is not a user light editor.
    struct Rig {
        let panelHeight = 3.0
        let panelWidth = 2.0
        let panelDepth = 0.5
        let panelOffset = 0.35
        let radiance = 44.5714854
        let environmentBase = 0.06
        let environmentHorizon = 1.2
        // Native SceneKit uses a different calibrated intensity scale.
        let nativeIntensity: CGFloat = 15000

        func shader(_ source: String) -> String {
            let values: [String: String] = [
                "HEIGHT": String(panelHeight), "WIDTH": String(panelWidth),
                "DEPTH": String(panelDepth), "HALF_WIDTH": String(panelWidth / 2),
                "HALF_DEPTH": String(panelDepth / 2), "OFFSET": String(panelOffset),
                "DX": String(panelWidth / 8), "DZ": String(panelDepth / 4),
                "RADIANCE": String(radiance), "ENV_BASE": String(environmentBase),
                "ENV_HORIZON": String(environmentHorizon)
            ]
            return values.reduce(source) { text, item in
                text.replacingOccurrences(of: "{{" + item.key + "}}", with: item.value)
            }
        }
    }
    static let rig = Rig()

    /// Same gate as the mobile base path; there is no "mobile without reference" mode.
    static var requested: Bool { MobileTableRendering.isEnabled }

    // S390 calibrated trial; keep the prior preview available without this flag.
    static var balanceTrialRequested: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-v62.balanceOneToTwo") || ProcessInfo.processInfo.environment["V62_BALANCE_ONE_TO_TWO"] == "1"
        #else
        return false
        #endif
    }
    static let trialTopGain = 0.5845556338079108
    static let trialFillGain = 1.7806465814547177
    private static func trialShader(_ source: String) -> String {
        guard balanceTrialRequested else { return source }
        return source.replacingOccurrences(of: "44.5714854", with: String(rig.radiance * trialTopGain))
            .replacingOccurrences(of: "+0.26", with: "+(0.26*\(trialFillGain))")
            .replacingOccurrences(of: "max(roomIrradiance,float3(0.0))", with: "(max(roomIrradiance,float3(0.0))*\(trialFillGain))")
    }

    static let environment: Data = {
        let width=512, height=256
        var data=Data("#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y \(height) +X \(width)\n".utf8)
        for y in 0..<height {
            let directionY=cos(Double.pi*(Double(y)+0.5)/Double(height))
            let value=rig.environmentBase+rig.environmentHorizon*pow(1-abs(directionY),2)
            var exponent:Int32=0
            let fraction=frexp(value,&exponent)
            let channel=UInt8(min(255,Int(fraction*256)))
            for _ in 0..<width { data.append(contentsOf:[channel,channel,channel,UInt8(exponent+128)]) }
        }
        return data
    }()

    /// Shader template placeholder value; `applyBall` substitutes the production finish.
    static let ballRoughness = 0.30
    /// Photo-reference finish for the user-selected numbered-ball packs.
    /// Same light transport and energy, with a narrower resin reflection lobe.
    /// 0.12 → 0.05: phenolic resin is near-mirror; with the room probe the
    /// wider lobe smeared the panel highlights into grey patches (film look).
    static let stickerBallRoughness = 0.05

    /// Shader argument block shared by every ball material: cloth bounce colour
    /// plus the room reflection probe (equirect texture + SH9 irradiance).
    static let ballShaderArguments: String = {
        var block = "#pragma arguments\nfloat3 selectedClothAlbedo;\ntexture2d<float> roomReflection;\nfloat3 roomFloor;\n"
        for i in 0..<9 { block += "float3 roomSH\(i);\n" }
        return block + "#pragma declaration\n"
    }()

    static func applyBall(to node: SCNNode, exposureOffset: CGFloat, stickerFinish: Bool = false,
                          probe: RoomReflectionProbe? = nil) {
        let probe = probe ?? RoomReflectionProbe.neutral
        func apply(_ node:SCNNode) {
            for m in node.geometry?.materials ?? [] {
                m.lightingModel = .constant
                let roughness = stickerFinish ? stickerBallRoughness : 0.34
                let surface = ballShader.replacingOccurrences(of: "float roughness=\(ballRoughness);", with: "float roughness=\(roughness);")
                let coloredSurface = ballShaderArguments + surface.replacingOccurrences(
                    of: "float3 clothAlbedo=float3(0.0074764,0.1612358,0.0036536);",
                    with: "float3 clothAlbedo=selectedClothAlbedo;")
                m.shaderModifiers = [.surface:trialShader(coloredSurface)]
                m.setValue(NSValue(scnVector3: ClothColor.green.linearAlbedo), forKey: "selectedClothAlbedo")
                probe?.install(on: m)
                applyHighlightHeadroom(to: m, exposureOffset: exposureOffset)
            }
        }
        apply(node);node.enumerateChildNodes { node,_ in apply(node) }
    }

    static func applyClothBounce(_ color: ClothColor, to node: SCNNode) {
        func update(_ node: SCNNode) {
            for material in node.geometry?.materials ?? [] {
                guard material.shaderModifiers?[.surface]?.contains("selectedClothAlbedo") == true else { continue }
                material.setValue(NSValue(scnVector3: color.linearAlbedo), forKey: "selectedClothAlbedo")
            }
        }
        update(node); node.enumerateChildNodes { node, _ in update(node) }
    }

    static func apply(to scene:AngleTrainingScene) {
        // setupScene already applies the rig on device Debug. Diagnostic callers
        // may ask again; never append another cloth program or emitter pair.
        guard scene.rootNode.childNode(withName: "S267AreaPanel", recursively: false) == nil else { return }
        scene.rootNode.enumerateChildNodes { node,_ in
            if node.light != nil { node.light?.intensity=0 }
        }
        // UIImage decodes the same RGBE data as the URL-based diagnostic.
        scene.lightingEnvironment.contents=UIImage(data:environment)
        scene.lightingEnvironment.intensity=1
        for z in [Float(-rig.panelOffset),Float(rig.panelOffset)] {
            let light=SCNLight();light.type = .area;light.areaType = .rectangle
            light.areaExtents=SIMD3<Float>(Float(rig.panelWidth),Float(rig.panelDepth),0);light.intensity=rig.nativeIntensity * (balanceTrialRequested ? CGFloat(trialTopGain) : 1)
            light.drawsArea=false;light.doubleSided=true;light.attenuationEndDistance=10
            let node=SCNNode();node.name="S267AreaPanel";node.light=light
            node.position=SCNVector3(0,Float(rig.panelHeight),z)
            node.look(at:SCNVector3(0,scene.surfaceY,z),up:SCNVector3(0,0,1),localFront:SCNVector3(0,0,-1))
            scene.rootNode.addChildNode(node)
        }
        for (key,node) in scene.allBallNodes {
            let numbered = key.hasPrefix("_") && (Int(key.dropFirst()).map { (1...15).contains($0) } ?? false)
            applyBall(to:node, exposureOffset: scene.cameraNode.camera?.exposureOffset ?? 0, stickerFinish: numbered,
                      probe: scene.roomReflectionProbe)
        }
        var shadow="", bounds="bool nearShadow=false;\n", possible="bool shadowPossible=false;\n"
        for i in 0..<scene.allBallNodes.count {
            shadow += """
            if(contactBall\(i).w>0.0) {
                float3 center=float3(contactBall\(i).x,0.8+contactBall\(i).z,contactBall\(i).y);
                float3 toCenter=center-p;float t=dot(toCenter,l);
                float perpendicular2=dot(toCenter,toCenter)-t*t;
                if(t>0.0 && t*t<r2 && perpendicular2 < 0.028575*0.028575) visibility *= 1.0-min(1.0,contactBall\(i).w/0.85);
            }
            """
            // Conservative projected bounding sphere: include its top and radius,
            // not only center height. Keep the existing nearShadow sample rule.
            possible += """
            if(contactBall\(i).w>0.0) {
                float top=contactBall\(i).z+0.028575;
                float bound=0.028575+top/max(0.01,2.2-top)*(length(contactBall\(i).xy)+1.3);
                float2 offset=p.xz-contactBall\(i).xy;
                shadowPossible=shadowPossible || top>=2.2 || dot(offset,offset)<=bound*bound;
            }
            """
            bounds += """
            if(contactBall\(i).w>0.0) {
                float bound=0.028575+contactBall\(i).z/max(0.01,2.2-contactBall\(i).z)*(length(contactBall\(i).xy)+1.3);
                float2 offset=p.xz-contactBall\(i).xy;
                nearShadow=nearShadow || dot(offset,offset)<bound*bound;
            }
            """
        }
        let shader=clothShader.replacingOccurrences(of:"// SHADOW",with:"if(shadowPossible) {\n"+shadow+"\n}")
            .replacingOccurrences(of:"// NEAR_SHADOW",with:bounds+possible)
        scene.tableNode?.enumerateChildNodes { node,_ in
            for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                var mods=m.shaderModifiers ?? [:]
                var contactSource = mods[.surface] ?? "#pragma body"
                // The shared buffer carries legacy 85% artistic opacity. Decode
                // it for opaque sphere ambient visibility, as direct shadows do.
                // Keep buffer values, fades, sphere size and culling untouched.
                for i in 0..<scene.allBallNodes.count {
                    contactSource = contactSource.replacingOccurrences(
                        of: "contactVisibility *= 1.0 - contactBall\(i).w *",
                        with: "contactVisibility *= 1.0 - (contactBall\(i).w / \(MobileContactOcclusion.encodedOpacityScale)) *")
                }
                mods[.surface]=trialShader(contactSource+"\n"+shader)
                m.lightingModel = .physicallyBased;m.shaderModifiers=mods
            }
        }
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "MG_Gold" {
                // Warm painted/cast leg body, not a polished conductor. Restrict
                // to the table's named finish; cue ferrules and Gold trim retain theirs.
                material.metalness.contents = 0.0
                material.roughness.contents = 0.68
                material.specular.contents = 0.25
                material.diffuse.contents = UIColor(red: 0.34, green: 0.22, blue: 0.14, alpha: 1)
                material.lightingModel = .constant
                material.shaderModifiers = [.surface: trialShader(matteWoodShader)]
            }
            for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                // Matte wood consumes the same emitter irradiance directly. Do
                // not subtract a native PBR contribution after output mapping.
                material.lightingModel = .constant
                material.shaderModifiers = [.surface: trialShader(matteWoodShader)]
            }
        }
        applySurfaceFinishes(to: scene)
        var visited = Set<ObjectIdentifier>()
        scene.rootNode.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where visited.insert(ObjectIdentifier(material)).inserted {
                applyHighlightHeadroom(to: material, exposureOffset: scene.cameraNode.camera?.exposureOffset ?? 0)
            }
        }

    }

    /// Output mapping shared by reference materials. Keep diffuse-range values
    /// unchanged; compress only highlights into the current exposure's headroom.
    private static func applyHighlightHeadroom(to material: SCNMaterial, exposureOffset: CGFloat) {
        let headroom = pow(2.0, -Double(exposureOffset)) - 1
        guard headroom > 0 else { return }
        var modifiers = material.shaderModifiers ?? [:]
        let existing = modifiers[.fragment] ?? "#pragma body"
        guard !existing.contains("// v62HighlightHeadroom") else { return }
        modifiers[.fragment] = existing + "\n" + """
        // v62HighlightHeadroom
        float outputPeak=max(_output.color.r,max(_output.color.g,_output.color.b));
        if(outputPeak>1.0) {
            float mapped=1.0+\(headroom)*(1.0-exp(-(outputPeak-1.0)/\(headroom)));
            _output.color.rgb*=mapped/outputPeak;
        }
        """
        material.shaderModifiers = modifiers
    }

    // Exact projected solid angle of a horizon-clipped rectangular emitter.
    // Same radiance/geometry as the sampled reference; no shadow approximation changes.
    static let analyticPanelDiffuse = rig.shader("""
    float v62RectIrradiance(float3 p, float3 n, float z) {
        float3 v[4]={float3(-{{HALF_WIDTH}},{{HEIGHT}},z-{{HALF_DEPTH}})-p,float3(-{{HALF_WIDTH}},{{HEIGHT}},z+{{HALF_DEPTH}})-p,
                     float3({{HALF_WIDTH}},{{HEIGHT}},z+{{HALF_DEPTH}})-p,float3({{HALF_WIDTH}},{{HEIGHT}},z-{{HALF_DEPTH}})-p};
        float3 clipped[8];int count=0;
        for(int i=0;i<4;++i) {
            float3 a=v[i],b=v[(i+1)%4];float da=dot(a,n),db=dot(b,n);
            if(da>=0.0) clipped[count++]=a;
            if((da>=0.0)!=(db>=0.0)) clipped[count++]=a+(b-a)*(da/(da-db));
        }
        if(count<3) return 0.0;
        float integral=0.0;
        for(int i=0;i<count;++i) {
            float3 a=normalize(clipped[i]),b=normalize(clipped[(i+1)%count]);
            float3 c=cross(a,b);float lengthC=length(c);
            if(lengthC>0.0000001) integral+=atan2(lengthC,dot(a,b))*dot(c,n)/lengthC;
        }
        return abs(integral)*0.5;
    }
    float3 v62PanelDiffuse(float3 p, float3 n) {
        return float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*
            (v62RectIrradiance(p,n,-{{OFFSET}})+v62RectIrradiance(p,n,{{OFFSET}}));
    }
    """)

    /// Cue varnish, pocket leather and ball finish. The training room is a
    /// separate scene-assembly step (`AngleTrainingScene.setupScene`).
    static func applySurfaceFinishes(to scene: AngleTrainingScene) {
        scene.cueStick?.rootNode.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] {
                if m.normal.contents is UIColor { m.normal.contents = nil }
                switch m.name ?? "" {
                case "copp", "MG_Gold":
                    m.roughness.contents = Float(0.45)
                default:
                    m.lightingModel = .constant
                    m.roughness.contents = Float(m.name == "PiTou" ? 0.85 : 0.48)
                    m.shaderModifiers = [.surface: satinShader]
                }
                applyHighlightHeadroom(to: m, exposureOffset: scene.cameraNode.camera?.exposureOffset ?? 0)
            }
        }
        scene.tableNode?.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] where m.name == "Leather" {
                m.lightingModel = .constant
                m.normal.intensity = 0.5
                m.shaderModifiers = [.surface: satinShader]
                applyHighlightHeadroom(to: m, exposureOffset: scene.cameraNode.camera?.exposureOffset ?? 0)
            }
        }
        // Ball finish (0.34 non-sticker roughness) is applied in `applyBall`.
    }

    static func roomTexture(_ name: String) -> UIImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else {
            preconditionFailure("Missing room texture: \(name)")
        }
        return roomRGBA(image)
    }

    static func roomRGBA(_ image: UIImage) -> UIImage {
        guard let source = image.cgImage,
              let context = CGContext(data: nil, width: source.width, height: source.height,
                bitsPerComponent: 8, bytesPerRow: source.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            preconditionFailure("Cannot create room RGBA texture")
        }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let result = context.makeImage() else { preconditionFailure("Cannot encode room texture") }
        return UIImage(cgImage: result)
    }

    // A precomputed-style pool of light, visual only. Existing ball lighting stays fixed.
    // One shared emitter model for satin cue varnish and textured leather.
    // Preserve albedo/UVs; integrate a broad GGX lobe without a white additive coat.
    private static let satinShader = analyticPanelDiffuse + "\n" + rig.shader("""
    #pragma body
    // v62SatinFinish
    float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
    float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
    float3 v=normalize(scn_frame.inverseViewTransform[3].xyz-p);
    float nv=max(0.001,dot(n,v));float rough=clamp(_surface.roughness,0.48,0.9);
    float a2=pow(rough,4.0);float3 spec=float3(0.0);
    for(int panel=0;panel<2;panel++) {
        for(int ix=0;ix<4;ix++) for(int iz=0;iz<2;iz++) {
            float3 lp=float3(-{{HALF_WIDTH}}+(float(ix)+0.5)*{{WIDTH}}/4.0,{{HEIGHT}},(panel==0?-{{OFFSET}}:{{OFFSET}})-{{HALF_DEPTH}}+(float(iz)+0.5)*{{DEPTH}}/2.0);
            float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);float nl=max(0.001,dot(n,l));
            float3 h=normalize(l+v);float nh=max(0.0,dot(n,h));float vh=max(0.0,dot(v,h));
            float denom=nh*nh*(a2-1.0)+1.0;float D=a2/(3.14159265*denom*denom);
            float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
            float F=0.04+0.96*pow(1.0-vh,5.0);
            spec+=float3(1,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,l.y)/r2/8.0*D*G*F/(4.0*nv*nl);
        }
    }
    _surface.diffuse.rgb=_surface.diffuse.rgb*(v62PanelDiffuse(p,n)/3.14159265+0.26)*0.96+spec;
    """)

    static let matteWoodShader = analyticPanelDiffuse + "\n" + """
    #pragma body
    float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
    float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
    _surface.diffuse.rgb *= v62PanelDiffuse(p,n)/3.14159265+0.26;
    """

    private static let ballShader: String = {
        let start = sampledBallShader.range(of: "float3 v62PanelDiffuse(")!
        let end = sampledBallShader.range(of: "float v62World(")!
        var source = sampledBallShader
        source.replaceSubrange(start.lowerBound..<end.lowerBound, with: analyticPanelDiffuse + "\n")
        return source
    }()

    // Retained as the numerical/visual reference while validating GPU cost.
    static let sampledBallShader = rig.shader("""
    float v62worldIntegral(float x) { return max(0.0,((((((((((((-0.08636586539832361*x+0.03358324878023771)*x+0.1807681120541014)*x+-0.0901518898599715)*x+-0.1398822803391923)*x+0.08601738357243822)*x+0.03544987957333094)*x+-0.0342965481779107)*x+-0.026459309315669012)*x+0.0051020175297182765)*x+-0.10414811593646554)*x+0.12979997791360942)*x+0.27073602068087366)); }
    float v62bounceIntegral(float x) { return max(0.0,((((((((((((0.7391315655967717*x+-0.521674143216907)*x+-1.8109810807609321)*x+1.2213403850849287)*x+1.5632528571973532)*x+-0.909670480224779)*x+-0.7209205166011029)*x+0.4267268481308019)*x+-0.003853721433570013)*x+0.11345215688244002)*x+-0.2082655686807922)*x+-0.3286814509996016)*x+0.4405794885548977)); }
    float3 v62PanelDiffuse(float3 p, float3 n) {
        float3 E=float3(0.0);
        for (int panel=0; panel<2; ++panel) {
            for (int ix=0; ix<8; ++ix) {
                for (int iz=0; iz<4; ++iz) {
                    float3 lp=float3(-{{HALF_WIDTH}}+(float(ix)+0.5)*{{DX}},{{HEIGHT}},(panel==0?-{{OFFSET}}:{{OFFSET}})-{{HALF_DEPTH}}+(float(iz)+0.5)*{{DZ}});
                    float3 delta=lp-p; float r2=dot(delta,delta); float3 l=delta/sqrt(r2);
                    E += float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,l.y)/r2*(1.0/32.0);
                }
            }
        }
        return E;
    }
    float v62World(float3 d) { return {{ENV_BASE}}+{{ENV_HORIZON}}*pow(1.0-abs(d.y),2.0); }
    // Room probe: equirect radiance baked from the installed training room
    // (RoomReflectionProbe). Mapping must match RoomReflectionProbe.uv(for:).
    // `#pragma arguments` are only visible in the body, so the texture is passed in.
    float3 v62Room(texture2d<float> room, float3 d, float lod) {
        constexpr sampler roomSampler(coord::normalized, s_address::repeat, t_address::clamp_to_edge, filter::linear, mip_filter::linear);
        float2 uv=float2(atan2(d.x,-d.z)*0.15915494+0.5, acos(clamp(d.y,-1.0,1.0))*0.31830989);
        return room.sample(roomSampler, uv, level(lod)).rgb;
    }
    float3 v62Reflection(texture2d<float> room, float3 reflected, float3 p, float3 center, float3 clothRadiance, float lod, float3 floorRadiance, float clothWeight) {
    float3 result=v62Room(room,reflected,lod);
    if(reflected.y < -0.00001) {
        // Only a forward hit counts: below the table plane (pocket net, return
        // rail) the old code extrapolated backwards onto the cloth (DR-303).
        float t=(0.8-p.y)/reflected.y;
        if(t>0.0) {
            float3 q=p+reflected*t;
            if(abs(q.x)<1.27 && abs(q.z)<0.635) {
                float r2=dot(q.xz-center.xz,q.xz-center.xz);
                result=clothRadiance*clamp(r2/(r2+0.028575*0.028575),0.0,1.0);
            }
        }
        // The probe's lower hemisphere is the cloth as seen from the table
        // centre; a ball under the table sees the floor instead.
        result=mix(floorRadiance,result,clothWeight);
    }
    if (reflected.y>0.0001) {
        float distance=({{HEIGHT}}-p.y)/reflected.y;
        float3 hit=p+distance*reflected;
        float width=clamp(fwidth(hit.x),0.008,0.05);
        float depth=clamp(fwidth(hit.z),0.008,0.05);
        float panelMask=0.0;
        for(int panel=0;panel<2;++panel) {
            float z=panel==0?-{{OFFSET}}:{{OFFSET}};
            panelMask = panelMask + (1.0-smoothstep({{HALF_WIDTH}}-width,{{HALF_WIDTH}}+width,abs(hit.x))) * (1.0-smoothstep({{HALF_DEPTH}}-depth,{{HALF_DEPTH}}+depth,abs(hit.z-z)));
        }
        result+=float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*panelMask;
    }
    return result;
    }
    #pragma body
    float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
    float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
    float3 camera=scn_frame.inverseViewTransform[3].xyz;
    float3 v=normalize(camera-p);
    float3 albedo=_surface.diffuse.rgb;
    float3 tangent=normalize(cross(abs(n.y)<0.99?float3(0,1,0):float3(1,0,0),n));
    float3 bitangent=cross(n,tangent);
    float3 env=float3(0.0);
    float3 center=p-n*0.028575;
    // Cloth terms assume the ball rests on the table plane (centre at 0.8+R).
    // Fade them out as the ball drops below the plane into the net / return rail.
    float clothWeight=clamp((center.y-0.8)/0.028575,0.0,1.0);
    float3 clothAlbedo=float3(0.0074764,0.1612358,0.0036536);
    float3 clothRadiance=clothAlbedo*(v62PanelDiffuse(float3(p.x,0.8,p.z),float3(0,1,0))/3.14159265+0.26);
    // Preview color calibration: retain half the cloth bounce chroma in both
    // diffuse and specular transport; luminance and contact occlusion stay intact.
    clothRadiance=mix(float3(dot(clothRadiance,float3(0.2126,0.7152,0.0722))),clothRadiance,0.5)*clothWeight;
    // Upper-hemisphere room irradiance / π from SH9 (cosine lobe pre-applied on CPU).
    float3 roomIrradiance=roomSH0*0.282095
        +roomSH1*(0.488603*n.y)+roomSH2*(0.488603*n.z)+roomSH3*(0.488603*n.x)
        +roomSH4*(1.092548*n.x*n.y)+roomSH5*(1.092548*n.y*n.z)+roomSH6*(0.315392*(3.0*n.z*n.z-1.0))
        +roomSH7*(1.092548*n.x*n.z)+roomSH8*(0.546274*(n.x*n.x-n.y*n.y));
    // Below the table the lower hemisphere is the floor, not the lit cloth.
    env=max(roomIrradiance,float3(0.0))+(clothRadiance+roomFloor*(1.0-clothWeight))*v62bounceIntegral(n.y);
    // Integrate the glossy reflection over GGX microfacet normals instead of
    // selecting one perfectly sharp environment/table ray for the whole lobe.
    float nv=max(0.001,dot(n,v));
    float roughness=\(ballRoughness);
    // Probe mip level grows with the lobe width so 64 samples stay noise-free.
    float roomLod=roughness*5.0;
    float alpha=roughness*roughness;
    float a2=alpha*alpha;
    float3 spec=float3(0.0);
    for(int i=0;i<64;++i) {
        float u=(float(i)+0.5)/64.0;
        float phi=6.2831853*fract(float(i)*0.61803398875);
        float ct=sqrt((1.0-u)/(1.0+(a2-1.0)*u));
        float st=sqrt(max(0.0,1.0-ct*ct));
        float3 h=normalize(tangent*(cos(phi)*st)+bitangent*(sin(phi)*st)+n*ct);
        float vh=max(0.0,dot(v,h));
        float3 l=reflect(-v,h);
        float nl=dot(n,l);
        if(nl>0.0 && vh>0.0) {
            float g=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
            float f=0.04+0.96*pow(1.0-vh,5.0);
            spec+=v62Reflection(roomReflection,l,p,center,clothRadiance,roomLod,roomFloor,clothWeight)*f*g*vh/(max(0.001,ct)*nv*64.0);
        }
    }
    float F=0.04+0.96*pow(1.0-max(0.0,dot(n,v)),5.0);
    _surface.diffuse.rgb=albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)+spec;
    """)

    private static let clothShader = rig.shader("""
    float3 p=contactWorld;
    float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
    float3 E=float3(0.0);float3 S=float3(0.0);
    float3 v=normalize(scn_frame.inverseViewTransform[3].xyz-p);
    float nv=max(0.001,dot(n,v));
    float alpha=max(0.01,_surface.roughness*_surface.roughness);
    float a2=alpha*alpha;
    // NEAR_SHADOW
    int samplesX=nearShadow?8:2;
    int samplesZ=nearShadow?4:2;
    for(int panel=0;panel<2;++panel) {
     for(int ix=0;ix<samplesX;++ix) {
      for(int iz=0;iz<samplesZ;++iz) {
       float3 lp=float3(-{{HALF_WIDTH}}+(float(ix)+0.5)*({{WIDTH}}/float(samplesX)),{{HEIGHT}},(panel==0?-{{OFFSET}}:{{OFFSET}})-{{HALF_DEPTH}}+(float(iz)+0.5)*({{DEPTH}}/float(samplesZ)));
       float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
       float visibility=1.0;
       // SHADOW
       float nl=max(0.001,dot(n,l));float3 h=normalize(l+v);float nh=max(0.0,dot(n,h));float vh=max(0.0,dot(v,h));
       float denom=nh*nh*(a2-1.0)+1.0;
       float D=a2/(3.14159265*denom*denom);
       float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
       float F=0.012+0.988*pow(1.0-vh,5.0);
       float3 weighted=float3(1,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,l.y)/r2/float(samplesX*samplesZ)*visibility;
       E+=weighted; S+=weighted*D*G*F/(4.0*nv*nl);
      }
     }
    }
    _surface.emission.rgb = (_surface.diffuse.rgb * _surface.multiply.rgb) * (E/3.14159265+0.26*_surface.ambientOcclusion)+0.35*S+0.35*float3(max(0.0,((((((((((-0.028803310033256934*nv+0.18720610088795223)*nv+-0.5502767636063797)*nv+0.9752880522825459)*nv+-1.17736218879761)*nv+1.0399023440946362)*nv+-0.6934645105632581)*nv+0.32180425209794744)*nv+-0.053736086147546894)*nv+-0.0426628106982577)*nv+0.023864333781715107)));
    _surface.diffuse.rgb=float3(0.0);
    _surface.metalness=1.0;
    
    _surface.multiply.rgb=float3(1.0);
    """)
}
