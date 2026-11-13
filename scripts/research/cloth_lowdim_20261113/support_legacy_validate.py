#!/usr/bin/env python3
"""Frozen legacy cone domain guard and independent native validation-only runner.

Uses the existing 39 frozen pressure fixtures plus the explicit cone cancellation
witness. No production source or shared benchmark scripts are modified. Pressure
dispatches are never performance evidence; output bit contracts are strict.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
DOMAIN = '''
// Research eligibility for the archived cone, not a universal scene guarantee.
inline bool legacyConeDomain(float3 p,constant float4 *balls) {
    if((as_type<uint>(p.y)&0x80000000u)!=0u) return false;
    if(!(p.y>=0.0 && p.y<=0.9 && abs(p.x)<=2.5399999618530273
         && abs(p.z)<=1.2699999809265137)) return false;
    for(int i=0;i<16;++i) {
        float4 b=balls[i];
        if(b.w>0.0 && !(abs(b.x)<=2.5399999618530273 && abs(b.y)<=1.2699999809265137
                       && b.z>=0.028575 && b.z<=2.2)) return false;
    }
    return true;
}
'''


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data): path.write_text(json.dumps(data, indent=2) + '\n')


def domain_rows(samples, balls):
    p=samples[:,:3]
    valid=(~np.signbit(p[:,1])) & (p[:,1]>=0) & (p[:,1]<=np.float32(.9)) & (abs(p[:,0])<=np.float32(2.54)) & (abs(p[:,2])<=np.float32(1.27))
    active=balls[balls[:,3]>0]
    all_balls=np.all((abs(active[:,0])<=np.float32(2.54)) & (abs(active[:,1])<=np.float32(1.27)) & (active[:,2]>=np.float32(.028575)) & (active[:,2]<=np.float32(2.2)))
    return valid & all_balls


def prepare(legacy, out):
    out.mkdir(parents=True,exist_ok=False)
    variants=[]
    for name, far_zero in [('legacy',False),('legacy-plus-safe-hoisted',True)]:
        raw=legacy/name/'height-support.metal'
        variants.append({'name':name,'kernel':str(raw.resolve()),'guarded':False,'farMaskZero':far_zero})
        folder=out/(name+'-domain');folder.mkdir()
        source=raw.read_text();start=source.index('inline Result heightSupportAt(')
        before,body=source[:start],source[start:]
        marker='uint shadowMask=0u;'
        assert body.count(marker)==1
        # The near selector is already final at this point. Far paths therefore
        # retain their exact original arithmetic and avoid 16 extra ball checks.
        eligibility='bool diagnosticConeEligible=!shadowPossible || legacyConeDomain(p,balls);\n'
        body=body.replace(marker,eligibility+marker)
        assert body.count('bool diagnosticGlobalQuality=false;')==1
        body=body.replace('bool diagnosticGlobalQuality=false;',
                          'bool diagnosticGlobalQuality=shadowPossible && !diagnosticConeEligible;')
        gate='if(shadowPossible) {\n    float3 diagnosticLight='
        assert body.count(gate)==1
        body=body.replace(gate,'if(shadowPossible && diagnosticConeEligible) {\n    float3 diagnosticLight=')
        if far_zero:
            # Outside the cone's declared domain, restore original below-bed
            # all-active mask as well. Keep a single transport/BRDF code path.
            mask_gate='(!receiverCanPrune || height_safe_ball_mask('
            assert body.count(mask_gate)==16
            body=body.replace(mask_gate,'(!diagnosticConeEligible || !receiverCanPrune || height_safe_ball_mask(')
        kernel=folder/'height-support.metal';kernel.write_text(before+DOMAIN+body)
        variants.append({'name':name+'-domain','kernel':str(kernel.resolve()),'guarded':True,'farMaskZero':far_zero})
        write(folder/'source-manifest.json',{'origin':str(raw),'originSHA256':sha(raw),'kernelSHA256':sha(kernel),'domain':DOMAIN,'behavior':'Only original near=true checks eligibility. Ineligible near receivers restore original mask and force original shadow evaluation via the same unique transport/BRDF code path. Far has original8 samples and original variant diagnostic-mask contract. No coordinate snapping or source sample change.','supersedes':'r1 return-referenceAt guard rejected because fastMath=true changed rounding even on empty far inputs','status':'Prepared; native acceptance pending'})
    source=(HERE/'support_height_evaluate.swift').read_text()
    # Keep both exact diagnostic kernels/readbacks/metrics. Continue failed
    # numeric cases so all fixtures can be recorded; Python enforces acceptance.
    source=source[:source.index('guard changedChannels == 0, nearExact, maskSubset else {')]
    source+='\nprint("Validation-only dispatch complete; strict acceptance enforced by driver")\n'
    for fast in [False,True]:
        folder=out/('fast' if fast else 'strict');folder.mkdir()
        swift=folder/'validate.swift';swift.write_text(source.replace('options.fastMathEnabled = false',f'options.fastMathEnabled = {str(fast).lower()}'))
        result=subprocess.run(['xcrun','swiftc','-O',str(swift),'-o',str(folder/'validate')],capture_output=True,text=True)
        (folder/'build.log').write_text(result.stdout+result.stderr)
        if result.returncode:raise RuntimeError(result.stderr)
    write(out/'manifest.json',{'scope':__doc__,'variants':variants,'driverSHA256':sha(Path(__file__)),'evaluatorOrigin':str(HERE/'support_height_evaluate.swift'),'evaluatorOriginSHA256':sha(HERE/'support_height_evaluate.swift'),'evaluatorTransforms':['Retain through native validation.json creation','Remove native throw and all timing; Python evaluates same strict numeric contract and continues recording failures','Separate fastMath=false and true binaries'],'domain':DOMAIN,'nativeValidationOnly':True})
    shutil.copyfile(__file__,out/'support_legacy_validate.py')
    return variants


def run(out, fixtures):
    manifest=json.loads((out/'manifest.json').read_text());variants=manifest['variants']
    prior=json.loads((fixtures/'results.json').read_text());names=[r['case'] for r in prior['rows']]
    assert len(names)==39 and len(set(names))==39
    shared=out/'inputs';shared.mkdir()
    for name in names:
        folder=shared/name;folder.mkdir()
        for file in ['samples.bin','balls.bin']:shutil.copyfile(fixtures/name/file,folder/file)
    name='legacy-cone-cancellation-witness';names.append(name);folder=shared/name;folder.mkdir()
    samples=np.zeros((3,12),'<f4');p=np.array([0,-100000,0],np.float32)
    samples[:,:3]=[p,np.nextafter(p,np.full(3,-np.inf,np.float32)),np.nextafter(p,np.full(3,np.inf,np.float32))]
    samples[:,5]=1;samples[:,8:11]=[.2,.9,.4];samples[:,11]=.8
    balls=np.zeros((16,4),'<f4');balls[0]=[10,0,1,.85]
    samples.tofile(folder/'samples.bin');balls.tofile(folder/'balls.bin')
    input_manifest={name:{f:sha(shared/name/f) for f in ['samples.bin','balls.bin']} for name in names}
    write(out/'input-manifest.json',{'source':str(fixtures),'sourceManifestSHA256':sha(fixtures/'manifest.json'),'cases':input_manifest,'reusedCases':39,'uniqueSourceDatasetsNote':'Original26 configurations use13 datasets; do not count these as26 independent random sets.','extraCases':1})
    rows=[];radiometric=[0,1,2,4,5,6,8,9,10,12,13,14]
    for fast in [False,True]:
        mode='fast' if fast else 'strict';binary=out/mode/'validate'
        for variant in variants:
            group=out/mode/variant['name'];group.mkdir()
            failed=[]
            for name in names:
                src=shared/name;folder=group/name;folder.mkdir()
                proc=subprocess.run([str(binary),variant['kernel'],str(src/'samples.bin'),str(src/'balls.bin'),str(folder/'gpu'),'1'],capture_output=True,text=True)
                (folder/'run.log').write_text(proc.stdout+proc.stderr)
                row={'fastMath':fast,'variant':variant['name'],'case':name,'exitCode':proc.returncode,'passed':False}
                if proc.returncode==0:
                    ref=np.fromfile(folder/'gpu/reference.bin','<f4').reshape(-1,16);cand=np.fromfile(folder/'gpu/height.bin','<f4').reshape(-1,16)
                    samples=np.fromfile(src/'samples.bin','<f4').reshape(-1,12);balls=np.fromfile(src/'balls.bin','<f4').reshape(16,4)
                    rb=ref.view(np.uint32);cb=cand.view(np.uint32);near=ref[:,3]!=0;far=~near;outside=~domain_rows(samples,balls)
                    expected=rb.copy()
                    if variant['farMaskZero']:expected[far,7]=0
                    radiometric_changes=int((rb[:,radiometric]!=cb[:,radiometric]).sum());near_exact=bool((rb[:,3]==cb[:,3]).all())
                    rm=ref[:,7].astype(np.uint32);cm=cand[:,7].astype(np.uint32);subset=bool(((cm & ~rm)==0).all())
                    fallback_exact=bool((expected[outside]==cb[outside]).all()) if variant['guarded'] else None
                    far_exact=bool((expected[far]==cb[far]).all());raw_mask_exact=bool((rm==cm).all()) if not variant['farMaskZero'] else None
                    row.update(samples=len(samples),radiometricChangedChannels=radiometric_changes,nearBitIdentical=near_exact,maskSubset=subset,farContractBitIdentical=far_exact,outsideDomainRows=int(outside.sum()),fallbackAllChannelsBitIdentical=fallback_exact,originalMaskBitIdentical=raw_mask_exact)
                    row['passed']=radiometric_changes==0 and near_exact and subset and far_exact and fallback_exact is not False and raw_mask_exact is not False
                    if not row['passed']:
                        bad=np.any(rb[:,radiometric]!=cb[:,radiometric],axis=1)
                        if variant['guarded']:bad|=outside&np.any(expected!=cb,axis=1)
                        row['firstFailures']=[{'index':int(i),'sample':samples[i].tolist(),'reference':ref[i].tolist(),'candidate':cand[i].tolist()} for i in np.flatnonzero(bad)[:3]]
                if not row['passed']:failed.append(name)
                rows.append(row)
                write(out/'results.json',{'status':'running','scope':__doc__,'rows':rows})
            print(mode,variant['name'],'cases',len(names),'failures',failed,flush=True)
    summary=[]
    for fast in [False,True]:
        for variant in variants:
            group=[r for r in rows if r['fastMath']==fast and r['variant']==variant['name']]
            summary.append({'fastMath':fast,'variant':variant['name'],'cases':len(group),'passed':sum(r['passed'] for r in group),'failures':[r['case'] for r in group if not r['passed']]})
    write(out/'results.json',{'status':'complete','scope':__doc__,'summary':summary,'rows':rows})
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--legacy',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--fixtures',type=Path,required=True);ap.add_argument('--prepare-only',action='store_true');ap.add_argument('--run-only',action='store_true');args=ap.parse_args()
    if not args.run_only:prepare(args.legacy.resolve(),args.out.resolve())
    if not args.prepare_only:run(args.out.resolve(),args.fixtures.resolve())
