import SceneKit
#if DEBUG
import MetalKit
#endif

/// S267 reference lighting, production since the v62 closeout (ADR-P5-01).
/// Original assets and physics are unchanged. Shared wide-emitter geometry extends the
/// S287 transport; calibration and motion evidence live in output/canopy-light-20260915.
enum MobileReferenceLighting {
    /// Fixed calibrated scene contract. Environment fits must be regenerated if
    /// its environment or table geometry changes; this is not a user light editor.
    struct Panel {
        let center: SIMD3<Double>
        let u: SIMD3<Double>
        let v: SIMD3<Double>
        let gain: Double
        var normal: SIMD3<Double> { simd_normalize(simd_cross(u, v)) }
        var area: Double { 4 * simd_length(simd_cross(u, v)) }
        var corners: [SIMD3<Double>] { [center-u-v, center-u+v, center+u+v, center+u-v] }
        var transform: SCNMatrix4 {
            let x = SIMD3<Float>(simd_normalize(u))
            // SCNLight emits along local -Z; keep a right-handed transform.
            let y = SIMD3<Float>(-simd_normalize(v))
            let z = SIMD3<Float>(-normal)
            return SCNMatrix4(simd_float4x4(SIMD4(x, 0), SIMD4(y, 0), SIMD4(z, 0), SIMD4(SIMD3<Float>(center), 1)))
        }
    }

    struct Rig {
        let panelHeight = 3.0
        // Each total dimension is twice the playfield (four times its area).
        let panelWidth = 2 * Double(TablePhysics.innerLength)
        let panelDepth = Double(TablePhysics.innerWidth)
        var panelOffset: Double { panelDepth / 2 }
        var panelArea: Double { panelWidth * panelDepth }
        var panels: [Panel] {
            [-panelOffset, panelOffset].map {
                Panel(center: SIMD3(0, panelHeight, $0), u: SIMD3(panelWidth/2, 0, 0),
                      v: SIMD3(0, 0, panelDepth/2), gain: 1)
            }
        }
        var emitterRadius: Double { panels.flatMap(\.corners).map { hypot($0.x, $0.z) }.max()! }
        var shadowSupportRadius: Double {
            emitterRadius + panels.enumerated().map {
                sqrt($0.element.area / 32 / .pi)
            }.max()!
        }
        var minimumHeight: Double { panelHeight }

        // Match the previously approved flat emitter's centre irradiance.
        // The enlarged surface redistributes light without another exposure increase.
        var radiance: Double { Self.calibratedRadiance }
        private static let calibratedRadiance: Double = {
            let panels = Rig().panels
            func irradiance(_ panel: Panel) -> Double {
                var total = 0.0
                for x in 0..<32 { for z in 0..<32 {
                    let point = panel.center + panel.u * (2*(Double(x)+0.5)/32-1)
                        + panel.v * (2*(Double(z)+0.5)/32-1)
                    let delta = point - SIMD3<Double>(0, 0.8, 0)
                    let r2 = simd_length_squared(delta)
                    let l = delta / sqrt(r2)
                    total += max(0, l.y) * max(0, simd_dot(panel.normal, -l)) / r2
                } }
                return total * panel.area * panel.gain / 1024
            }
            let reference = panels.map { panel in
                Panel(center: SIMD3(panel.center.x/2, panel.center.y, panel.center.z/2),
                      u: panel.u/2, v: panel.v/2, gain: panel.gain)
            }
            return 32.84539390996302 * reference.map(irradiance).reduce(0, +)
                / panels.map(irradiance).reduce(0, +)
        }()
        let environmentBase = 0.06
        let environmentHorizon = 1.2
        // Native SceneKit uses a different calibrated intensity scale.
        var nativeIntensity: CGFloat { 15000 * CGFloat(radiance / 44.5714854 * panelArea) }

