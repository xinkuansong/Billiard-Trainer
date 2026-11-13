#!/usr/bin/env python3
"""Native adversarial equivalence checks for a frozen height-safe kernel.

Never changes the candidate or tolerances. Batch 1 timing is incidental and must
not be used as a performance ranking. Stops and preserves the first failure.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import numpy as np


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def samples(points):
    p=np.asarray(points,dtype='<f4');s=np.zeros((len(p),12),dtype='<f4')
    s[:,:3]=p;s[:,5]=1;s[:,8:11]=[.2,.9,.4];s[:,11]=.8
    return s


def extra_fixtures(audit):
    for record in json.loads(audit.read_text())['rows']:
        witness=record['worst'];p=np.asarray(witness['p'],dtype=np.float32)
        balls=np.zeros((16,4),dtype='<f4');balls[0]=witness['ballPacked']
        points=[p,np.nextafter(p,np.full(3,-np.inf,np.float32)),np.nextafter(p,np.full(3,np.inf,np.float32))]
        yield 'old-witness-'+record['domain'],samples(points),balls,True
        # Keep the difficult occluder but force original near/64 with negligible
        # opacity at the receiver. Its contribution rounds to zero in Float32.
        forced=balls.copy();forced[1]=[p[0],p[2],.028575,1e-12]
        yield 'old-witness-forced-near-'+record['domain'],samples(points),forced,True
    ex=np.float32(2.5399999618530273);ez=np.float32(1.2699999809265137)
    points=[]
    negative_edges=np.array([0x80000000,0x80000001,0x807fffff,0x80800000],dtype='<u4').view(np.float32)
    for y in [np.float32(0),*negative_edges,np.float32(.799),np.nextafter(np.float32(.8),np.float32(-np.inf)),np.float32(.8)]:
        for x in [np.nextafter(-ex,np.float32(-np.inf)),-ex,np.nextafter(-ex,np.float32(np.inf)),np.nextafter(ex,np.float32(-np.inf)),ex,np.nextafter(ex,np.float32(np.inf))]:
            for z in [-ez,np.nextafter(-ez,np.float32(-np.inf)),ez,np.nextafter(ez,np.float32(np.inf))]:
                points.append([x,y,z])
    balls=np.zeros((16,4),dtype='<f4');balls[:4]=[[0,0,.028575,.85],[2.5,1.2,.6,.17],[-2.5,-1.2,.028575,.85],[.5,.5,2.3,.85]]
    yield 'helper-domain-boundary-ulps',samples(points),balls,False
    points=[[0,-1000,0],[10000,.79,0],[-10000,.79,10000],[0,-.01,0],[2.6,.79,0],[0,.79,1.3],[0,3.1,0],[0,1000,0]]
    yield 'receiver-outside-extremes',samples(points),balls,True
    outside=np.zeros((16,4),dtype='<f4');outside[:3]=[[3,0,.028575,.85],[-3,2,.6,.425],[0,-2,2.3,.85]]
    yield 'ball-outside-domain',samples([[0,.79,0],[1,.799,0],[-1,0,.5]]),outside,True


def original_required(s,balls):
    """Rows for which this helper's contract requires the original complete mask."""
    p=s[:,:3];e=np.array([2.5399999618530273,1.2699999809265137],np.float32)
    receiver_inside=(p[:,1]>=0)&(abs(p[:,0])<=e[0])&(abs(p[:,2])<=e[1])
    active=balls[balls[:,3]>0]
    all_balls_outside=all(abs(b[0])>e[0] or abs(b[1])>e[1] for b in active)
    # Negative zero is deliberately included in the proposed bit-sign fallback
    # contract, together with subnormals that GPU float comparison may flush.
    return (p[:,1]>=np.float32(.8))|(~receiver_inside)|np.signbit(p[:,1])|all_balls_outside


