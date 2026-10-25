"""Frozen comfort-85 refinement of the B/pocket-filtered original library."""
from pathlib import Path
import collections,copy,gzip,hashlib,importlib.util,json,math,os,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
SOURCE=ROOT/'output/two-ball-middle-geometry-comfort-20261025'
OUT=ROOT/'output/two-ball-comfort-refine-full-20261025'
sys.path.insert(0,str(ROOT/'research/two-ball-middle-grid18-20261025'))
import pipeline as P
C=P.C;common=P.common;APP=P.HERE/'Worker.app/Worker'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
F=load('comfort_formula',ROOT/'research/two-ball-comfort-full-20261025/run.py')
# Pin the dependency to this pipeline's source, avoiding similarly named research modules.
prep=load('prepare',ROOT/'research/two-ball-middle-geometry-comfort-20261025/prepare.py');sys.modules['prepare']=prep
audit=load('comfort_independent',ROOT/'research/two-ball-middle-geometry-comfort-20261025/audit_report.py')
import numpy as np
read=P.read;write=P.write;sha=P.sha;enc=P.enc;merge=P.merge;inc=P.inc
POLICY=dict(version='comfort85-min-change-v1',threshold=85,comparison='unrounded >=',grid=P.POLICY['grid'],angleHardCap=None,source='original25 after cue-independent B/pocket entry filter',preserveQualifiedOriginal=True,secondPocketFixed=True,railCountAndOrderFixed=True,zeroRailSideSpin=0,jawRoutes='reject',collisionPostMeters='2R+0.002',collisionPreMeters='2R',selection='qualifying minimum rounded normalized delta squares, then less abs side, then higher total, then params',metricScales=[.3,.15,.1],metricRoundDigits=5,failure='retain original; save best legal candidate separately without replacing',dedup='P2>=60; original qualified first, successful replacements second, unchanged low fallback third; original rank within each group; max5',allCandidates='all native trial output including every available 2mm trajectory, once per unique layout/parameters; per-B decisions reproducible from complete grid',score='distance-v2/space-v3/angle-v2 equal geometric mean',fullScope=[13570,173577,765246],initialBelow85=222917,initialAtLeast85=542329)
OMIT_TIMINGS=('wallMilliseconds','extractionCompressionMilliseconds','initialAimMilliseconds','physicsMilliseconds')
POLICY['archive']=dict(gzipLevel=9,omittedPerTrialDiagnostics=list(OMIT_TIMINGS),allPhysicalFieldsAndTrajectoriesPreserved=True,aggregateTimingPreserved=True)

def metric(r,root):
 return sum(round(v,5)**2 for v in [(r['velocity']-root['velocity'])/.3,(r['spinY']-root['spinY'])/.15,(r['spinX']-root['spinX'])/.1])

def decision(root,ref,b,board,byid,ids,prune):
 rejected=collections.Counter(prune);eligible=[];expected=P.seq(root)
 for i in ids:
  r=byid[i];why=r.get('_reject')
  if why is None and P.seq(r)!=expected:why='railStateChanged'
  if why is None:
   path=[p[1:] for p in r['trajectory2mm']['points']]
   if C.nearest(b,path)<=C.diameter+.002 or C.nearest(b,[board['cue'],path[0]])<=C.diameter:why='collisionB'
   elif C.independent_angle(r['cueStop'],b,F.ANCHORS[ref['pocket']])>=90:why='secondCutNotForward'
  if why:rejected[why]+=1;continue
  q=F.score(r['cueStop'],b,ref['pocket'])
  eligible.append(dict(comboIndex=i,comfort=q,change=metric(r,root)))
 qualified=[q for q in eligible if q['comfort']['totalScore']>=85]
 chosen=min(qualified,key=lambda q:(q['change'],abs(byid[q['comboIndex']]['spinX']),-q['comfort']['totalScore'],list(C.params(byid[q['comboIndex']])))) if qualified else None
 best=max(eligible,key=lambda q:(q['comfort']['totalScore'],-q['change'])) if eligible else None
 assert sum(rejected.values())+len(eligible)==245
 return dict(rootComboIndex=root['comboIndex'],pocket=ref['pocket'],expectedRails=list(expected),rejected=dict(rejected),eligibleCount=len(eligible),qualifyingCount=len(qualified),selected=chosen,bestLegal=best)

