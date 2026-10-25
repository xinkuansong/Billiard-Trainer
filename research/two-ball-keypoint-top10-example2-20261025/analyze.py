from pathlib import Path
import sys,json,math,itertools,hashlib
from collections import Counter
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry
from filter_second_ball_preview import assess,score,independent_score,independent_segment_distance
read=lambda p:json.loads(p.read_text())
d=read(OUT/'input.json');record=d['record'];board=record['board'];geo=d['geometry'];g=Geometry(**{k:geo[k] for k in ['length','width','radius']});R=g.radius;diameter=2*R;pad=.002
native=read(OUT/'p2-scores.json');assert native['algorithm']=='arc1cm-rms-p2-t20-potgate-v3'
mat={tuple(sorted((r['a'],r['b']))):r['score'] for r in native['key2mm']['pairs']}
trials=[r for r in record['rows'] if r['status']=='success'];assert len(mat)==len(trials)*(len(trials)-1)//2

def nearest(b,pts):
 result=[]
 for i,(a,c) in enumerate(zip(pts,pts[1:])):
  v=[c[j]-a[j] for j in range(2)];vv=sum(x*x for x in v);u=max(0,min(1,sum((b[j]-a[j])*v[j] for j in range(2))/vv)) if vv else 0
  p=[a[j]+u*v[j] for j in range(2)];dist=math.dist(p,b)
  ref=independent_segment_distance(b,a,c) if vv else math.dist(b,a)
  assert math.isclose(ref,dist,abs_tol=1e-11)
  result.append((dist,i,p))
 dist,i,p=min(result);return {'distance':dist,'segmentIndex':i,'point':p}
assert nearest([0,0],[[-1,0],[1,0]])['distance']==0
assert nearest([2,0],[[0,0],[1,0]])['distance']==1
assert nearest([0,1],[[0,0],[0,0]])['distance']==1
assert math.isclose(nearest([.5,diameter+pad],[[0,0],[1,0]])['distance'],diameter+pad)
for angle in [0,45]:
 a=math.radians(angle);c=[-diameter-math.cos(a),-math.sin(a)];m=score(c,[0,0],[1,0],R,0);assert math.isclose(m['score'],1/math.cos(a),rel_tol=1e-10)
results=[]
for cid,x,z,oldp,olds in d['candidates']['candidates']:
 b=[x,z];original=assess(board['cue'],board['object'],b,board['pocket'],g);assert original['keep']
 assert (original['bestSecond'] is None)==(olds is None)
 if olds is not None:assert math.isclose(original['bestSecond']['score'],olds,rel_tol=1e-10) and original['bestSecond']['pocket']==oldp
 kept=[];removed=[]
 for r in trials:
  path=[p[1:] for p in r['trajectory2mm']['points']];post=nearest(b,path);pre=nearest(b,[board['cue'],path[0]])
  reasons=[]
  if post['distance']<=diameter+pad:reasons.append('post_contact_possible_collision')
  if pre['distance']<=diameter:reasons.append('pre_contact_chord_intersection')
  overlap=math.dist(r['cueStop'],b)<diameter
  options=[]
  if not overlap:
   for pid,p in enumerate(g.anchors()):
    m=score(r['cueStop'],b,p,R,pid);ref=independent_score(r['cueStop'],b,p,R)
    assert (m['score'] is None)==math.isinf(ref)
    if m['score'] is not None:assert math.isclose(m['score'],ref,rel_tol=1e-9)
    options.append(m)
  best=min((m for m in options if m['score'] is not None),key=lambda m:(m['score'],m['pocket']),default=None)
  if overlap:reasons.append('endpoint_overlap')
  elif best is None:reasons.append('no_forward_pocket')
  entry={'comboIndex':r['comboIndex'],'best':best,'sixPockets':options,'postContactCheck':post,'preContactChordCheck':pre,'reasons':reasons,'inCompressionMarginBand':abs(post['distance']-diameter)<=pad}
  (removed if reasons else kept).append(entry)
 kept.sort(key=lambda x:(x['best']['score'],x['comboIndex']))
 representatives=[];merged=[]
 for rank,row in enumerate(kept,1):
  row['difficultyRankBeforeDedup']=rank
  match=next((old for old in representatives if mat[tuple(sorted((row['comboIndex'],old['comboIndex']))) ]>=75),None)
  if match is None:row['rank']=len(representatives)+1;representatives.append(row)
  else:merged.append({'comboIndex':row['comboIndex'],'representative':match['comboIndex'],'similarity':mat[tuple(sorted((row['comboIndex'],match['comboIndex']))) ]})
 for a,brow in itertools.combinations(representatives,2):assert mat[tuple(sorted((a['comboIndex'],brow['comboIndex']))) ]<75
 assert len(kept)+len(removed)==len(trials) and len(representatives)+len(merged)==len(kept)
 assert all(r['postContactCheck']['distance']>diameter+pad for r in kept)
 results.append({'cellID':cid,'position':[x,z],'initial':original,'eligibleCount':len(kept),'removedCount':len(removed),'representativeCount':len(representatives),'mergedCount':len(merged),'top10':representatives[:10],'representatives':representatives,'merged':merged,'removed':removed,'rankedBeforeDedup':kept,'marginBandCount':sum(r['inCompressionMarginBand'] for r in removed)})
for path,h in d['sources'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==h
result={'schema':'two-ball-keypoint-top10-v1','layoutID':record['id'],'samplingVersion':record['samplingVersion'],'board':board,'geometry':geo,'attempts':len(record['rows']),'firstShotStatus':dict(Counter(r['status'] for r in record['rows'])),'validFirstShots':len(trials),'candidateCount':len(results),'defaultCellID':42,'algorithm':native['algorithm'],'pairCount':len(mat),'policy':{'difficulty':'minimum six-generation-anchor OP/cos(cut); lower is easier','dedup':'ascending S then comboIndex; merge >=75 into first retained representative; process all eligible then take first 10','postContactThresholdMetres':diameter+pad,'marginMetres':pad,'pathScope':'stored post-contact cue keypoints; pre-contact chord supplement; original C->ghost and A->pocket corridors inherited; no stored object trajectory or three-ball replay','uncertainty':'2mm is deviation from sampled original polyline, not an independent continuous-time collision guarantee'},'candidates':results,'trials':trials,'sourcesSHA256':d['sources'],'verification':{'candidateOriginalRules':True,'independentSegmentDistances':True,'independentDifficultyScores':True,'allPartitions':True,'allRepresentativesPairwiseBelow75':True,'nativeAPIError':native['key2mm']['maxAPIError'],'nativeAsymmetryCM':native['key2mm']['maxAsymmetryCM'],'sourceHashesUnchanged':True}}
(OUT/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,allow_nan=False))
b42=next(c for c in results if c['cellID']==42)
summary={k:v for k,v in result.items() if k not in ['trials','candidates','geometry']};summary['candidateSummaries']=[{k:c[k] for k in ['cellID','eligibleCount','removedCount','representativeCount','mergedCount','marginBandCount']} for c in results];summary['B42']={k:v for k,v in b42.items() if k not in ['rankedBeforeDedup','representatives','removed']}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2,allow_nan=False))
print(json.dumps({'firstShotStatus':result['firstShotStatus'],'allCandidates':len(results),'B42':{k:b42[k] for k in ['eligibleCount','removedCount','representativeCount','mergedCount','marginBandCount']},'initialA':b42['initial']['first'],'initialB42':b42['initial']['bestSecond'],'top10':[r['comboIndex'] for r in b42['top10']]},ensure_ascii=False))