        func shader(_ source: String) -> String {
            let values: [String: String] = [
                "HEIGHT": String(panelHeight), "WIDTH": String(panelWidth),
                "DEPTH": String(panelDepth), "HALF_WIDTH": String(panelWidth / 2),
                "AREA": String(panelArea), "PANEL_COUNT": String(panels.count),
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
        return source.replacingOccurrences(of: String(rig.radiance), with: String(rig.radiance * trialTopGain))
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
    enum SamplingProfile {
        case reference, reducedShadows, reducedReflections, balanced
    }

    // Preview opt-in only until cool-device performance and motion quality pass.
    // Release behavior remains the reference profile.
    private static var previewSamplingProfile: SamplingProfile {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-balancedRendering") { return .balanced }
        #endif
        return .reference
    }

    static func samplingShader(_ source: String, profile: SamplingProfile) -> String {
        var result = source
        if profile == .reducedShadows || profile == .balanced {
            result = result.replacingOccurrences(of: "int samplesX=shadowPossible?8:2;", with: "int samplesX=shadowPossible?4:2;")
        }
        if profile == .reducedReflections || profile == .balanced {
            result = result.replacingOccurrences(of: "for(int i=0;i<64;++i)", with: "for(int i=0;i<32;++i)")
                .replacingOccurrences(of: "(float(i)+0.5)/64.0", with: "(float(i)+0.5)/32.0")
                .replacingOccurrences(of: "*nv*64.0", with: "*nv*32.0")
        }
        return result
    }

    enum SpecializedProfile: String, CaseIterable {
        case reference = "A", reflection = "R", shadow = "S", combined = "RS"
        var usesReflection: Bool { self == .reflection || self == .combined }
        var usesShadow: Bool { self == .shadow || self == .combined }
    }

    /// Shared baseline. Daily clearance opts into R on its own scene before setup.
    static var specializedProfile: SpecializedProfile {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-specializedRendering"), args.indices.contains(index + 1),
           let profile = SpecializedProfile(rawValue: args[index + 1]) { return profile }
        #endif
        return .reference
    }

    static func filteredBallShader(_ source: String) -> String {
        guard !source.contains("// v2SplitSum"),
              let begin = source.range(of: "// Probe mip level"),
              let end = source.range(of: "float F=0.04", range: begin.upperBound..<source.endIndex) else { return source }
        var result = source
        result.replaceSubrange(begin.lowerBound..<end.lowerBound, with: """
        // v2SplitSum
        constexpr sampler responseSampler(coord::normalized, address::clamp_to_edge, filter::linear);
        float2 brdf=reflectionResponse.sample(responseSampler,float2(nv,roughness)).rg;
        float3 reflected=reflect(-v,n);
        float3 spec=v2FilteredReflection(filteredRoom,reflected,p,center,clothRadiance,roughness,roomFloor,clothWeight)*(0.04*brdf.x+brdf.y);

        """)
        result = result.replacingOccurrences(of: "texture2d<float> roomReflection;",
            with: "texture2d<float> roomReflection;\ntexture2d<float> filteredRoom;\ntexture2d<float> reflectionResponse;")
        return result.replacingOccurrences(of: "#pragma body", with: filteredReflectionFunctions + "\n#pragma body")
    }

    /// Restore the original integral when a replacement probe cannot be prepared.
    static func referenceBallShader(_ source: String) -> String {
        guard let begin=source.range(of:"// v2SplitSum"),
              let end=source.range(of:"float F=0.04",range:begin.upperBound..<source.endIndex),
              let originalStart=ballShader.range(of:"// Probe mip level"),
              let originalEnd=ballShader.range(of:"float F=0.04",range:originalStart.upperBound..<ballShader.endIndex) else { return source }
        var result=source
        result.replaceSubrange(begin.lowerBound..<end.lowerBound,with:String(ballShader[originalStart.lowerBound..<originalEnd.lowerBound]))
        return result.replacingOccurrences(of:filteredReflectionFunctions+"\n",with:"")
            .replacingOccurrences(of:"\ntexture2d<float> filteredRoom;\ntexture2d<float> reflectionResponse;",with:"")
    }

    // Separable GGX slope CDF approximates the rectangular reflected emitter.
    // This is a split-sum area-light approximation, not exact LTC or ray tracing.
    private static let filteredReflectionFunctions = rig.shader("""
    float v2SlopeCDF(float x,float scale) { return 0.5+0.5*x*rsqrt(x*x+scale*scale); }
    float3 v2FilteredReflection(texture2d<float> room,float3 reflected,float3 p,float3 center,float3 clothRadiance,float roughness,float3 floorRadiance,float clothWeight) {
        float3 result=v62Room(room,reflected,roughness*float(room.get_num_mip_levels()-1));
        float alpha=roughness*roughness;
        if(reflected.y < -0.00001) {
            float t=(0.8-p.y)/reflected.y;
            if(t>0.0) {
                float3 q=p+reflected*t;
                float width=max(0.0001,2.0*alpha*t/max(0.05,abs(reflected.y)));
                float mask=(v2SlopeCDF(1.27-q.x,width)-v2SlopeCDF(-1.27-q.x,width))
                          *(v2SlopeCDF(0.635-q.z,width)-v2SlopeCDF(-0.635-q.z,width));
                float r2=dot(q.xz-center.xz,q.xz-center.xz);
                result=mix(result,clothRadiance*clamp(r2/(r2+0.028575*0.028575),0.0,1.0),mask);
            }
            result=mix(floorRadiance,result,clothWeight);
        }
        for(int panel=0;panel<{{PANEL_COUNT}};++panel) {
            float3 pn=v62EmitterNormal(panel),u=v62EmitterU(panel),w=v62EmitterV(panel);
            float denominator=dot(pn,reflected);
            if(denominator>=-0.00001) continue;
            float distance=dot(pn,v62EmitterCenter(panel)-p)/denominator;
            if(distance<=0.0) continue;
            float3 hit=p+distance*reflected-v62EmitterCenter(panel);
            float x=dot(hit,normalize(u)),z=dot(hit,normalize(w));
            float spread=2.0*alpha*distance/max(0.05,abs(denominator));
            float width=max(clamp(fwidth(x),0.008,0.05),spread);
            float depth=max(clamp(fwidth(z),0.008,0.05),spread);
            float mask=(v2SlopeCDF(length(u)-x,width)-v2SlopeCDF(-length(u)-x,width))
                      *(v2SlopeCDF(length(w)-z,depth)-v2SlopeCDF(-length(w)-z,depth));
            result+=float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*mask*v62EmitterGain(panel);
        }
        return result;
    }
    """)

    static let ballShaderArguments: String = {
        var block = "#pragma arguments\nfloat3 selectedClothAlbedo;\ntexture2d<float> roomReflection;\nfloat3 roomFloor;\n"
        for i in 0..<9 { block += "float3 roomSH\(i);\n" }
        return block + "#pragma declaration\n"
    }()

    static func applyBall(to node: SCNNode, exposureOffset: CGFloat, stickerFinish: Bool = false,
                          probe: RoomReflectionProbe? = nil, profile: SpecializedProfile? = nil) {
        let probe = probe ?? RoomReflectionProbe.neutral
        func apply(_ node:SCNNode) {
            for m in node.geometry?.materials ?? [] {
                m.lightingModel = .constant
                let roughness = stickerFinish ? stickerBallRoughness : 0.34
                let surface = ballShader.replacingOccurrences(of: "float roughness=\(ballRoughness);", with: "float roughness=\(roughness);")
                let coloredSurface = ballShaderArguments + surface.replacingOccurrences(
                    of: "float3 clothAlbedo=float3(0.0074764,0.1612358,0.0036536);",
                    with: "float3 clothAlbedo=selectedClothAlbedo;")
                m.shaderModifiers = [.surface:trialShader(samplingShader(coloredSurface, profile: previewSamplingProfile))]
                m.setValue(NSValue(scnVector3: ClothColor.green.linearAlbedo), forKey: "selectedClothAlbedo")
                probe?.install(on: m, usesPrefilteredReflection: (profile ?? specializedProfile).usesReflection)
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
        for panel in rig.panels {
            let light = SCNLight(); light.type = .area; light.areaType = .rectangle
            light.areaExtents = SIMD3(Float(2*simd_length(panel.u)), Float(2*simd_length(panel.v)), 0)
            light.intensity = 15000 * CGFloat(rig.radiance / 44.5714854 * panel.area * panel.gain)
                * (balanceTrialRequested ? CGFloat(trialTopGain) : 1)
            light.drawsArea = false; light.doubleSided = true; light.attenuationEndDistance = 10
            let node = SCNNode(); node.name = "S267AreaPanel"; node.light = light
            node.transform = panel.transform
            scene.rootNode.addChildNode(node)
        }
        for (key,node) in scene.allBallNodes {
            let numbered = key.hasPrefix("_") && (Int(key.dropFirst()).map { (1...15).contains($0) } ?? false)
            applyBall(to:node, exposureOffset: scene.cameraNode.camera?.exposureOffset ?? 0, stickerFinish: numbered,
                      probe: scene.roomReflectionProbe, profile: scene.renderingProfile)
        }
        let shader = directShadowShader(ballCount: scene.allBallNodes.count, profile: scene.renderingProfile,
                                        mergesSupport: scene.mergesDailyClothSupport,
                                        factorsBRDF: scene.factorsDailyClothBRDF)
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
                contactSource = contactSource.replacingOccurrences(of: "#pragma body",
                    with: "#pragma declaration\n" + analyticPanelDiffuse + (scene.renderingProfile.usesShadow ? "\n" + analyticShadowFunctions : "") + "\n#pragma body")
                mods[.surface]=trialShader(contactSource+"\n"+shader)
                m.lightingModel = .physicallyBased;m.shaderModifiers=mods
                #if DEBUG
                if scene.usesClothLightingPrototype {
                    do {
                        try applyClothLightingPrototype(to: m)
                        print("[DailyClothPrototype] active: explicit linear roughness, constant emission")
                    } catch {
                        print("[DailyClothPrototype] reference fallback: \(error)")
                    }
                }
                #endif
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
                // Source-aligned roughness modulates a weak matte coating. The
                // diffuse illumination and theme albedo remain independently owned.
                material.lightingModel = .constant
                TableSurfaceTextures.bindWood(to: material)
                material.shaderModifiers = [.surface: trialShader(woodCoatShader)]
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

    /// Cull provably irrelevant blockers once per receiver, retaining the exact
    /// emitter grid/filter and ascending multiplication order. A single bit mask
    /// avoids keeping one live branch predicate per ball across every light sample.
    /// `usesMask: false` provides the original program for equivalence diagnostics.
    static func directShadowShader(ballCount: Int, usesMask: Bool = true, specialized: Bool = true,
                                   profile: SpecializedProfile? = nil,
                                   mergesSupport: Bool = false, factorsBRDF: Bool = false) -> String {
        if specialized && (profile ?? specializedProfile).usesShadow { return analyticDirectShadowShader(ballCount: ballCount) }
        var shadow="", possible="bool shadowPossible=false;\n"
        var firstBallShadow = ""
        var mask = "uint shadowMask=0u;\n"
        var mergedSupport = "// daily3DMergedSupport\nbool shadowPossible=false;\nuint shadowMask=0u;\n"
        for i in 0..<ballCount {
            shadow += """
            if(contactBall\(i).w>0.0) {
                float3 center=float3(contactBall\(i).x,0.8+contactBall\(i).z,contactBall\(i).y);
                float3 toCenter=center-p;float t=dot(toCenter,l);
                float perpendicular2=dot(toCenter,toCenter)-t*t;
                if(t>0.0 && t*t<r2) {
                    // Project the equal-area light-sample disk onto the blocker.
                    // Deterministic footprint filtering replaces binary sample jumps.
                    float filterRadius=max(0.000001,lightCellRadius*t/sqrt(r2));
                    float distanceToRay=sqrt(max(0.0,perpendicular2));
                    float blocked=1.0-smoothstep(0.028575-filterRadius,0.028575+filterRadius,distanceToRay);
                    visibility *= 1.0-min(1.0,contactBall\(i).w/0.85)*blocked;
                }
            }
            """
            if i == 0 { firstBallShadow = shadow }
            mask += """
            if(contactBall\(i).w>0.0) {
                float top=contactBall\(i).z+0.028575;
                float bound=0.028575+top/max(0.01,\(rig.minimumHeight - 0.8)-top)*(length(contactBall\(i).xy)+\(rig.shadowSupportRadius));
                float2 offset=p.xz-contactBall\(i).xy;
                if(p.y<0.8 || top>=\(rig.minimumHeight - 0.8) || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<\(i));
            }
            """
            // Conservative support includes the sphere top and filtered sample
            // footprint. Use the lowest emitter height for every panel.
            possible += """
            if(contactBall\(i).w>0.0) {
                float top=contactBall\(i).z+0.028575;
                float bound=0.028575+top/max(0.01,\(rig.minimumHeight - 0.8)-top)*(length(contactBall\(i).xy)+\(rig.shadowSupportRadius));
                float2 offset=p.xz-contactBall\(i).xy;
                shadowPossible=shadowPossible || top>=\(rig.minimumHeight - 0.8) || dot(offset,offset)<=bound*bound;
            }
            """
            // The reference intentionally gives receivers below the cloth a
            // wider blocker mask without changing the quadrature selection.
            // Preserve both predicates while evaluating their shared bound once.
            mergedSupport += """
            if(contactBall\(i).w>0.0) {
                float top=contactBall\(i).z+0.028575;
                float bound=0.028575+top/max(0.01,\(rig.minimumHeight - 0.8)-top)*(length(contactBall\(i).xy)+\(rig.shadowSupportRadius));
                float2 offset=p.xz-contactBall\(i).xy;
                bool inSupport=top>=\(rig.minimumHeight - 0.8) || dot(offset,offset)<=bound*bound;
                shadowPossible=shadowPossible || inSupport;
                if(p.y<0.8 || inSupport) shadowMask |= (1u<<\(i));
            }
            """
        }
        let masked = usesMask && (1...32).contains(ballCount)
        if masked {
            shadow = "uint remainingShadowBalls=shadowMask;\nwhile(remainingShadowBalls!=0u) {\nuint shadowIndex=ctz(remainingShadowBalls);\nremainingShadowBalls &= remainingShadowBalls-1u;\nfloat4 shadowBall=shadowBalls[shadowIndex];\n"
                + firstBallShadow.replacingOccurrences(of: "contactBall0", with: "shadowBall") + "\n}"
        }
        var cloth = clothShader
        if factorsBRDF {
            // Smith G/(4*nv*nl) = 1/((nv+sqrt(...))*(nl+sqrt(...))).
            // nv/nl retain the reference positive clamps. Light samples,
            // roughness, visibility and their accumulation order are unchanged.
            cloth = cloth.replacingOccurrences(of: "float a2=alpha*alpha;", with: """
            float a2=alpha*alpha;
            // daily3DFactoredBRDF
            float inverseViewSmith=1.0/(nv+sqrt(a2+(1.0-a2)*nv*nv));
            """)
            .replacingOccurrences(of: "float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));", with:
                "float smithVisibility=inverseViewSmith/(nl+sqrt(a2+(1.0-a2)*nl*nl));")
            .replacingOccurrences(of: "S+=weighted*visibility*D*G*F/(4.0*nv*nl);", with:
                "S+=weighted*visibility*D*F*smithVisibility;")
        }
        var shader = cloth.replacingOccurrences(of: "// SHADOW", with: "if(shadowPossible) {\n" + shadow + "\n}")
            .replacingOccurrences(of: "// NEAR_SHADOW", with: masked && mergesSupport ? mergedSupport : possible)
        if masked {
            let values = (0..<ballCount).map { "contactBall\($0)" }.joined(separator: ",")
            shader = shader.replacingOccurrences(of: "float3 p=contactWorld;", with: "float4 shadowBalls[\(ballCount)]={\(values)};\nfloat3 p=contactWorld;")
                .replacingOccurrences(of: "for(int panel=0;", with: (mergesSupport ? "" : mask + "\n") + "for(int panel=0;")
        }
        return samplingShader(shader, profile: previewSamplingProfile)
    }

    /// S1: sphere-cone/rectangle intersection integrated analytically along Z,
    /// then eight fixed Gauss-Legendre strips along X. No light-sample/ball loop.
    /// The fixed rig is horizontal and aligned with world X/Z (metres).
    static let analyticShadowFunctions = """
    float v2ShadowPrimitive(float z,float x,float height,float3 n) {
        float a=x*x+height*height;
        float j0=z/(2.0*a*(a+z*z))+atan(z*rsqrt(a))/(2.0*a*sqrt(a));
        float jz=-0.5/(a+z*z);
        return height*((n.x*x+n.y*height)*j0+n.z*jz);
    }
    float v2SphereBlocked(float3 p,float3 n,float4 ball,int panel,float fullIntegral) {
        if(ball.w<=0.0 || fullIntegral<=0.000001) return 0.0;
        float3 d=float3(ball.x,0.8+ball.z,ball.y)-p;
        float radius=0.028575, radius2=radius*radius;
        float height=v62EmitterCenter(panel).y-p.y;
        // Receivers above the sphere cannot be shadowed by an overhead emitter.
        if(d.y<=0.0 || d.y>=height || height<=0.0) return 0.0;
        float top=d.y+radius;
        if(height>top) {
            float bound=radius+top/(height-top)*(length(ball.xy)+\(rig.emitterRadius));
            if(dot(d.xz,d.xz)>bound*bound) return 0.0;
        }
        float k=dot(d,d)-radius2;
        if(k<=0.00000001) return min(1.0,ball.w/0.85);
        float x0=v62EmitterCenter(panel).x-length(v62EmitterU(panel))-p.x;
        float x1=v62EmitterCenter(panel).x+length(v62EmitterU(panel))-p.x;
        float z0=v62EmitterCenter(panel).z-length(v62EmitterV(panel))-p.z;
        float z1=v62EmitterCenter(panel).z+length(v62EmitterV(panel))-p.z;
        float den=d.y*d.y-radius2;
        if(den>0.00000001) {
            float extent=radius*sqrt(max(0.0,d.x*d.x+den));
            x0=max(x0,height*(d.y*d.x-extent)/den);
            x1=min(x1,height*(d.y*d.x+extent)/den);
        }
        if(x1<=x0) return 0.0;
        // Nodes/weights of the order-eight Legendre rule, not fitted opacity.
        const float nodes[8]={-0.9602898565,-0.7966664774,-0.5255324099,-0.1834346425,0.1834346425,0.5255324099,0.7966664774,0.9602898565};
        const float weights[8]={0.1012285363,0.2223810345,0.3137066459,0.3626837834,0.3626837834,0.3137066459,0.2223810345,0.1012285363};
        float blocked=0.0;
        for(int strip=0;strip<8;++strip) {
            float x=(x0+x1)*0.5+nodes[strip]*(x1-x0)*0.5;
            float a=d.z*d.z-k,b=2.0*d.z*(d.x*x+d.y*height);
            float c=pow(d.x*x+d.y*height,2.0)-k*(x*x+height*height);
            float lo=z0,hi=z1;
            if(abs(a)<0.00000001) {
                if(abs(b)<0.00000001) { if(c<0.0) continue; }
                else if(b>0.0) lo=max(lo,-c/b); else hi=min(hi,-c/b);
            } else if(a<0.0) {
                float disc=b*b-4.0*a*c;
                if(disc<=0.0) continue;
                float root=sqrt(disc);
                lo=max(lo,(-b+root)/(2.0*a));hi=min(hi,(-b-root)/(2.0*a));
            } else {
                // Non-bed receivers can intersect the upper sphere hemisphere.
                // Retain contact AO there; no bed-plane projection onto cushions.
                continue;
            }
            if(hi<=lo) continue;
            // Clip to positive N.L before integrating the perturbed cloth normal.
            if(abs(n.z)>0.000001) {
                float horizon=-(n.x*x+n.y*height)/n.z;
                if(n.z>0.0) lo=max(lo,horizon); else hi=min(hi,horizon);
            } else if(n.x*x+n.y*height<=0.0) continue;
            if(hi<=lo) continue;
            blocked+=weights[strip]*max(0.0,v2ShadowPrimitive(hi,x,height,n)-v2ShadowPrimitive(lo,x,height,n));
        }
        return clamp(blocked*(x1-x0)*0.5/fullIntegral,0.0,1.0)*min(1.0,ball.w/0.85);
    }
    """

    static func analyticDirectShadowShader(ballCount: Int) -> String {
        let reference = directShadowShader(ballCount: ballCount, specialized: false)
        guard let begin=reference.range(of:"float3 E=float3(0.0);"),
              let end=reference.range(of:"_surface.emission.rgb") else { return reference }
        // Reuse the output calibration, normals, contact uniforms and same-frame data.
        var output=reference
        let blockers=(0..<ballCount).map {
            "visibility *= 1.0-v2SphereBlocked(p,n,contactBall\($0),panel,fullIntegral);"
        }.joined(separator:"\n")
        let replacement=rig.shader("""
        // v2AnalyticShadow
        float3 E=float3(0.0),S=float3(0.0);
        float3 v=normalize(scn_frame.inverseViewTransform[3].xyz-p);
        float nv=max(0.001,dot(n,v));
        float alpha=max(0.01,_surface.roughness*_surface.roughness),a2=alpha*alpha;
        for(int panel=0;panel<{{PANEL_COUNT}};++panel) {
            float fullIntegral=v62RectIrradiance(p,n,panel),visibility=1.0;
            \(blockers)
            E+=float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*fullIntegral*v62EmitterGain(panel)*visibility;
            // Broad cloth BRDF retains the existing unshadowed 2x2 quadrature.
            // Visibility is separated: no per-light-sample blocker traversal.
            for(int ix=0;ix<2;++ix) for(int iz=0;iz<2;++iz) {
                float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(float(ix)-0.5)+v62EmitterV(panel)*(float(iz)-0.5);
                float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
                float nl=max(0.001,dot(n,l));float3 h=normalize(l+v);float nh=max(0.0,dot(n,h)),vh=max(0.0,dot(v,h));
                float denom=nh*nh*(a2-1.0)+1.0,D=a2/(3.14159265*denom*denom);
                float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
                float F=0.012+0.988*pow(1.0-vh,5.0);
                float3 weighted=float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*(v62EmitterArea(panel)*v62EmitterGain(panel)/4.0);
                S+=weighted*visibility*D*G*F/(4.0*nv*nl);
            }
        }
        """)
        output.replaceSubrange(begin.lowerBound..<end.lowerBound,with:replacement+"\n")
        // The reference prefix's array is no longer needed by the strip integrator.
        if let start=output.range(of:"float4 shadowBalls["),let stop=output.range(of:"float3 p=contactWorld;") {
            output.removeSubrange(start.lowerBound..<stop.lowerBound)
        }
        return output
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

    /// Generated constants, not per-material uniforms: keep older Metal binding budgets.
    static let emitterGeometry: String = {
        func vector(_ value: SIMD3<Double>) -> String { "float3(\(value.x),\(value.y),\(value.z))" }
        let panels = rig.panels
        var source = ""
        for (name, values) in [("Center", panels.map(\.center)), ("U", panels.map(\.u)),
                               ("V", panels.map(\.v)), ("Normal", panels.map(\.normal))] {
            source += "float3 v62Emitter\(name)(int i) { const float3 a[\(panels.count)]={"
                + values.map(vector).joined(separator: ",") + "}; return a[i]; }\n"
        }
        source += "float v62EmitterGain(int i) { const float a[\(panels.count)]={"
            + panels.map { String($0.gain) }.joined(separator: ",") + "}; return a[i]; }\n"
        source += "float v62EmitterArea(int i) { const float a[\(panels.count)]={"
            + panels.map { String($0.area) }.joined(separator: ",") + "}; return a[i]; }\n"
        return source
    }()

    // Exact projected solid angle of a horizon-clipped rectangular emitter.
    // Same radiance/geometry as the sampled reference; no shadow approximation changes.
    static let analyticPanelDiffuse = emitterGeometry + analyticDiffuseIntegral

    private static let analyticDiffuseIntegral = rig.shader("""
    float v62RectIrradiance(float3 p, float3 n, int panel) {
        float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
        if(dot(v62EmitterNormal(panel),-c)<=0.0) return 0.0;
        float3 v[4]={c-u-w,c-u+w,c+u+w,c+u-w};
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
        float total=0.0;
        for(int i=0;i<{{PANEL_COUNT}};++i) total+=v62RectIrradiance(p,n,i)*v62EmitterGain(i);
        return float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*total;
    }
    """)

    /// Cue varnish, pocket leather and ball finish. The training room is a
    /// separate scene-assembly step (`AngleTrainingScene.setupScene`).
    static func applySurfaceFinishes(to scene: AngleTrainingScene) {
        scene.cueStick?.rootNode.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] {
                if m.normal.contents is UIColor { m.normal.contents = nil }
                switch m.name ?? "" {
                case "copp" where scene.cueStick?.style != .original:
                    // Selected finishes own ferrule roughness; do not replace
                    // their texture when installing the room's surface finishes.
                    break
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
                TableSurfaceTextures.bindLeather(to: m)
                m.shaderModifiers = [.surface: leatherShader]
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
    for(int panel=0;panel<{{PANEL_COUNT}};panel++) {
        for(int ix=0;ix<4;ix++) for(int iz=0;iz<2;iz++) {
            float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/4.0-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/2.0-1.0);
            float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);float nl=max(0.001,dot(n,l));
            float3 h=normalize(l+v);float nh=max(0.0,dot(n,h));float vh=max(0.0,dot(v,h));
            float denom=nh*nh*(a2-1.0)+1.0;float D=a2/(3.14159265*denom*denom);
            float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
            float F=0.04+0.96*pow(1.0-vh,5.0);
            spec+=float3(1,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*(v62EmitterArea(panel)*v62EmitterGain(panel)/8.0)*D*G*F/(4.0*nv*nl);
        }
    }
    _surface.diffuse.rgb=_surface.diffuse.rgb*(v62PanelDiffuse(p,n)/3.14159265+0.26)*0.96+spec;
    """)

    private static let leatherShader = """
    #pragma arguments
    texture2d<float> leatherMicroNormal;
    texture2d<float> leatherMicroRoughness;
    #pragma declaration
    """ + "\n" + satinShader.replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + TableSurfaceTextures.leatherSampling)

    // Two by two quadrature points per panel, shared GGX model with satin;
    // 35% coating contribution avoids a polished white layer on dark wood.
    private static let woodCoatShader = """
    #pragma arguments
    texture2d<float> woodCoatRoughness;
    #pragma declaration
    """ + "\n" + satinShader
        .replacingOccurrences(of: "// v62SatinFinish", with: "// v64WoodCoat")
        .replacingOccurrences(of: "ix<4", with: "ix<2")
        .replacingOccurrences(of: "0.5)/4.0", with: "0.5)/2.0")
        .replacingOccurrences(of: "Gain(panel)/8.0", with: "Gain(panel)/4.0")
        .replacingOccurrences(of: "*0.96+spec;", with: "*0.986+0.35*spec;")
        .replacingOccurrences(of: "#pragma body", with: """
        #pragma body
        constexpr sampler woodSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
        _surface.roughness=woodCoatRoughness.sample(woodSampler,_surface.diffuseTexcoord).r;
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
        source.replaceSubrange(start.lowerBound..<end.lowerBound, with: analyticDiffuseIntegral + "\n")
        return source
    }()

    // Retained as the numerical/visual reference while validating GPU cost.
    static let sampledBallShader = emitterGeometry + rig.shader("""
    float v62worldIntegral(float x) { return max(0.0,((((((((((((-0.08636586539832361*x+0.03358324878023771)*x+0.1807681120541014)*x+-0.0901518898599715)*x+-0.1398822803391923)*x+0.08601738357243822)*x+0.03544987957333094)*x+-0.0342965481779107)*x+-0.026459309315669012)*x+0.0051020175297182765)*x+-0.10414811593646554)*x+0.12979997791360942)*x+0.27073602068087366)); }
    float v62bounceIntegral(float x) { return max(0.0,((((((((((((0.7391315655967717*x+-0.521674143216907)*x+-1.8109810807609321)*x+1.2213403850849287)*x+1.5632528571973532)*x+-0.909670480224779)*x+-0.7209205166011029)*x+0.4267268481308019)*x+-0.003853721433570013)*x+0.11345215688244002)*x+-0.2082655686807922)*x+-0.3286814509996016)*x+0.4405794885548977)); }
    float3 v62PanelDiffuse(float3 p, float3 n) {
        float3 E=float3(0.0);
        for (int panel=0; panel<{{PANEL_COUNT}}; ++panel) {
            for (int ix=0; ix<8; ++ix) {
                for (int iz=0; iz<4; ++iz) {
                    float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/8.0-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/4.0-1.0);
                    float3 delta=lp-p; float r2=dot(delta,delta); float3 l=delta/sqrt(r2);
                    E += float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*(v62EmitterArea(panel)*v62EmitterGain(panel)/32.0);
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
    for(int panel=0;panel<{{PANEL_COUNT}};++panel) {
        float3 pn=v62EmitterNormal(panel),u=v62EmitterU(panel),w=v62EmitterV(panel);
        float denominator=dot(pn,reflected);
        if(denominator>=-0.00001) continue;
        float distance=dot(pn,v62EmitterCenter(panel)-p)/denominator;
        if(distance<=0.0) continue;
        float3 hit=p+distance*reflected-v62EmitterCenter(panel);
        float x=dot(hit,normalize(u)),z=dot(hit,normalize(w));
        float width=clamp(fwidth(x),0.008,0.05),depth=clamp(fwidth(z),0.008,0.05);
        float mask=(1.0-smoothstep(length(u)-width,length(u)+width,abs(x)))
                  *(1.0-smoothstep(length(w)-depth,length(w)+depth,abs(z)));
        result+=float3(1.0,0.985,0.96)*({{RADIANCE}}/3.14159265)*mask*v62EmitterGain(panel);
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
    float3 E=float3(0.0);float3 unoccludedE=float3(0.0);float3 S=float3(0.0);
    float3 v=normalize(scn_frame.inverseViewTransform[3].xyz-p);
    float nv=max(0.001,dot(n,v));
    float alpha=max(0.01,_surface.roughness*_surface.roughness);
    float a2=alpha*alpha;
    // NEAR_SHADOW
    for(int panel=0;panel<{{PANEL_COUNT}};++panel) {
     // 64 samples near shadow, fixed grid with no temporal jitter.
     int samplesX=shadowPossible?8:2;
     int samplesZ=shadowPossible?4:2;
     float cellArea=v62EmitterArea(panel)/float(samplesX*samplesZ);
     float lightCellRadius=sqrt(cellArea/3.14159265);
     for(int ix=0;ix<samplesX;++ix) {
      for(int iz=0;iz<samplesZ;++iz) {
       float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/float(samplesZ)-1.0);
       float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);
       float visibility=1.0;
       // SHADOW
       float nl=max(0.001,dot(n,l));float3 h=normalize(l+v);float nh=max(0.0,dot(n,h));float vh=max(0.0,dot(v,h));
       float denom=nh*nh*(a2-1.0)+1.0;
       float D=a2/(3.14159265*denom*denom);
       float G=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
       float F=0.012+0.988*pow(1.0-vh,5.0);
       float3 weighted=float3(1,0.985,0.96)*({{RADIANCE}}/3.14159265)*max(0.0,dot(n,l))*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel);
       unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);
      }
     }
    }
    E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));
    // v64ClothNap: weak albedo-coloured grazing response; shadow/AO stay multiplicative.
    _surface.emission.rgb = (_surface.diffuse.rgb * _surface.multiply.rgb) * (1.0+0.10*pow(1.0-clamp(abs(dot(normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz),v)),0.0,1.0),3.0)) * (E/3.14159265+0.26*_surface.ambientOcclusion)+0.35*S+0.35*float3(max(0.0,((((((((((-0.028803310033256934*nv+0.18720610088795223)*nv+-0.5502767636063797)*nv+0.9752880522825459)*nv+-1.17736218879761)*nv+1.0399023440946362)*nv+-0.6934645105632581)*nv+0.32180425209794744)*nv+-0.053736086147546894)*nv+-0.0426628106982577)*nv+0.023864333781715107)));
    _surface.diffuse.rgb=float3(0.0);
    _surface.metalness=1.0;

    _surface.multiply.rgb=float3(1.0);
    """)
}


#if DEBUG
extension MobileReferenceLighting {
    /// Visual-validation prototype only. Scene-local opt-in; unsupported assets retain PBR.
    static func applyClothLightingPrototype(to material: SCNMaterial) throws {
        func invalid(_ message: String) -> NSError {
            NSError(domain: "DailyClothPrototype", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard let device = MTLCreateSystemDefaultDevice(),
              let url = material.roughness.contents as? URL, url.isFileURL,
              let source = material.shaderModifiers?[.surface],
              source.contains("#pragma arguments"), source.contains("#pragma body"),
              material.roughness.mappingChannel == material.diffuse.mappingChannel else {
            throw invalid("Unsupported roughness binding or shader")
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let bytes: Data
        if !query.isEmpty {
            guard let offsetText = query.first(where: { $0.name == "offset" })?.value,
                  let countText = query.first(where: { $0.name == "size" })?.value,
                  let offset = UInt64(offsetText), let count = Int(countText), count > 0, count <= 32 * 1024 * 1024 else {
                throw invalid("Unsupported embedded image range")
            }
            let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: url.path))
            defer { try? file.close() }
            let length = try file.seekToEnd()
            guard offset <= length, UInt64(count) <= length - offset else { throw invalid("Invalid embedded image range") }
            try file.seek(toOffset: offset)
            guard let data = try file.read(upToCount: count), data.count == count else { throw invalid("Incomplete embedded image") }
            bytes = data
        } else { bytes = try Data(contentsOf: url) }
        guard let image = UIImage(data: bytes)?.cgImage else { throw invalid("Roughness image decode failed") }
        let texture = try MTKTextureLoader(device: device).newTexture(cgImage: image,
            options: [.SRGB: false, .generateMipmaps: true])
        let property = SCNMaterialProperty(contents: texture)
        property.mipFilter = .linear; property.minificationFilter = .linear; property.magnificationFilter = .linear
        property.maxAnisotropy = material.roughness.maxAnisotropy
        var modifiers = material.shaderModifiers ?? [:]
        modifiers[.surface] = source
            .replacingOccurrences(of: "#pragma arguments", with: "#pragma arguments\ntexture2d<float> clothRoughness;\nfloat4x4 clothRoughnessTransform;\nfloat clothRoughnessIntensity;")
            .replacingOccurrences(of: "#pragma body", with: """
            #pragma body
            constexpr sampler clothSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
            float2 clothUV = (clothRoughnessTransform * float4(_surface.diffuseTexcoord,0.0,1.0)).xy;
            _surface.roughness = clothRoughness.sample(clothSampler,clothUV).r * clothRoughnessIntensity;
            """)
        modifiers[.fragment] = "#pragma body\n_output.color.rgb = _surface.emission.rgb;"
        material.setValue(property, forKey: "clothRoughness")
        material.setValue(NSValue(scnMatrix4: material.roughness.contentsTransform), forKey: "clothRoughnessTransform")
        material.setValue(material.roughness.intensity, forKey: "clothRoughnessIntensity")
        material.shaderModifiers = modifiers
        material.lightingModel = .constant
    }
}
#endif