def predicate_probe(out):
    """Observe raw bit loads versus comparisons; no candidate kernel modification."""
    out.mkdir(parents=True,exist_ok=False)
    metal='''#include <metal_stdlib>
using namespace metal;
kernel void probe(device const float *values [[buffer(0)]],device const uint *raw [[buffer(1)]],
                  device uint4 *result [[buffer(2)]],uint i [[thread_position_in_grid]]) {
    float y=values[i];
    result[2*i]=uint4(raw[i],as_type<uint>(y),uint(y>=0.0),uint(y<0.0));
    result[2*i+1]=uint4(uint((as_type<uint>(y)&0x80000000u)!=0u),
                       as_type<uint>(y+0.0),as_type<uint>(y*1.0),as_type<uint>(abs(y)));
}
'''
    swift='''import Foundation
import Metal
let a=CommandLine.arguments
let input=try Data(contentsOf:URL(fileURLWithPath:a[2]))
let count=input.count/4
let d=MTLCreateSystemDefaultDevice()!,q=d.makeCommandQueue()!
let o=MTLCompileOptions();o.fastMathEnabled=false
let l=try d.makeLibrary(source:String(contentsOfFile:a[1],encoding:.utf8),options:o)
let p=try d.makeComputePipelineState(function:l.makeFunction(name:"probe")!)
let b=input.withUnsafeBytes { d.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)! }
let r=d.makeBuffer(length:count*32,options:.storageModeShared)!
let c=q.makeCommandBuffer()!,e=c.makeComputeCommandEncoder()!
e.setComputePipelineState(p);e.setBuffer(b,offset:0,index:0);e.setBuffer(b,offset:0,index:1);e.setBuffer(r,offset:0,index:2)
e.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:count,height:1,depth:1));e.endEncoding()
c.commit();c.waitUntilCompleted();guard c.status == .completed else { throw c.error! }
try Data(bytes:r.contents(),count:r.length).write(to:URL(fileURLWithPath:a[3]))
print(d.name)
'''
    (out/'probe.metal').write_text(metal);(out/'probe.swift').write_text(swift)
    bits=np.array([0x00000000,0x80000000,0x00000001,0x80000001,0x007fffff,0x807fffff,0x00800000,0x80800000,0xbc23d70a,0x3f4ccccd],dtype='<u4')
    bits.tofile(out/'input.bin')
    build=subprocess.run(['xcrun','swiftc','-O',str(out/'probe.swift'),'-o',str(out/'probe')],capture_output=True,text=True)
    (out/'build.log').write_text(build.stdout+build.stderr)
    if build.returncode:raise RuntimeError(build.stderr)
    run=subprocess.run([str(out/'probe'),str(out/'probe.metal'),str(out/'input.bin'),str(out/'result.bin')],capture_output=True,text=True)
    (out/'run.log').write_text(run.stdout+run.stderr)
    if run.returncode:raise RuntimeError(run.stderr)
    values=np.fromfile(out/'result.bin',dtype='<u4').reshape(-1,8);rows=[]
    for source,value in zip(bits,values):
        rows.append({'inputBits':f'{source:08x}','inputFloat':float(np.asarray(source).view(np.float32)),
                     'rawUIntLoad':f'{value[0]:08x}','floatLoadAsUInt':f'{value[1]:08x}',
                     'floatGreaterOrEqualZero':bool(value[2]),'floatLessThanZero':bool(value[3]),
                     'bitwiseNegativeGuard':bool(value[4]),'plusZeroBits':f'{value[5]:08x}',
                     'multiplyOneBits':f'{value[6]:08x}','absBits':f'{value[7]:08x}'})
    report={'device':run.stdout.strip(),'scope':'Small native predicate diagnostic, fastMath=false; no changes to height-safe kernel or failed evidence.',
            'allRawLoadsPreserved':bool(np.array_equal(values[:,0],bits)),'allFloatLoadBitcastsPreserved':bool(np.array_equal(values[:,1],bits)),
            'allSignBitGuardsMatchRaw':bool(np.array_equal(values[:,4],bits>>31)),'rows':rows}
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--predicate-probe',action='store_true')
    ap.add_argument('--far-mask-zero',action='store_true',help='Declared near-first contract: far diagnostic mask must be zero; near original-domain contract stays exact')
    ap.add_argument('--base',type=Path,default=Path('output/render-lowdim-20261113/support-grid-check-r1'))
    ap.add_argument('--audit',type=Path,default=Path('output/render-lowdim-20261113/support-height-audit/results.json'))
    args=ap.parse_args()
    if args.predicate_probe:
        predicate_probe(args.out);return
    if args.native is None:ap.error('--native is required for pressure validation')
    args.out.mkdir(parents=True,exist_ok=False)
    kernel=args.out/'height-support.metal';binary=args.out/'evaluate'
    shutil.copy2(args.native/'height-support.metal',kernel);shutil.copy2(args.native/'evaluate',binary)
    manifest={'driverSHA256':sha(Path(__file__)),'kernelSHA256':sha(kernel),'binarySHA256':sha(binary),
              'originalNative':str(args.native),'baseResultsSHA256':sha(args.base/'results.json'),'counterexampleAuditSHA256':sha(args.audit),
              'scope':'Strict native equivalence stress only; batch1 raw timing is not a performance result. Does not modify helper or thresholds.',
              'maskContract':'Near radiometric/near flag exact and mask subset; required near original-domain rows retain all 16 channels. Far mask is exactly zero.' if args.far_mask_zero else 'Original-domain rows retain all 16 channels; other masks may only shrink.'}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    fixtures=[]
    for row in json.loads((args.base/'results.json').read_text())['rows']:
        src=args.base/(row['case']+'-inputs')
        fixtures.append((f"reused-{row['case']}-grid{row['width']}",np.fromfile(src/'samples.bin',dtype='<f4').reshape(-1,12),np.fromfile(src/'balls.bin',dtype='<f4').reshape(16,4),False))
    fixtures.extend(extra_fixtures(args.audit))
    report={'scope':manifest['scope'],'maskContract':manifest['maskContract'],'rows':[],'status':'running'}
    for name,s,balls,full_contract in fixtures:
        folder=args.out/name;folder.mkdir();s.tofile(folder/'samples.bin');balls.tofile(folder/'balls.bin')
        command=[str(binary),str(kernel),str(folder/'samples.bin'),str(folder/'balls.bin'),str(folder/'gpu'),'1']
        process=subprocess.run(command,capture_output=True,text=True)
        (folder/'run.log').write_text(process.stdout+process.stderr)
        row={'case':name,'samples':len(s),'exitCode':process.returncode,'extraFullContract':full_contract}
        v=folder/'gpu/validation.json'
        if v.exists():row['validation']=json.loads(v.read_text())
        if process.returncode==0:
            ref=np.fromfile(folder/'gpu/reference.bin',dtype='<f4').reshape(-1,16)
            candidate=np.fromfile(folder/'gpu/height.bin',dtype='<f4').reshape(-1,16)
            required=original_required(s,balls)
            same=np.all(ref.view(np.uint32)==candidate.view(np.uint32),axis=1)
            near=ref[:,3]!=0;far=~near
            exact_required=required&near if args.far_mask_zero else required
            row['originalRequiredRows']=int(exact_required.sum());row['originalRequiredBitwise']=bool(same[exact_required].all())
            row['originalEqualityDomain']='near required-domain only; far mask explicitly zero' if args.far_mask_zero else 'all required-domain rows'
            # The old worst witnesses are outside the declared practical helper
            # domain; explicitly require every row to retain the whole mask.
            full_selection=near if args.far_mask_zero else np.ones(len(s),dtype=bool)
            row['fullContractBitwise']=bool(same[full_selection].all()) if full_contract else None
            row['nativeRadiometricExact']=row['validation']['radiometricChangedChannels']==0
            bad=(exact_required&~same)|((~same&full_selection) if full_contract else np.zeros(len(s),dtype=bool))
            if args.far_mask_zero:
                row['farReceivers']=int(far.sum());row['farMaskZero']=bool((candidate[far,7].view(np.uint32)==0).all())
                bad|=far&(candidate[:,7].view(np.uint32)!=0)
                # All far channels except the explicitly changed mask must also
                # remain bitwise equal; this keeps padding/diagnostic fields exact.
                far_expected=ref.copy();far_expected[far,7]=0
                far_same=np.all(far_expected.view(np.uint32)==candidate.view(np.uint32),axis=1)
                row['farOtherChannelsBitwise']=bool(far_same[far].all());bad|=far&~far_same
            if bad.any():
                row['firstFailures']=[{'index':int(i),'sample':s[i].tolist(),'reference':ref[i].tolist(),'candidate':candidate[i].tolist()} for i in np.flatnonzero(bad)[:20]]
                row['exitCode']='independent_original_path_contract_failure'
        report['rows'].append(row)
        if row['exitCode']!=0:
            report['status']='failed';report['firstFailure']=name
            (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
            raise RuntimeError(f'Preserved first failure: {name}; inspect {folder}')
        print(name,len(s),'radiometric exact',row['nativeRadiometricExact'],'original rows',row['originalRequiredRows'],flush=True)
        (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    report['status']='passed';report['totalEvaluatedReceivers']=sum(x['samples'] for x in report['rows'])
    report['reusedInputNote']='26 configurations reuse 13 unique original datasets (two prior grid labels); not 26 independent random cases.'
    (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
