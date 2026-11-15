#!/usr/bin/env python3
"""Audit H16 evidence and unchanged production inputs, without another benchmark."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
ids=['a2593999d59d41bd975ced4b5cf46d6f','4364b8d6d0dc495a919a6a6916d28cb8','25632ad39fc54a74b92ec12838bce12a','625f04a83d344671914b52f61a9c0ded','4872b96fbe86494386bb1ed837d9e781','915557b0425d42c696e64d1e733061b5']
report={'runs':[],'productionComparedWithH15':{},'formalTimedFrames':0,'formalQualityPairs':0}
for rid in ids:
 p=ROOT/'output/local-test-runs'/rid;r=json.loads((p/'run.json').read_text())
 assert r['exit_code']==0 and not (p/'work').exists(),rid
 row={'id':rid,'task':r['task'],'state':r['state'],'exitCode':r['exit_code'],'workExists':False}
 f=p/'evidence/test-summary.json'
 if f.exists():
  s=json.loads(f.read_text());assert s['passedTests']==1 and s['failedTests']==s['skippedTests']==0
  row['testCounts']={k:s[k] for k in ['totalTestCount','passedTests','failedTests','skippedTests']}
 report['runs'].append(row)
baseline=ROOT/'output/local-test-runs/45049dd5c729464480350e8c347598a8/evidence/snapshot-manifest.json'
base=json.loads(baseline.read_text())['files'];production={p:v['sha256'] for p,v in base.items() if p.startswith('QiuJi/')}
changed=[p for p,h in production.items() if not (ROOT/p).exists() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
assert not changed,changed
report['productionComparedWithH15']={'baseline':str(baseline.relative_to(ROOT)),'checkedFiles':len(production),'changedFiles':changed}
for rid in ids[1::2]:
 p=ROOT/'output/local-test-runs'/rid/'evidence';m=json.loads((p/'snapshot-manifest.json').read_text())['files'];actual={k:v['sha256'] for k,v in m.items() if k.startswith('QiuJi/')}
 assert actual==production,rid
 report.setdefault('productionSnapshotMatches',[]).append(rid)
 for f in (p/'attachments').glob('*.json'):
  d=json.loads(f.read_text())
  if isinstance(d,dict) and d.get('study','').startswith('H16'):
   assert d['completed'] and len(d['rows']) in [3,6]
   for row in d['rows']:
    assert row['aaMaximum']==row['restoreMaximum']==0 and row['maximumChannelDifference']<=1
    report['formalQualityPairs']+=1
    for slot in row['times']:
     assert len(slot['frames'])==12
     for frame in slot['frames']:
      assert frame['gpuEndTime']>frame['gpuStartTime']>0
     report['formalTimedFrames']+=len(slot['frames'])
   report.setdefault('rawReports',[]).append(str(f.relative_to(ROOT)))
assert report['formalTimedFrames']==8640 and report['formalQualityPairs']==15
last=ROOT/'output/local-test-runs'/ids[-1]/'evidence/frozen-source/QiuJiTests/ClothSupportPerformanceResearchTests.swift'
assert last.read_bytes()==(ROOT/'QiuJiTests/ClothSupportPerformanceResearchTests.swift').read_bytes()
report['finalTestSourceMatchesFrozen']=True
out=ROOT/'tasks/render-highlight-20261114/H16-CHECKS.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'runsReclaimed':len(ids),'productionFilesUnchanged':len(production),'formalTimedFrames':report['formalTimedFrames'],'qualityPairs':report['formalQualityPairs']}))
