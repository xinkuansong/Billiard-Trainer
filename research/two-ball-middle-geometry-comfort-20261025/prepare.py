"""Freeze original library and extract cue-independent B/pocket requests."""
from pathlib import Path
import gzip,hashlib,json,time
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/two-ball-middle-geometry-comfort-20261025'
SRC=ROOT/'output/two-ball-refine-full-20261025'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def rows(p):return [json.loads(l) for l in gzip.decompress(p.read_bytes()).splitlines()]
def key(b,p):return hashlib.sha256(json.dumps([*b,p],separators=(',',':')).encode()).hexdigest()
if __name__=='__main__':
 t=time.perf_counter();assert not (OUT/'manifest.json').exists()
 s=read(SRC/'summary.json');assert s['state']=='complete' and s['auditPassed'] and s['stats']['afterTop']==816076
 index=read(SRC/'parts-index.json');requests={};seen=set();bs=set();n=m=0;parts=[]
 for receipt in index:
  p=SRC/'final'/(receipt['stem']+'.jsonl.gz');assert sha(p)==receipt['finalSHA256'];data=rows(p)
  assert [r['id'] for r in data]==receipt['layoutIDs']
  parts.append(dict(stem=receipt['stem'],source=str(p),sourceSHA256=sha(p),layoutIDs=receipt['layoutIDs']))
  for row in data:
   assert row['id'] not in seen;seen.add(row['id'])
   for c in row['candidates']:
    k=(row['id'],c['cellID']);assert k not in bs;bs.add(k)
    for q in c['top5']:
     n+=1
     if q['pocket'] in (4,5):
      m+=1;k=key(c['position'],q['pocket']);requests[k]=dict(key=k,object=c['position'],pocket=q['pocket'])
 assert (len(seen),len(bs),n,m)==(13570,173577,816076,357711)
 gpath=ROOT/'output/two-ball-comfort-score-five-v2-20261025/data.json';g=read(gpath)['geometry']
 write(OUT/'geometry.json',g);write(OUT/'requests.json',list(requests.values()))
 frozen={str(p):sha(p) for p in [SRC/'summary.json',SRC/'parts-index.json',gpath,HERE/'prepare.py']}
 write(OUT/'manifest.json',dict(source=str(SRC),sourceHashes=frozen,schedule=parts,geometry=g,policy=dict(version='B-pocket-original-ray-geometry-v1',predicate='2D accuracy GridGeometry.cleanObjectPath',input='B position and original chosen pocket only',aim='original generation anchor; middle=(0,+/-width/2)',ray='continue past anchor to measured capture lip union deep collector',blockers='full-radius finite cushion segments, endpoints and circular jaws',contactToleranceMeters=4*2**-23,scope='fixed original direction geometric direct entry, not all-aim/all-spin impossibility',cueIndependent=True,unchangedCorner=True,replacePocket=False,replenish=False,filterByComfort=False,score='distance v2, space v3, angle v2; equal geometric mean',questionKey=['layout.id','candidate.cellID'],questionScore='maximum retained recommendation total; null if empty',thresholdComparison='unrounded >=; cumulative'),counts=dict(layouts=len(seen),BPositions=len(bs),recommendations=n,middleRecommendations=m,uniqueMiddlePairs=len(requests)),prepareSeconds=time.perf_counter()-t))
 print(json.dumps(dict(uniqueMiddlePairs=len(requests),seconds=time.perf_counter()-t)))
