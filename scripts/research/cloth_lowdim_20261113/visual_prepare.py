"""Export the actual production contact prefix + R cloth surface for a macOS scene.

Candidate computes moments inside the fragment, so its timing is NOT a cache
performance result. It isolates representation error with real texture sampling.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,re
ROOT=Path(__file__).resolve().parents[3]
def one(s,old,new):
    if s.count(old)!=1:raise ValueError((old,s.count(old)))
    return s.replace(old,new)
def section(s,a,b):return s[s.index(a):s.index(b,s.index(a))]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--reference',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--support-mask',type=Path);ap.add_argument('--support-mode',choices=['safe','safe-near-first'],default='safe');a=ap.parse_args()
    a.out.mkdir(parents=True,exist_ok=True)
    lighting=(ROOT/'QiuJi/Core/Scene/MobileReferenceLighting.swift').read_text()
    contact=(ROOT/'QiuJi/Core/Scene/MobileTableRendering.swift').read_text()
    generator=(a.reference/'generator.swift').read_text().split('let rig = ExportedLighting.rig')[0]
    uniform=section(contact,'    static func uniformDeclarations(', '\n    init(scene:')
    contactbody=section(contact,'        var shader = "#pragma arguments','        var targets: [SCNMaterial]')
    contactbody=one(contactbody,'let railTexture = MobileTableRendering.railOcclusion','let railTexture: Int? = 1')
    env=section(lighting,'    static let environment: Data = {','    /// Shader template')
    env=one(env,'    static let environment: Data','let environment: Data')
    swift=generator+'\nlet rig=ExportedLighting.rig\n'+env+'\nenum MobileContactOcclusion {\n'+uniform+'}\nenum AngleSceneCalculator {static let innerLength:Float=2.54;static let innerWidth:Float=1.27}\nfunc contactPrefix()->String {\nlet balls=Array(0..<16);let batchesUniforms=true;let radius:Float=0.028575;let surfaceY:Float=0.8\n'+contactbody.replace('Self.uniformDeclarations','MobileContactOcclusion.uniformDeclarations')+'\nreturn shader\n}\n'
    swift+='''let out=URL(fileURLWithPath:CommandLine.arguments[1])
var prefix=contactPrefix()
for i in 0..<16 {prefix=prefix.replacingOccurrences(of:"contactVisibility *= 1.0 - contactBall\\(i).w *",with:"contactVisibility *= 1.0 - (contactBall\\(i).w / 0.85) *")}
prefix=prefix.replacingOccurrences(of:"#pragma body",with:"#pragma declaration\\n"+ExportedLighting.analyticPanelDiffuse+"\\n#pragma body")
let core=ExportedLighting.directShadowShader(ballCount:16,profile:.reflection)
try (prefix+"\\n"+core).write(to:out.appendingPathComponent("reference.surface"),atomically:true,encoding:.utf8)
try prefix.write(to:out.appendingPathComponent("contact-prefix.surface"),atomically:true,encoding:.utf8)
try core.write(to:out.appendingPathComponent("cloth-core.surface"),atomically:true,encoding:.utf8)
try environment.write(to:out.appendingPathComponent("reference-environment.hdr"))
'''
    (a.out/'export.swift').write_text(swift)
    proc=subprocess.run(['xcrun','swift',str(a.out/'export.swift'),str(a.out)],cwd=ROOT,capture_output=True,text=True)
    (a.out/'export.log').write_text(proc.stdout+proc.stderr)
    if proc.returncode:raise RuntimeError(proc.stderr)
    core=(a.out/'cloth-core.surface').read_text();prefix=(a.out/'contact-prefix.surface').read_text()
    # K=8 per emitter: four X bins, two Z bins; 4 original samples in each.
    start='float3 E=float3(0.0);float3 unoccludedE=float3(0.0);float3 S=float3(0.0);'
    core=one(core,start,start+'\nfloat3 moments[16];for(int q=0;q<16;q++) moments[q]=float3(0);\nbool momentValid=true;\nfor(int ax=0;ax<2;ax++)for(int az=0;az<3;az++){float3 corner=v62EmitterCenter(az==2?1:0)+(ax==0?-1.0:1.0)*v62EmitterU(0)+(az==0?-1.0:1.0)*v62EmitterV(0);momentValid=momentValid&&dot(n,corner-p)>=0.0;}\n'.replace('2.540000:?2.540000','2.540000:2.540000'))
    core=one(core,'for(int panel=0;panel<2;++panel) {','bool useMoments=momentValid&&shadowPossible;\nfor(int panel=0;panel<2;++panel) {')
    brdf=section(core,'float nl=max(0.001,dot(n,l));','float3 weighted=')
    core=one(core,brdf,'')
    accum='unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);'
    # Divide RGB weighted by nl? Avoid it: the unprojected scalar is generated directly.
    rig=json.loads((a.reference/'generated-production-core.json').read_text())['rig'];radiance=rig['radiance']
    replacement='''unoccludedE+=weighted; E+=weighted*visibility;
if(useMoments) {
 int group=panel*8+(ix/2)*2+(iz/2);
 float a=RADIANCE/3.14159265*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel);
 moments[group]+=a*visibility*l;
} else { BRDF S+=weighted*visibility*D*G*F/(4.0*nv*nl); }
'''.replace('RADIANCE',repr(radiance)).replace('BRDF',brdf)
    core=one(core,accum,replacement)
    marker='E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));'
    consume='''if(useMoments) { for(int g=0;g<16;g++) {
 float3 m=moments[g];float len2=dot(m,m);if(len2>0.0){float3 l=m/sqrt(len2);
 BRDF
 S+=float3(1.0,0.985,0.96)*max(0.0,dot(n,m))*D*G*F/(4.0*nv*nl);
 }}}
'''.replace('BRDF',brdf)
    core=one(core,marker,consume+marker)
    k8core=core
    for k,nx,nz in [(2,2,1),(4,2,2),(8,4,2)]:
        candidate=k8core.replace('float3 moments[16];for(int q=0;q<16;q++)','float3 moments[%d];for(int q=0;q<%d;q++)'%(2*k,2*k))
        candidate=candidate.replace('panel*8+(ix/2)*2+(iz/2)','panel*%d+(ix/%d)*%d+(iz/%d)'%(k,8//nx,nz,4//nz))
        candidate=candidate.replace('for(int g=0;g<16;g++)','for(int g=0;g<%d;g++)'%(2*k))
        (a.out/f'candidate-k{k}.surface').write_text(prefix+'\n'+candidate)
    (a.out/'candidate-coverage.surface').write_text(prefix+'\n'+k8core+'\n_surface.emission.rgb=useMoments?float3(0,1,0):float3(1,0,0);')
    # Encode the actual SceneKit world normal, with output transforms explicitly disabled by the harness.
    normal=prefix+'\n'+(a.out/'cloth-core.surface').read_text()+'\n_surface.emission.rgb=0.5+0.5*n;'
    (a.out/'normal.surface').write_text(normal)
    if a.support_mask:
        helper=a.support_mask.read_text()
        ref=(a.out/'reference.surface').read_text()
        support=one(ref,'#pragma body',helper+'\n#pragma body')
        pattern=r'if\(p.y<0.8 \|\| top>=2.2 \|\| dot\(offset,offset\)<=bound\*bound\) shadowMask \|= \(1u<<(\d+)\);'
        support,count=re.subn(pattern,lambda m:'if((p.y<0.8 && height_safe_below_mask(p,contactBall'+m[1]+')) || top>=2.2 || dot(offset,offset)<=bound*bound) shadowMask |= (1u<<'+m[1]+');',support)
        if count!=16:raise ValueError(('Expected 16 mask terms',count))
        if a.support_mode=='safe-near-first':
            for i in range(16):
                old=f'if((p.y<0.8 && height_safe_below_mask(p,contactBall{i})) || top>=2.2 || dot(offset,offset)<=bound*bound)'
                new=f'if(top>=2.2 || dot(offset,offset)<=bound*bound || (p.y<0.8 && height_safe_below_mask(p,contactBall{i})))'
                support=one(support,old,new)
            support=one(support,'uint shadowMask=0u;','uint shadowMask=0u;\nif(shadowPossible) {')
            support=one(support,'for(int panel=0;panel<2;++panel) {','}\nfor(int panel=0;panel<2;++panel) {')
        (a.out/'height-safe.surface').write_text(support)
        active='+'.join(f'int(contactBall{i}.w>0.0)' for i in range(16))
        diagnostic=f'\nint sourceMaskCount=p.y<0.8?({active}):int(popcount(shadowMask));\n_surface.emission.rgb=(shadowPossible && sourceMaskCount>int(popcount(shadowMask)))?float3(0,1,0):float3(1,0,0);'
        (a.out/'height-safe-coverage.surface').write_text(support+diagnostic)
    manifest={'scope':'Real USDZ TaiNi material and production shader core/prefix, isolated macOS SceneKit scene; not complete App',
      'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'QiuJi/Core/Scene/MobileReferenceLighting.swift',ROOT/'QiuJi/Core/Scene/MobileTableRendering.swift',ROOT/'QiuJi/Core/Scene/MaterialFactory.swift',ROOT/'QiuJi/Core/Scene/AngleTrainingScene.swift',ROOT/'QiuJi/Core/Scene/TableModelLoader.swift',ROOT/'QiuJi/Core/Scene/MobileClothAlignment.swift',ROOT/'QiuJi/Core/Scene/PocketLeatherMesh.swift']},
      'generator_source_sha256':hashlib.sha256(generator.encode()).hexdigest(),'reference':str(a.reference),
      'candidate':'K2/4/8 per lamp; generate moments per fragment then 4/8/16 BRDF evaluations; diffuse retains original sum; corner hemisphere guard; exact far/guard fallback; no spatial interpolation or cache',
      'material_overrides':{'normalIntensity':.65,'source':'MaterialFactory.enhanceClothMaterials preservesClothResponse true','multiplySRGB':[.54,.73,.54],'diffuseSRGB':[48/255,155/255,32/255],'geometry_alignment':'Full MobileClothAlignment.swift plus production PocketLeatherMesh.decode; macOS SCNVector3 CGFloat-to-Float conversion only; preserve geometry modifier when swapping surface','normal_roughness_uv_scale':[2,2,1],'wrap':'repeat','lightingModel':'physicallyBased'},
      'limits':['No baked room or R ball reflection in first isolated scene','Diagnostic sphere geometry marks occluders; other table materials are imported USDZ','No performance claim for in-fragment moments','Final normal diagnostic uses SceneKit actual texture/mesh tangent, unlike raw texture basis study']}
    if a.support_mask:manifest['support_mask']={'path':str(a.support_mask),'sha256':hashlib.sha256(a.support_mask.read_bytes()).hexdigest(),'mode':a.support_mode,'far_mask_diagnostic':('0 because unused mask construction is skipped' if a.support_mode=='safe-near-first' else 'same construction as source, with below-bed narrowing'),'prepare_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scope':'only unconditional below-bed mask OR term replaced; original inSupport retained; no sample, BRDF, color, geometry change'}
    (a.out/'shader-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    alignment=(ROOT/'QiuJi/Core/Scene/MobileClothAlignment.swift').read_text()
    alignment=alignment.replace('points.map(\\.y).min()', 'points.map { Float($0.y) }.min()').replace('points.map(\\.y).max()', 'points.map { Float($0.y) }.max()')
    meshSource=(ROOT/'QiuJi/Core/Scene/PocketLeatherMesh.swift').read_text()
    mesh='\nimport SceneKit\nenum PocketLeatherMesh { enum Failure:Error {case invalidMesh(String)}\n'+section(meshSource,'    static func decode(', '    static func makeElement(')+'\n}\n'
    shim='\nfinal class AngleTrainingScene { let rootNode:SCNNode;let tableNode:SCNNode?;let surfaceY:Float=0.8;init(scene:SCNScene,table:SCNNode){rootNode=scene.rootNode;tableNode=table} }\nenum AngleSceneCalculator { static let ballRadius:Float=0.028575 }\n'
    harness=(ROOT/'scripts/research/cloth_lowdim_20261113/visual_render.swift').read_text()+shim+alignment+mesh
    (a.out/'harness.swift').write_text(harness)
    build=subprocess.run(['xcrun','swiftc','-O',str(a.out/'harness.swift'),'-o',str(a.out/'render')],cwd=ROOT,capture_output=True,text=True)
    (a.out/'build.log').write_text(build.stdout+build.stderr)
    if build.returncode:raise RuntimeError(build.stderr)
    print(a.out)
if __name__=='__main__':main()
