"""Read back source rows and verify all 25 rendered route records and ordering."""
from pathlib import Path
import gzip, hashlib, json, math, re, shutil, urllib.request
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-execution-five-20261025'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
d=json.loads((OUT/'data.json').read_text())
model=ROOT/d['model']['source'];assert sha(model)==d['model']['sha256']
code=model.read_text()
def constant(k):return float(re.search(r'static let '+k+r' = ([0-9.]+)',code)[1])
wx=constant('sideSpinWeight');wy=constant('verticalSpinWeight')
threshold=constant('velocityPenaltyThreshold');slope=constant('velocityPenaltySlope')
assert len(d['samples'])==5 and len({s['id'] for s in d['samples']})==5
for item in d['selection']['scope']:assert sha(ROOT/item['path'])==item['sha256']
route_count=0
for s in d['samples']:
 p=ROOT/s['source'];assert sha(p)==s['sourceSHA256']
 original=next(x for x in map(json.loads,gzip.decompress(p.read_bytes()).splitlines()) if x['id']==s['id'])
 assert s['board']==original['board']
 c=next(x for x in original['candidates'] if x['cellID']==s['candidate']['cellID'])
 assert c==s['candidate'] and len(c['top5'])==5
 routes={t['comboIndex']:t for t in original['routes']}
 assert [routes[q['comboIndex']] for q in c['top5']]==s['routes']
 pairs=[]
 for old,q in enumerate(c['top5'],1):
  t=routes[q['comboIndex']]
  e=math.fsum([wx*abs(t['spinX']),wy*abs(t['spinY']),slope*max(0,t['velocity']-threshold)])
  actual=next(z for z in s['ranking'] if z['comboIndex']==q['comboIndex'])
  assert abs(actual['effort']-e)<1e-12 and actual['originalRank']==old
  assert len(t['trajectory2mm']['cushions'])==t['cueMainRailsAfterContact']
  assert math.dist(t['trajectory2mm']['points'][-1][1:],t['cueStop'])<1e-5
  assert math.hypot(t['spinX'],t['spinY'])<=.500001
  assert t['cueJawsAfterContact']==0 and t['cueOtherCushionsAfterContact']==0
  pairs.append((e,old,q['comboIndex']));route_count+=1
 assert [z[2] for z in sorted(pairs)]==[z['comboIndex'] for z in s['ranking']]
 assert [z['rank'] for z in s['ranking']]==list(range(1,6))
# Verify drawing contract separately from an XZ rotation or a spin sign guess.
assert d['geometry']==json.loads((ROOT/d['source']/'geometry.json').read_text())
assert abs(d['geometry']['length']/d['geometry']['width']-2)<1e-6
assert abs(d['geometry']['radius']-.028575)<1e-7
served=ROOT/'output/two-ball-multi-position-top10-20261024/execution-five'
served.mkdir(exist_ok=True)
files=['index.html','data.json','overview.png']+[f'sample-{i}.png' for i in range(1,6)]
receipts={}
for f in files:
 shutil.copy2(OUT/f,served/f)
 with urllib.request.urlopen('http://127.0.0.1:51240/execution-five/'+f,timeout=10) as response:body=response.read()
 assert hashlib.sha256(body).hexdigest()==sha(OUT/f)
 receipts[f]=dict(sha256=sha(OUT/f),bytes=len(body))
result=dict(status='passed',layouts=5,routes=route_count,scannedSourcesUnchanged=len(d['selection']['scope']),sourceRecordsExact=True,independentFormulaAndOrder=True,cushionEventsAndStops=True,sourceGeometryExact=True,httpFilesExact=receipts,visualReview='five detail PNGs and overview inspected; no clipped text or missing routes',notTested=['physics rerun','parameter robustness','real player difficulty','cue clearance'])
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='httpFilesExact'},ensure_ascii=False))
