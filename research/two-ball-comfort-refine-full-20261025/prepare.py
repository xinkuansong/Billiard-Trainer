"""Read-only source audit and immutable execution contract."""
import engine as E
from pathlib import Path
import gzip,json,time
def main():
 start=time.perf_counter();out=E.OUT;out.mkdir(exist_ok=True)
 assert not (out/'manifest.json').exists()
 s=E.read(E.SOURCE/'summary.json');assert s['state']=='complete' and s['auditPassed']
 ix=E.read(E.SOURCE/'parts-index.json');entry={p['key']:p for p in E.read(E.SOURCE/'entry-decisions.json')};jobs=[];seen=set();bs=set();low=high=zeroSide=valid=badquestions=lowquestions=rootsCount=0
 for j,part in enumerate(ix):
  stem=part['stem'];src=E.SOURCE/'final'/f'{stem}.jsonl.gz';sp=E.SOURCE/'scores'/f'{stem}.jsonl.gz'
  assert E.sha(src)==part['finalSHA256'] and E.sha(sp)==part['scoresSHA256']
  rows=[json.loads(l) for l in gzip.decompress(src.read_bytes()).splitlines()];scores=[json.loads(l) for l in gzip.decompress(sp.read_bytes()).splitlines()]
  assert [r['id'] for r in rows]==part['layoutIDs']
  for row,sc in zip(rows,scores,strict=True):
   assert row['id']==sc['id'] and row['id'] not in seen;seen.add(row['id']);byid={r['comboIndex']:r for r in row['routes']};rootids=set()
   for r in byid.values():
    assert r['cueJawsAfterContact']==r['cueOtherCushionsAfterContact']==0
    if not E.P.seq(r) and r['spinX']!=0:zeroSide+=1
   for c,scoresc in zip(row['candidates'],sc['candidates'],strict=True):
    k=(row['id'],c['cellID']);assert k not in bs;bs.add(k);assert c['cellID']==scoresc['cellID'] and c['position']==scoresc['position'];l=h=0
    for q,sq in zip(c['top5'],scoresc['recommendations'],strict=True):
     assert (q['comboIndex'],q['pocket'])==(sq['comboIndex'],sq['pocket']) and sq['stop']==byid[q['comboIndex']]['cueStop']
     if q['pocket'] in (4,5):assert entry[E.prep.key(c['position'],q['pocket'])]['passed']
     if sq['totalScore']<85:l+=1;rootids.add(q['comboIndex'])
     else:h+=1
    low+=l;high+=h;valid+=bool(l+h);lowquestions+=bool(l);badquestions+=bool(l and not h)
   rootsCount+=len(rootids)
  jobs.append(dict(stem=stem,source=str(src),sourceSHA256=part['finalSHA256'],scores=str(sp),scoresSHA256=part['scoresSHA256'],layoutIDs=part['layoutIDs']))
  if j%100==0:print('INPUT',j,len(seen),low,flush=True)
 assert (len(seen),len(bs),low,high,valid,lowquestions,badquestions)==(13570,173577,222917,542329,167122,126701,3946)
 assert zeroSide==0,'Source violates no-rail side-spin rule; do not silently keep it'
 paths=[E.HERE/n for n in ['engine.py','runner.py','prepare.py','report.py']]+[E.APP,E.P.HERE/'pipeline.py',E.ROOT/'research/two-ball-refine-full-20261025/core.py',E.ROOT/'research/two-ball-refine-full-20261025/dedup',E.ROOT/'research/two-ball-comfort-full-20261025/run.py',E.ROOT/'research/two-ball-middle-geometry-comfort-20261025/audit_report.py',E.ROOT/'research/two-ball-independent125-full-20261024/contract.py',E.ROOT/'research/two-ball-independent125-full-20261024/runtime_common.py',E.SOURCE/'entry-decisions.json',E.SOURCE/'entry-audit.json',E.SOURCE/'parts-index.json',E.SOURCE/'summary.json']
 hashes={str(p):E.sha(p) for p in paths}
 counts=dict(layouts=len(seen),questions=len(bs),recommendations=low+high,below85=low,atLeast85=high,nonemptyQuestions=valid,questionsWithLow=lowquestions,questionsWithOnlyLow=badquestions,uniqueLowRootsPerLayoutSum=rootsCount,zeroRailSideSpin=zeroSide)
 E.write(E.OUT/'input-audit.json',dict(passed=True,counts=counts,seconds=time.perf_counter()-start))
 E.write(E.OUT/'manifest.json',dict(policy=E.POLICY,workers=16,schedule=jobs,hashes=hashes,counts=counts,diskReserveBytes=4*1024**3))
 print(json.dumps(counts),flush=True)
if __name__=='__main__':main()
