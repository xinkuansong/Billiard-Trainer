#!/usr/bin/env python3
"""Independent binary-layout, finite and light/table symmetry audit."""
import hashlib,json,math,os,re,struct,sys
from pathlib import Path
p=Path(sys.argv[1]);manifest=json.loads((p/'attachments/manifest.json').read_text());assets=[]
for t in manifest:
 for item in t['attachments']:
  n=item['suggestedHumanReadableName']
  if n.startswith('static-response-') and '.rgba16f' in n:
   grid=int(re.fullmatch(r'static-response-(17|33)_\d+_[0-9A-Fa-f-]{36}\.rgba16f',n).group(1));assets.append((grid,p/'attachments'/item['exportedFileName']))
assert len(assets)==1,assets
grid,path=assets[0];h=(grid+1)//2;width=grid*16;height=h*35;raw=path.read_bytes()
assert len(raw)==width*height*8
values=[v[0] for v in struct.iter_unpack('<e',raw)]
assert all(math.isfinite(v) and v>=0 for v in values)
def pixel(x,z,az,pol,panel):
 i=((panel*17+pol)*h+z)*width+(az*grid+x)
 return values[i*4:i*4+4]
worst=0;checks=0
for panel in [0,1]:
 for az in range(16):
  for pol in [0,1,8,15,16]:
   for x in [0,grid//2,grid-1]:
    for z in [0,h//2,h-1]:
     original=pixel(x,z,az,pol,panel)
     for twin in [pixel(grid-1-x,z,(8-az)%16,pol,panel),pixel(x,h-1-z,(-az)%16,pol,1-panel)]:
      for a,b in zip(original,twin):
       worst=max(worst,abs(a-b)/max(1e-6,a,b));assert abs(a-b)<max(2e-6,.003*max(a,b));checks+=1
report={'grid':[grid,h],'bytes':len(raw),'SHA256':hashlib.sha256(raw).hexdigest(),'allFiniteNonnegative':True,'symmetryChecks':checks,'maxSymmetryRelativeError':worst,'scope':'Independent exported FP16 asset check; not visual acceptance'}
(Path(os.environ['QIUJI_TEST_EVIDENCE'])/'response-asset-audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
