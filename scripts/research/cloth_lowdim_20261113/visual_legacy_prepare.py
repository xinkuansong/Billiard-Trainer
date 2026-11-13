#!/usr/bin/env python3
"""Restore a validated math core to the frozen complete SceneKit cloth material.

Inverse binding mapping must reconstruct the original cloth byte-for-byte before
any candidate is accepted. Only helper pointer address space is adapted from a
Metal constant input buffer to the surface's local thread shadowBalls array.
"""
from pathlib import Path
import argparse,hashlib,json,shutil


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def one(s,a,b):
    if s.count(a)!=1:raise ValueError(('anchor drift',a[:80],s.count(a)))
    return s.replace(a,b)


def function(source,name,end):
    start=source.index('inline Result '+name+'(')
    return source[start:source.index(end,start)]


def unmap(core,tail):
    body=core.split('{\n',1)[1]
    body=body[:body.index('\n    return {float4(unoccludedE')]
    body=one(body,'float3 p=input.position.xyz;','float3 p=contactWorld;')
    body=one(body,'normalize(input.normal.xyz)','normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz)')
    body=one(body,'normalize(input.view.xyz)','normalize(scn_frame.inverseViewTransform[3].xyz-p)')
    body=body.replace('input.view.w','_surface.roughness')
    for i in range(16):body=body.replace(f'balls[{i}]',f'contactBall{i}')
    body=one(body,'float3 sampledE=E;\n    E=v62PanelDiffuse','E=v62PanelDiffuse')
    body=body.replace('legacyConeDomain(p,balls)','legacyConeDomain(p,shadowBalls)')
    if 'input.' in body:raise ValueError('Unmapped explicit input')
    return body+tail


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--base',type=Path,required=True);ap.add_argument('--reference',type=Path,required=True);ap.add_argument('--candidate',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
    base=args.base.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    original=args.reference.read_text();candidate=args.candidate.read_text();cloth=(base/'cloth-core.surface').read_text();prefix=(base/'contact-prefix.surface').read_text();tail=cloth[cloth.index('// v64ClothNap:'):]
    ref=function(original,'referenceAt','inline float groupBRDF(')
    if unmap(ref,tail)!=cloth:raise ValueError('Inverse mapping does not reproduce frozen cloth byte-for-byte')
    if not candidate.startswith(original):raise ValueError('Candidate reference is not frozen original')
    start=candidate.index('inline Result heightSupportAt(');helpers=candidate[len(original):start]
    helpers=one(helpers,'float3 p,constant float4 *balls)','float3 p,thread const float4 *balls)')
    trial=unmap(function(candidate,'heightSupportAt','\nkernel void evaluateHeightSupport('),tail)
    modified_prefix=one(prefix,'#pragma body',helpers+'\n#pragma body')
    surface=modified_prefix+'\n'+trial
    for name in ['reference.surface','contact-prefix.surface','cloth-core.surface','normal.surface','reference-environment.hdr','harness.swift','render']:
        shutil.copy2(base/name,out/name)
    if (out/'reference.surface').read_text()!=prefix+'\n'+cloth:raise ValueError('Frozen surface mismatch')
    (out/'height-safe.surface').write_text(surface)
    active='+'.join(f'int(contactBall{i}.w>0.0)' for i in range(16))
    diagnostic=f'\nint sourceMaskCount=p.y<0.8?({active}):int(popcount(shadowMask));\n_surface.emission.rgb=(shadowPossible && (!diagnosticGlobalQuality || sourceMaskCount>int(popcount(shadowMask))))?float3(0,1,0):float3(1,0,0);'
    (out/'height-safe-coverage.surface').write_text(surface+diagnostic)
    manifest=json.loads((base/'shader-manifest.json').read_text())
    manifest['support_mask']={'mode':'legacy-domain-plus-safe-hoisted','source':str(args.candidate.resolve()),'sha256':sha(args.candidate),'reference_sha256':sha(args.reference),'surface_sha256':sha(out/'height-safe.surface'),'full_reference_surface_sha256':sha(out/'reference.surface'),'inverseReferenceMappingByteIdentical':True,'prepare_sha256':sha(Path(__file__)),'transforms':['Restore original SceneKit position/normal/view/roughness/uniform bindings','Restore complete original cloth emission tail','Only legacyConeDomain pointer address space constant->thread for local shadowBalls array','Preserve contact prefix, native PBR/material/geometry/fragment/HDR exactly from visual-r4'],'domain':'near only; p raw Y sign nonnegative, y0..0.9, absXZ<=2.54/1.27; all active balls sameXZ and hR..2.2; otherwise restore original mask and original shadow loop using one transport/BRDF path','far_mask_diagnostic':'zero'}
    manifest['candidate_description']='Guarded historical two-lamp cone classifier plus current safe-hoisted per-ball mask; original near64/far8, visibility filter, sample order, BRDF, global two-lamp diffuse normalization and complete material composition preserved. Outside declared cone domain restore original mask/shadow evaluation. No duplicate fallback transport path.'
    manifest['frozen_visual_base']=str(base)
    (out/'shader-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(args.candidate,out/'candidate-core.metal');shutil.copy2(Path(__file__),out/'visual_legacy_prepare.py')
    print(json.dumps(manifest['support_mask'],indent=2))


if __name__=='__main__':main()