def native_dedup(candidates,routes,tmp):
 used={q['comboIndex'] for c in candidates for q in c['ranked']}
 inp=dict(routes=[dict(comboIndex=i,points=routes[i]['trajectory2mm']['points']) for i in sorted(used)],candidates=[dict(cellID=c['cellID'],ranked=[q['comboIndex'] for q in c['ranked']]) for c in candidates])
 write(tmp/'dedup-in.json',inp)
 subprocess.run([str(ROOT/'research/two-ball-refine-full-20261025/dedup'),str(tmp/'dedup-in.json'),str(tmp/'dedup-out.json')],check=True,capture_output=True)
 return read(tmp/'dedup-out.json')

def process(old,scores,w,tmp):
 start=time.perf_counter();assert old['id']==scores['id'];roots={r['comboIndex']:copy.deepcopy(r) for r in old['routes']}
 cache={C.params(r):r for r in roots.values()};byid=dict(roots);grids={};allkeys={};trials=[]
 lowids={q['comboIndex'] for c in scores['candidates'] for q in c['recommendations'] if q['totalScore']<85}
 for i in sorted(lowids):
  keys,prune=P.grid(roots[i]);grids[i]=dict(keys=keys,prune=prune)
  for k in keys:allkeys.setdefault(k,None)
 replayed=None
 if lowids:
  r=roots[min(lowids)];rr=w.run(old['board'],[dict(comboIndex=r['comboIndex'],tipID=0,speedID=0,velocity=r['velocity'],spinX=r['spinX'],spinY=r['spinY'])])['rows'][0];C.normalize(rr)
  assert C.reason(rr) is None and rr['cueStop']==r['cueStop'] and rr['trajectory2mm']==r['trajectory2mm'];replayed=r['comboIndex']
 pending=[k for k in allkeys if k not in cache];counter=max(roots,default=0)+1
 for off in range(0,len(pending),32):
  ks=pending[off:off+32];cs=[dict(comboIndex=counter+j,tipID=0,speedID=0,velocity=k[0],spinX=k[1],spinY=k[2]) for j,k in enumerate(ks)];counter+=len(cs)
  rr=w.run(old['board'],cs)['rows']
  for k,r in zip(ks,rr,strict=True):
   C.normalize(r);r['strokeCategory']=C.category(r['spinX'],r['spinY']);r['_reject']=C.reason(r)
   assert r['directionRetries']==0 and r['simulationCalls'] in (0,1)
   for name in OMIT_TIMINGS:r.pop(name,None)
   cache[k]=r;byid[r['comboIndex']]=r;trials.append(r)
 for gr in grids.values():gr['ids']=[cache[k]['comboIndex'] for k in gr.pop('keys')]
 stats=dict(layouts=1,BPositions=len(old['candidates']),beforeRecommendations=0,beforeQualified=0,lowRecommendations=0,optimizedQualified=0,failedKeepOriginal=0,afterRecommendations=0,afterQualified=0,beforeValidB=0,afterValidB=0,beforeQualifiedB=0,afterQualifiedB=0,dedupRemoved=0,originalQualifiedDedupRemoved=0,newSimulations=len(pending),replaySimulations=int(bool(lowids)),gridRoots=len(lowids),gridRejects={},recommendationCountHistogram={},beforeScoreHistogram={},afterScoreHistogram={},afterCutAbove18=0,railHistogram={},categoryHistogram={})
 cands=[];decisions=[]
 for c,sc in zip(old['candidates'],scores['candidates'],strict=True):
  assert c['cellID']==sc['cellID'] and c['position']==sc['position'];ranked=[];records=[];stats['beforeValidB']+=bool(c['top5']);stats['beforeQualifiedB']+=any(q['totalScore']>=85 for q in sc['recommendations'])
  for rank,(ref,s) in enumerate(zip(c['top5'],sc['recommendations'],strict=True)):
   assert (ref['comboIndex'],ref['pocket'])==(s['comboIndex'],s['pocket']);root=roots[ref['comboIndex']];assert root['cueStop']==s['stop']
   assert root['cueJawsAfterContact']==root['cueOtherCushionsAfterContact']==0 and (P.seq(root) or root['spinX']==0)
   oldq=F.score(root['cueStop'],c['position'],ref['pocket']);assert all(abs(oldq[k]-s[k])<1e-8 for k in ('totalScore','distanceScore','spaceScore','angleScore'))
   stats['beforeRecommendations']+=1;inc(stats['beforeScoreHistogram'],min(9,int(s['totalScore']//10)))
   record=dict(originalRank=rank,rootComboIndex=ref['comboIndex'],pocket=ref['pocket'],beforeTotal=s['totalScore'])
   if s['totalScore']>=85:
    q=copy.deepcopy(ref);q.update(comfort=oldq,refinementStatus='originalQualified',rootComboIndex=ref['comboIndex'],originalRank=rank);stats['beforeQualified']+=1;record['action']='originalQualified'
   else:
    stats['lowRecommendations']+=1;gr=grids[ref['comboIndex']];dec=decision(root,ref,c['position'],old['board'],byid,gr['ids'],gr['prune']);record.update(dec);merge(stats['gridRejects'],dec['rejected'])
    chosen=dec['selected']
    if chosen:
     rr=byid[chosen['comboIndex']];q=dict(comboIndex=chosen['comboIndex'],**C.score(rr['cueStop'],c['position'],F.ANCHORS[ref['pocket']],C.G.radius,ref['pocket']),comfort=chosen['comfort'],refinementStatus='optimizedQualified',rootComboIndex=ref['comboIndex'],originalRank=rank,parameterChange=chosen['change']);record['action']='optimizedQualified';stats['optimizedQualified']+=1
    else:
     q=copy.deepcopy(ref);q.update(comfort=oldq,refinementStatus='unqualifiedOriginalRetained',rootComboIndex=ref['comboIndex'],originalRank=rank);record['action']='unqualifiedOriginalRetained';stats['failedKeepOriginal']+=1
   ranked.append(q);record['outputComboIndex']=q['comboIndex'];records.append(record)
  priorities={'originalQualified':0,'optimizedQualified':1,'unqualifiedOriginalRetained':2}
  ranked.sort(key=lambda q:(priorities[q['refinementStatus']],q['originalRank']))
  # Two roots may converge to the exact same parameter triple. Keep their decisions,
  # but submit a unique physical route once to the similarity pass.
  seen=set();unique=[]
  for q in ranked:
   if q['comboIndex'] not in seen:seen.add(q['comboIndex']);unique.append(q)
  cands.append({**copy.deepcopy(c),'ranked':unique});decisions.append(dict(cellID=c['cellID'],recommendations=records,ranked=ranked))
 dedup=native_dedup(cands,byid,tmp);used=set()
 for c,dec,res in zip(cands,decisions,dedup['results'],strict=True):
  lookup={q['comboIndex']:q for q in c.pop('ranked')};c['top5']=[lookup[i] for i in res['top5']];used.update(res['top5']);dec['keptComboIndices']=res['top5'];dec['dedup']=res
  stats['dedupRemoved']+=len(dec['recommendations'])-len(c['top5']);stats['afterRecommendations']+=len(c['top5']);stats['afterValidB']+=bool(c['top5']);stats['afterQualifiedB']+=any(q['comfort']['totalScore']>=85 for q in c['top5']);inc(stats['recommendationCountHistogram'],len(c['top5']))
  oldqualified={q['comboIndex'] for q in dec['ranked'] if q['refinementStatus']=='originalQualified'}
  stats['originalQualifiedDedupRemoved']+=len(oldqualified-set(res['top5']))
  assert oldqualified<=set(res['top5']),'Original qualified routes unexpectedly similar'
  for q in c['top5']:
   t=q['comfort']['totalScore'];stats['afterQualified']+=t>=85;inc(stats['afterScoreHistogram'],min(9,int(t//10)));stats['afterCutAbove18']+=q['comfort']['angleDegrees']>18;inc(stats['railHistogram'],len(P.seq(byid[q['comboIndex']])));inc(stats['categoryHistogram'],byid[q['comboIndex']]['strokeCategory'])
 stats['layoutSeconds']=time.perf_counter()-start
 out={k:copy.deepcopy(v) for k,v in old.items() if k not in ('routes','candidates')};out.update(schema='two-ball-comfort85-minchange-v1',routes=[P.compact(byid[i]) for i in sorted(used)],candidates=cands,comfortRefinementStats=stats)
 trace=dict(id=old['id'],roots=old['routes'],grids={str(i):gr for i,gr in grids.items()},nativeTrials=trials,replayedOriginalComboIndex=replayed,candidates=decisions,stats=stats)
 return out,trace,stats

def verify(old,scores,out,trace,tmp,deep=False):
 assert old['id']==scores['id']==out['id']==trace['id'] and old['board']==out['board']
 assert trace['roots']==old['routes'];roots={r['comboIndex']:r for r in old['routes']};byid={**roots,**{r['comboIndex']:r for r in trace['nativeTrials']}};final={r['comboIndex']:r for r in out['routes']};used=set()
 assert len(byid)==len(roots)+len(trace['nativeTrials'])
 for r in trace['nativeTrials']:
  assert r['_reject']==C.reason(r)
  if r['status']=='success':assert math.dist(r['cueStop'],r['trajectory2mm']['points'][-1][1:])<1e-6 and r['trajectory2mm']['maxDeviationMeters']<=.002+1e-8
 for i,gr in trace['grids'].items():
  keys,prune=P.grid(roots[int(i)]);assert gr['prune']==prune and [C.params(byid[k]) for k in gr['ids']]==keys
 dedupInput=[]
 for c,o,sc,dec in zip(out['candidates'],old['candidates'],scores['candidates'],trace['candidates'],strict=True):
  assert c['cellID']==o['cellID']==sc['cellID']==dec['cellID'] and c['position']==o['position'] and len(c['top5'])<=5
  assert len(dec['recommendations'])==len(o['top5'])
  for ref,s,record in zip(o['top5'],sc['recommendations'],dec['recommendations'],strict=True):
   root=roots[ref['comboIndex']]
   if s['totalScore']>=85:assert record['action']=='originalQualified' and record['outputComboIndex']==ref['comboIndex']
   else:
    gr=trace['grids'][str(ref['comboIndex'])]
    if deep:
     expected=decision(root,ref,c['position'],old['board'],byid,gr['ids'],gr['prune'])
     for k,v in expected.items():assert record[k]==v
    chosen=record['selected'];assert record['outputComboIndex']==(chosen['comboIndex'] if chosen else ref['comboIndex'])
  for q in c['top5']:
   r=final[q['comboIndex']];used.add(q['comboIndex']);assert r==P.compact(byid[q['comboIndex']]);root=roots[q['rootComboIndex']]
   assert P.seq(r)==P.seq(root) and (P.seq(r) or r['spinX']==0)
   ref=next(q0 for q0 in o['top5'] if q0['comboIndex']==q['rootComboIndex']);assert q['pocket']==ref['pocket']
   if q['refinementStatus']!='optimizedQualified':
    assert r==root and all(q[k]==v for k,v in ref.items())
   else:assert q['comfort']['totalScore']>=85
   independent=audit.recompute(F.G,np.array([r['cueStop']]),np.array([c['position']]),np.array([q['pocket']]))[0]
   assert np.max(np.abs(independent-[q['comfort'][k] for k in ('distanceScore','spaceScore','angleScore','totalScore')]))<1e-8
  seen=set();ranked=[]
  for q in dec['ranked']:
   if q['comboIndex'] not in seen:seen.add(q['comboIndex']);ranked.append(q)
  dedupInput.append(dict(cellID=c['cellID'],ranked=ranked));assert [q['comboIndex'] for q in c['top5']]==dec['keptComboIndices']
 assert used==set(final)
 if deep:
  rr=native_dedup(dedupInput,byid,tmp)
  assert [r['top5'] for r in rr['results']]==[[q['comboIndex'] for q in c['top5']] for c in out['candidates']]
