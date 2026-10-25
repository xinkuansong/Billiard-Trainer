"""Full-part pilot must reproduce the five approved independent searches."""
import engine as E
import gzip,json,shutil
def main():
 s=E.read(E.OUT/'pilot-summary.json');assert s['auditPassed'] and s['state']=='pilot-complete'
 expected=E.read(E.ROOT/'output/two-ball-comfort-refine-five-20261025/results.json');matches=[]
 for sample in expected['samples']:
  ref=sample['sample'];stem=ref['stem'];rows=[json.loads(l) for l in gzip.decompress((E.OUT/'refinement'/f'{stem}.jsonl.gz').read_bytes()).splitlines()]
  row=next(r for r in rows if r['id']==ref['id']);byid={r['comboIndex']:r for r in row['roots']+row['nativeTrials']}
  cand=next(c for c in row['candidates'] if c['cellID']==ref['cellID']);decision=next(d for d in cand['recommendations'] if d['rootComboIndex']==ref['route']['comboIndex'])
  selected=decision['selected'] if sample['qualified'] else decision['bestLegal'];r=byid[selected['comboIndex']]
  assert E.C.params(r)==tuple(sample['after']['parameters'])
  assert r['cueStop']==sample['after']['route']['cueStop'] and r['trajectory2mm']==sample['after']['route']['trajectory2mm']
  assert selected['comfort']['totalScore']==sample['after']['scores']['totalScore']
  assert decision['qualifyingCount']==sample['qualifying'] and decision['rejected']==sample['rejected']
  if not sample['qualified']:assert decision['outputComboIndex']==ref['route']['comboIndex']
  matches.append(dict(sample=ref['number'],exact=True,total=selected['comfort']['totalScore'],qualified=bool(decision['selected'])))
 t=s['stats'];target=E.read(E.OUT/'manifest.json')['counts']['uniqueLowRootsPerLayoutSum'];ratio=target/t['gridRoots']
 proof=s['refinementGzipBytes']*ratio;final=s['finalGzipBytes']*13570/t['layouts'];free=shutil.disk_usage(E.OUT).free
 # The pilot is already committed and its bytes are already excluded from free.
 # Full execution skips it, so budget only future writes, not the same bytes twice.
 remaining=proof+final-s['refinementGzipBytes']-s['finalGzipBytes']
 spaceOK=remaining*1.5+4*1024**3<free
 estimate=dict(passed=spaceOK,fiveParityPassed=True,fiveMatches=matches,pilotLayouts=t['layouts'],pilotRootCount=t['gridRoots'],pilotUniqueSimulations=t['newSimulations'],projectedRefinementBytes=proof,projectedFinalBytes=final,projectedTotalBytes=proof+final,projectedRemainingBytes=remaining,projectionMethod='refinement bytes scaled by unique below85 roots; final by layouts; subtract already committed pilot from future writes; 8 parts include5 reviewed examples, not random full cost sample',freeDiskBytes=free,conservativeRemainingBytes1_5=remaining*1.5,reserveBytes=4*1024**3,projectedComputeHours=t['layoutSeconds']*ratio/16/3600,projectedAuditHours=s['auditSeconds']*ratio/3600)
 E.write(E.OUT/'pilot-verification.json',estimate);print(json.dumps(estimate,ensure_ascii=False,indent=2))
 assert spaceOK,'Conservative remaining disk estimate exceeds free space; do not start until resolved'
if __name__=='__main__':main()
