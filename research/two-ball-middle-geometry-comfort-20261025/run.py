"""Filter the original library by B/pocket geometry; preserve trajectories and score sidecars."""
from prepare import *
import collections,copy,importlib.util,traceback
sp=importlib.util.spec_from_file_location('comfort',ROOT/'research/two-ball-comfort-full-20261025/run.py');C=importlib.util.module_from_spec(sp);sp.loader.exec_module(C)
def gzwrite(p,values):
 with gzip.open(p,'wt',compresslevel=6) as f:
  for v in values:f.write(json.dumps(v,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')
def main():
 start=time.perf_counter();assert not (OUT/'summary.json').exists();ga=read(OUT/'geometry-audit.json');assert ga['passed'] and ga['proofsSHA256']==sha(OUT/'geometry-proofs.json')
 manifest=read(OUT/'manifest.json');manifest['sourceHashes'][str(Path(C.__file__))]=sha(Path(C.__file__));manifest['sourceHashes'][str(HERE/'run.py')]=sha(HERE/'run.py');write(OUT/'manifest.json',manifest)
 entry=read(OUT/'entry-audit.json');assert entry['passed'] and entry['noKnownDirectPotPairDeleted'] and entry['decisionSHA256']==sha(OUT/'entry-decisions.json')
 proofs={p['key']:p for p in read(OUT/'entry-decisions.json')}
 for d in ['final','scores','deletions']:(OUT/d).mkdir(exist_ok=True)
 counts=collections.Counter();hist=collections.Counter();cross=collections.Counter();totals=[];best=[];indices=[];seen=set();bs=set();removedPairs=set();beforeValid=afterValid=lost=0
 prior=ROOT/'output/two-ball-middle-filter-20261025';priorIndex={p['stem']:p for p in read(prior/'parts-index.json')}
 for i,part in enumerate(manifest['schedule']):
  stem=part['stem'];source=Path(part['source']);assert sha(source)==part['sourceSHA256'];original=rows(source)
  oldfile=prior/'parts'/f'{stem}.jsonl.gz';assert sha(oldfile)==priorIndex[stem]['finalSHA256'];priorRows=rows(oldfile)
  final=[];scores=[];deleted=[]
  for old,previous in zip(original,priorRows,strict=True):
   assert old['id']==previous['id'] and old['id'] not in seen;seen.add(old['id']);new=copy.deepcopy(old);scoreRow=dict(id=old['id'],candidates=[]);delRow=dict(id=old['id'],deleted=[]);used=set();routes={r['comboIndex']:r for r in old['routes']}
   priorKeys={(c['cellID'],q['comboIndex'],q['pocket']) for c in previous['candidates'] for q in c['top5']}
   for c in new['candidates']:
    identity=(old['id'],c['cellID']);assert identity not in bs;bs.add(identity);beforeValid+=bool(c['top5']);oldtop=c['top5'];keep=[];scored=[]
    for rank,q in enumerate(oldtop,1):
     counts['before']+=1;middle=q['pocket'] in (4,5);k=key(c['position'],q['pocket']) if middle else None;passed=proofs[k]['passed'] if middle else True
     cross[f'prior_{"kept" if (c["cellID"],q["comboIndex"],q["pocket"]) in priorKeys else "deleted"}__geometry_{"kept" if passed else "deleted"}']+=1
     if middle:counts['middleChecked']+=1
     if not passed:
      counts['deletedMiddle']+=1;removedPairs.add((*identity,q['pocket']));delRow['deleted'].append(dict(cellID=c['cellID'],position=c['position'],recommendation=q,geometryProofKey=k,reason=proofs[k]['reason']));continue
     counts['keptMiddle' if middle else 'unchangedCorner']+=1;counts['after']+=1;keep.append(q);used.add(q['comboIndex']);stop=routes[q['comboIndex']]['cueStop'];score=C.score(stop,c['position'],q['pocket']);assert abs(score['angleDegrees']-q['angle'])<1e-6
     scored.append(dict(originalRank=rank,comboIndex=q['comboIndex'],pocket=q['pocket'],stop=stop,**score));totals.append(score['totalScore'])
    c['top5']=keep;c['middleGeometryFilter']=dict(before=len(oldtop),after=len(keep),checkedPockets=sorted({q['pocket'] for q in oldtop if q['pocket'] in (4,5)}));hist[len(keep)]+=1;afterValid+=bool(keep);lost+=bool(oldtop) and not keep
    b=max([x['totalScore'] for x in scored],default=None)
    if b is not None:best.append(b)
    scoreRow['candidates'].append(dict(cellID=c['cellID'],position=c['position'],recommendations=scored,bestTotalScore=b))
   new['routes']=[r for r in old['routes'] if r['comboIndex'] in used];new['originalStats']=new.pop('stats',{});new['schema']='two-ball-original-B-pocket-geometry-v1';new['middleGeometryStats']=dict(before=sum(len(c['top5']) for c in old['candidates']),after=sum(len(c['top5']) for c in new['candidates']))
   final.append(new);scores.append(scoreRow);deleted.append(delRow)
  receipt=dict(stem=stem,sourceSHA256=part['sourceSHA256'],layoutIDs=[r['id'] for r in final])
  for folder,values in [('final',final),('scores',scores),('deletions',deleted)]:
   p=OUT/folder/f'{stem}.jsonl.gz';gzwrite(p,values);receipt[folder+'SHA256']=sha(p);receipt[folder+'Bytes']=p.stat().st_size
  indices.append(receipt)
  if i%100==0:write(OUT/'progress.json',dict(state='filter-and-score',parts=i+1,totalParts=len(manifest['schedule']),counts=dict(counts),seconds=time.perf_counter()-start));print(i+1,dict(counts),flush=True)
 assert len(seen)==13570 and len(bs)==173577 and counts['before']==816076 and counts['middleChecked']==357711 and counts['unchangedCorner']==458365
 assert beforeValid==170445 and afterValid+lost==beforeValid and counts['before']==counts['after']+counts['deletedMiddle']
 for p,h in manifest['sourceHashes'].items():assert sha(Path(p))==h
 write(OUT/'parts-index.json',indices)
 summary=dict(state='computed-needs-audit',auditPassed=False,layouts=len(seen),BPositions=len(bs),counts=dict(counts),geometryUniquePairs=len(proofs),geometryBlockedUniquePairs=ga['blockedPairs'],entryRejectedUniquePairs=entry['deletedPairs'],entryDecisionCounts=entry['counts'],removedQuestionPocketPairs=len(removedPairs),questionsWithRoutesBefore=beforeValid,questionsWithRoutesAfter=afterValid,questionsLostAllRoutes=lost,questionsWithoutRoutes=173577-afterValid,recommendationCountHistogram=dict(hist),routeScores=C.describe(totals),questionBestScores=C.describe(best),priorFilterComparison=dict(cross),gzipBytes={d:sum(p[d+'Bytes'] for p in indices) for d in ['final','scores','deletions']},filterAndScoreSeconds=time.perf_counter()-start)
 write(OUT/'summary-pending.json',summary);print(json.dumps(summary,ensure_ascii=False),flush=True)
if __name__=='__main__':
 try:main()
 except BaseException:write(OUT/'failure.json',dict(traceback=traceback.format_exc(),time=time.time()));raise
