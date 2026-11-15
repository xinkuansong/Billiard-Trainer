#!/usr/bin/env python3
"""Compile and execute extracted sample-loop math before a native App build."""
from pathlib import Path
import os, shutil, subprocess, sys, json, struct, math
ROOT=Path(__file__).resolve().parents[3]
work=Path(os.environ['QIUJI_TEST_WORK']); evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
for src,name in [(ROOT/'scripts/research/cloth_batch_20261115/packed_preflight_main.swift','main.swift'),(ROOT/'QiuJi/Core/Scene/StaticClothIrradiance.swift','StaticClothIrradiance.swift')]:
    shutil.copyfile(src,work/name);shutil.copyfile(src,evidence/name)
with (evidence/'compile.log').open('w') as f:
    subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(work/'StaticClothIrradiance.swift'),str(work/'main.swift'),'-o',str(work/'probe')],stdout=f,stderr=subprocess.STDOUT,check=True)
with (evidence/'probe.log').open('w') as f:
    subprocess.run([str(work/'probe'),str(ROOT),str(evidence)],stdout=f,stderr=subprocess.STDOUT,check=True)
def floats(w):
    b=(evidence/f'width-{w}.bin').read_bytes();return struct.unpack('<'+str(len(b)//4)+'f',b)
a=floats(0);report={}
for w in (2,):
    b=floats(w);assert all(math.isfinite(v) for v in b)
    error=[abs(x-y) for i,(x,y) in enumerate(zip(a,b)) if i%4!=3]
    pruned=sum(b[i] for i in range(3,len(b),12));missed=sum(b[i] for i in range(7,len(b),12));assert pruned>0 and missed==0, (pruned,missed)
    report[str(w)]={'maxAbsolute':max(error),'meanAbsolute':sum(error)/len(error),'relativeToMaxBaseline':max(error)/max(abs(x) for x in a),'points':8192,'prunedBallSamplePairs':pruned,'nonzeroOcclusionMisses':missed}
    assert max(error)==0, report[str(w)]
(evidence/'results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
