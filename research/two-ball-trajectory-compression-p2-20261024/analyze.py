from pathlib import Path
import json,csv,statistics,gzip
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
read=lambda p:json.loads(p.read_text())
scores=read(OUT/'pair-scores.json');details=read(OUT/'point-details.json');reps=read(OUT/'representations.json')
ranking=read(ROOT/'output/two-ball-multi-position-top10-20261024/B42-ranking.json')
order93=[r['comboIndex'] for r in ranking['rows']]
order95=[r['comboIndex'] for r in sorted(ranking['rows']+ranking['removed'],key=lambda r:(r['evaluation']['best']['score'],r['comboIndex']))]
base={(p['a'],p['b']):p['score'] for p in scores['full']['pairs']}
def stats(xs):
 s=sorted(xs);return dict(mean=statistics.mean(xs),median=statistics.median(xs),p95=s[int(.95*(len(s)-1))],min=s[0],max=s[-1],sum=sum(xs))
def dedup(order,mat):
 kept=[];merged={}
 for a in order:
  match=next((b for b in kept if mat[tuple(sorted((a,b)))]>=75),None)
  if match is None:kept.append(a)
  else:merged[str(a)]=match
 return dict(kept=kept,count=len(kept),top10=kept[:10],merged=merged)
result=dict(algorithm=scores['algorithm'],trajectoryCount=95,pairCount=len(base),B42Eligible=93,excludedB42=[r['comboIndex'] for r in ranking['removed']],variants={})
with (OUT/'pair-comparison.csv').open('w') as f:
 writer=csv.writer(f);names=list(reps);writer.writerow(['a','b']+names)
 mats={name:{(p['a'],p['b']):p['score'] for p in scores[name]['pairs']} for name in names}
 for a,b in base:writer.writerow([a,b]+[mats[n][a,b] for n in names])
for name in reps:
 mat=mats[name];errors=[abs(mat[k]-v) for k,v in base.items()]
 flips=[dict(a=k[0],b=k[1],full=base[k],compressed=mat[k],error=mat[k]-base[k]) for k in mat if (mat[k]>=75)!=(base[k]>=75)]
 worst=sorted([dict(a=k[0],b=k[1],full=base[k],compressed=mat[k],error=mat[k]-base[k]) for k in mat],key=lambda r:abs(r['error']),reverse=True)[:20]
 points=[d['variants'][name]['points'] for d in details]
 v=dict(points=stats(points),coordinateBytesPerTrajectory=statistics.mean(points)*8,pointReductionPercent=100*(1-sum(points)/sum(d['variants']['full']['points'] for d in details)),absoluteScoreError=stats(errors),meanSignedScoreError=statistics.mean([mat[k]-base[k] for k in mat]),thresholdFlips=flips,thresholdFlipCount=len(flips),falseMergePairs=sum(p['compressed']>=75 for p in flips),falseSeparatePairs=sum(p['compressed']<75 for p in flips),worstPairs=worst,maxDeviationMM=max(d['variants'][name]['maxDeviationMM'] for d in details),maxLengthLossMM=max(d['variants'][name]['lengthLossMM'] for d in details),dedupB42=dedup(order93,mat),dedupAll95Diagnostic=dedup(order95,mat))
 # Coordinate-only payload, with per-trajectory arrays; excludes events/ids/times.
 payload=json.dumps([[[p['position']['x'],p['position']['z']] for p in r['points']] for r in reps[name]],separators=(',',':')).encode()
 v['coordinateJSONBytes']=len(payload);v['coordinateGzipBytes']=len(gzip.compress(payload,mtime=0))
 result['variants'][name]=v
baseline=result['variants']['full']['dedupB42']
for name,v in result['variants'].items():
 d=v['dedupB42'];v['representativesAdded']=sorted(set(d['kept'])-set(baseline['kept']));v['representativesRemoved']=sorted(set(baseline['kept'])-set(d['kept']));v['sameTop10']=d['top10']==baseline['top10'];v['sameRepresentatives']=d['kept']==baseline['kept']
 v['assignmentChanges']=[a for a in order93 if d['merged'].get(str(a),a)!=baseline['merged'].get(str(a),a)]
(OUT/'summary.json').write_text(json.dumps(result,indent=2))
for n,v in result['variants'].items():
 print(n,'points',v['points'],'err',v['absoluteScoreError'],'flips',v['thresholdFlipCount'],'dedup',v['dedupB42']['count'],'top10',v['dedupB42']['top10'],'added/removed',v['representativesAdded'],v['representativesRemoved'],'assignchanges',v['assignmentChanges'])
print('flips cushion',result['variants']['cushion']['thresholdFlips'])
print('flips key5mm',result['variants']['key5mm']['thresholdFlips'])
