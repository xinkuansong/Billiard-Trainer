#!/usr/bin/env python3
"""Compile both producer and complete consumer, validate atlas/view addressing."""
import json,math,os,subprocess
from pathlib import Path
from compare_ir import wrapper
root=Path(__file__).resolve().parents[3];work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
p=root/'output/static-cloth-20261126/response-bake'
sources={'producer':(p/'response.metal').read_text(),'consumer':wrapper((p/'response.surface').read_text()).replace('uint index [[thread_position_in_grid]]','texture2d<float> staticGeometryAtlas [[texture(6)]],uint index [[thread_position_in_grid]]')}
for name,source in sources.items():
 f=evidence/(name+'.metal');f.write_text(source)
 with (evidence/(name+'.log')).open('wb') as log:subprocess.run(['xcrun','-sdk','macosx','metal','-std=metal3.1','-O3','-c',str(f),'-o',str(work/(name+'.air'))],stdout=log,stderr=subprocess.STDOUT,check=True)
for g in [17,33]:
 h=(g+1)//2
 for panel in range(2):
  for az in range(16):
   for pol in range(17):
    x=az*g+g//2;y=(panel*17+pol)*h+h//2
    assert x//g==az and y//h==panel*17+pol
    t=pol/16;nv=max(.001,1-t*t);a=az*2*math.pi/16
    v=(math.sqrt(1-nv*nv)*math.cos(a),nv,math.sqrt(1-nv*nv)*math.sin(a))
    assert abs(sum(z*z for z in v)-1)<1e-12
    if nv<1:
     phi=math.atan2(v[2],v[0])*16/(2*math.pi)%16
     assert min(abs(phi-az),16-abs(phi-az))<1e-12
 assert g*16*h*35*8<4*1024**2
report={'compiled':list(sources),'layoutChecks':'Both lamps, all 16 azimuths and 17 polar nodes, both spatial grids','scope':'Not native GPU or quality evidence'}
(evidence/'preflight.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
