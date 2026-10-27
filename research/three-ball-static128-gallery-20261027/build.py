from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/three-ball-static128-final-audit-20261027'
OUT=ROOT/'output/three-ball-static128-gallery-20261027'
forms=json.loads((SRC/'formations.json').read_text())['items']
groups=[]
for i in range(1,129):
 s=json.loads((SRC/f'sample-{i:03}.json').read_text())['sample']
 prefix=s['id']+'/second-cell:'+str(s['cellID'])+'/'
 groups.append(dict(number=i,id=s['id'],cellID=s['cellID'],board=s['board'],second=s['second'],items=[f for f in forms if f['id'].startswith(prefix)]))
assert len(forms)==365 and sum(len(x['items']) for x in groups)==365
assert all(0<=len(x['items'])<=3 for x in groups)
g=json.loads((ROOT/'QiuJi/Resources/TwoBallBank/index.json').read_text())['geometry']
assert abs(g['length']/g['width']-2)<1e-6
# Equal x/z scaling; center maps to (450,255), +X right, +Z down.
assert 450+g['length']/2*300>450 and 255+g['width']/2*300>255
payload=dict(geometry=g,groups=groups)
template=Path(__file__).with_name('viewer.html').read_text()
OUT.mkdir(exist_ok=True)
(OUT/'index.html').write_text(template.replace('__DATA__',json.dumps(payload,ensure_ascii=False).replace('</','<\\/')))
(OUT/'manifest.json').write_text(json.dumps(dict(source=str(SRC/'formations.json'),sha256=hashlib.sha256((SRC/'formations.json').read_bytes()).hexdigest(),formations=len(forms),inputs=len(groups),empty=[x['number'] for x in groups if not x['items']],multiPocket=next((dict(sample=q['number'],position=i+1) for q in groups for i,f in enumerate(q['items']) if len(f['pocket2Options'])>1),None)),indent=2))
print((OUT/'manifest.json').read_text())
