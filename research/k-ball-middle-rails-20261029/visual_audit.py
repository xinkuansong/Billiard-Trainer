from pathlib import Path
import json,math,urllib.request
from concurrent.futures import ThreadPoolExecutor
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-middle-rails-20261029'
def read(name):return json.loads((OUT/name).read_text())
g=read('geometry.json');rows=read('trials.json');regions=read('regions.json');hx=g['length']/2;hz=g['width']/2
for e in regions:
 im=np.asarray(Image.open(OUT/e['mask']));yy,xx=np.nonzero(im[:,:,3]);r=g['rails'][e['railID']]
 gaps=(-hx+(xx+.5)*.002-r['start'][0])*r['normal'][0]+(-hz+(yy+.5)*.002-r['start'][1])*r['normal'][1]-g['radius']
 assert np.all((gaps>=0)&(gaps<=.10)),e['id']
 assert Image.open(OUT/'images'/f"{e['id']}-region.png").size==(1500,1080)
for r in rows:
 im=Image.open(OUT/'masks'/f"{r['regionID']}.png")
 assert im.getpixel((math.floor((r['B'][0]+hx)/.002),math.floor((r['B'][1]+hz)/.002)))==(94,222,143,175),r['id']
 assert Image.open(OUT/'images'/f"{r['id']}.png").size==(1500,1080)
resources=['index.html','audit.json','scan-audit.json','selection.json','trials.json','candidate-audit.json']+[str(x.relative_to(OUT)) for x in (OUT/'images').glob('*.png')]
def fetch(name):
 with urllib.request.urlopen('http://127.0.0.1:8855/'+name) as response:
  assert response.status==200
  assert response.read()==(OUT/name).read_bytes(),name
with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(fetch,resources))
report=dict(passed=True,masksWithin10cm=len(regions),greenMaskContainsAllSamples=len(rows),httpResources=len(resources))
(OUT/'render-audit.json').write_text(json.dumps(report,indent=2));print(report)
