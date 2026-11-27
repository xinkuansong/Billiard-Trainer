"""Audit and select original bank cases before explicitly adapted supplements."""
from pathlib import Path
import json,hashlib,math,gzip
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-maxscore-gallery-20261106'
cfg=json.loads((OUT/'scenario.json').read_text());inputs={};refined=[]
for folder in [OUT,OUT/'supplement']:
 conf=json.loads((folder/'scenario.json').read_text())
 inputs.update({c['label']:c for c in conf['cases']})
 for r in json.loads((folder/'refined-summary.json').read_text()):
  refined.append({**r,'dataDirectory':str((folder/'refined'/r['label']).relative_to(OUT))})
bankPath=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz'
bank={q['id']:q for q in json.loads(gzip.decompress(bankPath.read_bytes()))['questions']}
bins=cfg['bins'];selected=[];counts={};keys=set()
for b in bins:
 eligible=[r for r in refined if b-2.5<=r['maximum']<b+2.5]
 eligible.sort(key=lambda r:('adaptation' in inputs[r['label']],abs(r['maximum']-b),r['label']))
 kept=[]
 for r in eligible:
  if r['symmetryKey'] in keys:continue
  keys.add(r['symmetryKey']);kept.append({**inputs[r['label']],**r,'bin':b})
  if len(kept)==10:break
 counts[b]=len(kept);selected+=kept
 assert len(kept)==10,(b,len(kept),'No padding or silent interval widening')
checks=[]
for r in selected:
 d=OUT/r['dataDirectory'];scan=json.loads((d/'scan-adaptive.json').read_text());peaks=json.loads((d/'peak-probes.json').read_text())
 rows=scan['coarse']+scan['rows']+peaks;valid=[p for p in rows if 'score' in p]
 assert abs(max(p['score'] for p in valid)-r['maximum'])<1e-9
 best=[p for p in valid if abs(p['score']-r['maximum'])<1e-9];assert best
 target=scan['target']
 for p in valid:
  assert 0<=p['score']<=100 and math.isfinite(p['score'])
  assert math.dist([p['x'],p['z']],target)>=.3-1e-6
 assert r['bin']-2.5<=r['maximum']<r['bin']+2.5
 native=json.loads((d/'native-results.json').read_text());assert native['passed'] and not native['issues']
 q=r['question'];original=bank[q['id']]
 if 'adaptation' in r:
  assert r['originalQuestion']==original
  assert q['cue']==original['cue']
  positions=[b['position'] for b in original['balls']]
  assert all(b['position'] in positions for b in q['balls'])
 else:assert q==original
 assert r['target']==next(b['position'] for b in q['balls'] if b['number']==9)
 checks.append({'label':r['label'],'bin':r['bin'],'maximum':r['maximum'],'branch':r['maximumStatus'],'evaluatedRows':len(valid),'sourceSHA256':hashlib.sha256((d/'scan-adaptive.json').read_bytes()).hexdigest(),'peakSHA256':hashlib.sha256((d/'peak-probes.json').read_bytes()).hexdigest(),'adaptation':r.get('adaptation'),'originalCoordinatesVerified':True})
manifest=json.loads((OUT/'source-manifest.json').read_text());drift=[p for p,h in manifest.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h];assert not drift
assert hashlib.sha256(bankPath.read_bytes()).hexdigest()==cfg['bankSHA256']
(OUT/'selected.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2))
(OUT/'validation.json').write_text(json.dumps({'passed':True,'counts':counts,'cases':checks,'sourceDrift':drift,'bankUnchanged':True,'scope':'Static score maps only. Sampled maxima, not a proof of continuous global maxima. No shot reachability validation. One target orientation per rounded mirror-symmetry class. Adapted supplements preserve original coordinates with explicit role/ball-count changes.'},ensure_ascii=False,indent=2))
print('Selected',counts,'adapted',sum('adaptation' in c for c in selected))
