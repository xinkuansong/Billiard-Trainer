"""Read actual shader inputs at R3 failing pixels; no performance ranking."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess


def main():
    p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--evidence',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[3];package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    native=(a.reference/'main.swift').read_text();prefix=native[:native.index('var results=[[String:Any]]()')];shim=native[native.index('final class AngleTrainingScene'):]
    suffix=r'''
for (pose,frame,rough) in [("single-low",15,0.68),("single-near",12,0.39),("scatter-overview",13,0.4),("scatter-overview",14,0.5)] {
 let s=try makeScene(package),target=try Target(s.renderer,maxWidth,maxWidth*4/7)
 for m in s.mats {field.install(on:m);m.roughness.contents=Float(rough)}
 _=input(s,pose,frame)
 var inspection=[MTLTexture]()
 for index in 0..<2 {
  let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:target.w,height:target.h,mipmapped:false)
  d.storageMode = .shared;d.usage=[.shaderRead,.shaderWrite]
  let t=try unwrap(device.makeTexture(descriptor:d),"Inspection texture")
  let zero=Data(count:target.w*target.h*16)
  zero.withUnsafeBytes{t.replace(region:MTLRegionMake2D(0,0,target.w,target.h),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:target.w*16)}
  inspection.append(t)
  for m in s.mats {m.setValue(SCNMaterialProperty(contents:t),forKey:"h18Inspect\(index)")}
 }
 var capture=baseline
 let args=capture.range(of:"#pragma arguments")!
 capture.insert(contentsOf:"\ntexture2d<float,access::write> h18Inspect0;\ntexture2d<float,access::write> h18Inspect1;",at:args.upperBound)
 capture=try once(capture,"// v64ClothNap:","""
 float4 h18Clip=scn_frame.projectionTransform*float4(_surface.position,1.0);
 uint2 h18Pixel=uint2((h18Clip.xy/h18Clip.w*float2(0.5,-0.5)+0.5)*float2(\(target.w),\(target.h)));
 if(all(h18Pixel<uint2(\(target.w),\(target.h)))){
  h18Inspect0.write(float4(n,_surface.roughness),h18Pixel);
  h18Inspect1.write(float4(p,shadowPossible?1.0:0.0),h18Pixel);
 }
 // v64ClothNap:
 """)
 install(s,capture);_=try target.batch(3)
 for index in 0..<2 {
  var bytes=Data(count:target.w*target.h*16)
  bytes.withUnsafeMutableBytes{inspection[index].getBytes($0.baseAddress!,bytesPerRow:target.w*16,from:MTLRegionMake2D(0,0,target.w,target.h),mipmapLevel:0)}
  try bytes.write(to:output.appendingPathComponent("\(pose)-\(frame)-input\(index).f32"))
 }
}
'''
    source=prefix+suffix+'\n'+shim
    for d in [a.work,a.evidence]:
        d.mkdir(parents=True,exist_ok=True);(d/'inspect.swift').write_text(source)
        shutil.copy2(a.reference/'StaticClothIrradiance.swift',d)
    (a.work/'main.swift').write_text(source)
    for name in ['fit.json','ltc0.f32','ltc1.f32','ltc.metal']:shutil.copy2(a.reference/name,a.evidence/name)
    with (a.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(a.work/'StaticClothIrradiance.swift'),str(a.work/'main.swift'),'-o',str(a.work/'probe')],stdout=log,stderr=subprocess.STDOUT,check=True)
    with (a.evidence/'render.log').open('w') as log:
        subprocess.run([str(a.work/'probe'),str(package),str(a.evidence),'700','120'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=140)
    report=[]
    for pose,frame,setting in [('single-low',15,.68),('single-near',12,.39),('scatter-overview',13,.4),('scatter-overview',14,.5)]:
        name=f'{pose}-integral-true-{frame}'
        aa=(a.reference/f'{name}-A.bgra8').read_bytes();bb=(a.reference/f'{name}-B.bgra8').read_bytes()
        n=(a.evidence/f'{pose}-{frame}-input0.f32').read_bytes();q=(a.evidence/f'{pose}-{frame}-input1.f32').read_bytes()
        delta=[max(abs(aa[i+c]-bb[i+c]) for c in range(3)) for i in range(0,len(aa),4)]
        maximum=max(delta);pixels=[i for i,x in enumerate(delta) if x==maximum]
        report.append({'pose':pose,'frame':frame,'materialContents':setting,'maximum':maximum,'pixelCount':len(pixels),
                       'samples':[{'xy':[i%700,i//700],'normalRoughness':struct.unpack_from('4f',n,i*16),'positionNear':struct.unpack_from('4f',q,i*16)} for i in pixels[:64]]})
    (a.evidence/'inputs.json').write_text(json.dumps(report,indent=2)+'\n')
    (a.evidence/'source.json').write_text(json.dumps({'reference':str(a.reference),'referenceSwiftSHA':hashlib.sha256(native.encode()).hexdigest(),'probeSHA':hashlib.sha256(source.encode()).hexdigest()},indent=2)+'\n')
    print(a.evidence/'inputs.json')


if __name__=='__main__':main()
