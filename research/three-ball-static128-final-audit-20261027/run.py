"""Same 128-question static pilot; unchanged certification, dense audit only after final selection."""
from pathlib import Path
import os,sys,json,gzip,hashlib,random,math,time,collections,subprocess,re
from concurrent.futures import ProcessPoolExecutor,as_completed
import numpy as np
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'research/three-ball-middle-filter-20261027'))
import filter as F
R,E,M=F.R,F.E,F.M
INPUT=ROOT/'output/two-ball-random3-per-layout-20261027'
ARCHIVE=ROOT/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
SEED='three-ball-static128-20261027-v1';WORKERS=8

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,allow_nan=False,indent=2))
def rng(key):return random.Random(int.from_bytes(hashlib.sha256(key.encode()).digest(),'big'))
def identity(s):return s['id']+'/second-cell:'+str(s['cellID'])
def extract_function(source,start):
 i=source.index(start);a=source.index('{',i);depth=1;j=a+1
 while depth:
  if source[j]=='{':depth+=1
  elif source[j]=='}':depth-=1
  j+=1
 return source[i:j]

def prepare():
 start=time.monotonic();source=INPUT/'selected-bank.jsonl.gz';manifest=json.loads((INPUT/'manifest.json').read_text());assert sha(source)==manifest['files'][source.name]
 allq=[]
 with gzip.open(source,'rt') as f:
  for line in f:
   row=json.loads(line);routes={r['id']:r for r in row['routes']}
   for q in row['questions']:
    s=dict(id=row['id'],cellID=q['id'],board=row['board'],second=q['p'],refs=q['refs'],routes=[routes[x[0]] for x in q['refs']])
    allq.append(s)
 samples=sorted(allq,key=lambda s:hashlib.sha256((SEED+'\0'+identity(s)).encode()).digest())[:128]
 ai=json.loads((ARCHIVE/'index.json').read_text());entries={e['id']:e for e in ai['layouts']};parts={s['name']:s for s in ai['shards']};group=collections.defaultdict(list)
 for s in samples:group[entries[s['id']]['shard']].append(s)
 archive_hashes={}
 for shard,wanted in group.items():
  p=ARCHIVE/(shard+'.jsonl.gz');raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==parts[shard]['sha256'];archive_hashes[str(p.relative_to(ROOT))]=sha(p)
  byid={x['id']:x for x in map(json.loads,gzip.decompress(raw).splitlines())}
  for s in wanted:
   row=byid[s['id']];assert row['board']==s['board'];q=next(c for c in row['candidates'] if c['cellID']==s['cellID']);assert q['position']==s['second'];assert [[t['comboIndex'],t['pocket']] for t in q['top5']]==s['refs']
   oldroutes={r['comboIndex']:r for r in row['routes']};stops=[]
   for rank,(r,ref) in enumerate(zip(s['routes'],s['refs'])):
    old=oldroutes[r['id']]
    assert (r['v'],r['sx'],r['sy'],r['dir'])==(old['velocity'],old['spinX'],old['spinY'],old['strikeDirection'])
    stops.append(dict(rank=rank,routeID=r['id'],pocket=ref[1],position=old['cueStop']))
   s['stops']=stops
 for no,s in enumerate(samples,1):
  s['number']=no;s['firstMetric']=E.metric(s['board']['cue'],s['board']['object'],s['board']['aim']);gen=rng(SEED+'/grid/'+identity(s));s['candidates']=[]
  for iz in range(6):
   for ix in range(12):
    p=[E.f32(-R.HX+R.R+(ix+.5)*(R.L-2*R.R)/12+gen.uniform(-.05,.05)),E.f32(-R.HZ+R.R+(iz+.5)*(R.W-2*R.R)/6+gen.uniform(-.05,.05))];reasons=[]
    if min(math.dist(p,t) for t in [s['board']['cue'],s['board']['object'],s['second']])<2*R.R:reasons.append('overlap')
    if E.segment(p,s['board']['cue'],s['firstMetric']['ghost'])<2*R.R or E.segment(p,s['board']['object'],s['board']['aim'])<2*R.R:reasons.append('blocks_first_geometry')
    reasons,best=F.opening(s,dict(position=p,reasons=reasons))
    s['candidates'].append(dict(id=iz*12+ix,position=p,reasons=reasons,bestInitial=best,legalPockets3=M.pockets(p)))
 write(OUT/'inputs.json',samples)
 return samples,dict(seconds=time.monotonic()-start,sourceSHA=sha(source),archiveIndexSHA=sha(ARCHIVE/'index.json'),archiveShardSHA=archive_hashes,populationQuestions=len(allq))

def native_checks(samples):
 start=time.monotonic();work=Path(os.environ['QIUJI_TEST_WORK']);asc=ROOT/'QiuJi/Core/Scene/AngleSceneCalculator.swift';bt=ROOT/'QiuJi/Core/Physics/BTPhysicsConstants.swift'
 text=asc.read_text();constants='\n'.join(re.search(r'    (?:private )?static let '+name+r': Float[^\n]+',text)[0] for name in ['innerLength','innerWidth','ballRadius','cornerPocketOffset','middlePocketOffset'])
 methods='\n'.join(extract_function(text,k) for k in ['static func pocketPositions(','private static func pocketCenters(','static func clampAwayFromPockets('])
 btext=bt.read_text();bconstants='\n'.join(re.search(r'    static let '+name+r': Float[^\n]+',btext)[0] for name in ['sidePocketDiameter','sidePocketRadius','sidePocketNearRimZ','sidePocketCenterOffsetZ'])
 mtext=M.SOURCE.read_text();assess=extract_function(mtext,'static func assess(')
 main='''import Foundation
struct SCNVector3 {var x,y,z:Float;init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z}}
enum TablePhysics {\n'''+bconstants+'\n}\nenum AngleSceneCalculator {\n'+constants+'\n'+methods+'''
}
enum MiddlePocketRegion {
 enum Assessment {case inside,outside,uncalibrated}
 struct Calibration {let halfWidth:Double;let inset:Double;let slope:Double}
'''+assess+f'''
 static let verified = Calibration(halfWidth:{M.HALF_WIDTH},inset:{M.INSET},slope:{M.SLOPE})
}}
struct ScoreCase:Codable {{let c,b,p:[Double]}}
struct Input:Codable {{let points:[[Double]];let cases:[ScoreCase]}}
let input=try JSONDecoder().decode(Input.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
let g=ShotComfortScore.Geometry(length:{R.L},width:{R.W},radius:{R.R})
let scores=input.cases.map {{t -> [Double]? in
 guard let s=ShotComfortScore.evaluate(cue:(t.c[0],t.c[1]),ball:(t.b[0],t.b[1]),aim:(t.p[0],t.p[1]),geometry:g,pocketDistanceAngle:true) else {{return nil}}
 return [s.distance,s.space,s.angle,s.total]
}}
let legal=input.points.map {{ a -> Bool in
 let p=SCNVector3(Float(a[0]),0,Float(a[1])), c=AngleSceneCalculator.clampAwayFromPockets(p,surfaceY:0)
 let dx=c.x-p.x,dz=c.z-p.z
 return abs(p.x)<=AngleSceneCalculator.innerLength/2-AngleSceneCalculator.ballRadius && abs(p.z)<=AngleSceneCalculator.innerWidth/2-AngleSceneCalculator.ballRadius && sqrtf(dx*dx+dz*dz)<=0.000001
}}
let middle=input.points.map {{a in (0..<6).map {{p in p<4 || MiddlePocketRegion.assess(target:SCNVector3(Float(a[0]),0,Float(a[1])),pocket:p,calibration:MiddlePocketRegion.verified) == .inside}} }}
struct Result:Codable {{let scores:[[Double]?];let legal:[Bool];let middle:[[Bool]]}}
try JSONEncoder().encode(Result(scores:scores,legal:legal,middle:middle)).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
'''
 (work/'main.swift').write_text(main);(OUT/'native-main.swift.txt').write_text(main)
 cases=[];points=[c['position'] for s in samples for c in s['candidates']]
 for s in samples:
  cases.extend(dict(c=t['position'],b=s['second'],p=R.ANCHORS[t['pocket']].tolist()) for t in s['stops'])
  gen=rng(SEED+'/score/'+identity(s))
  cases.extend(dict(c=[gen.uniform(-R.HX+R.R,R.HX-R.R),gen.uniform(-R.HZ+R.R,R.HZ-R.R)],b=s['second'],p=R.ANCHORS[p].tolist()) for p in range(6) for _ in range(4))
 write(OUT/'native-input.json',dict(points=points,cases=cases))
 compile=subprocess.run(['xcrun','swiftc','-O',str(R.SOURCE),str(work/'main.swift'),'-o',str(work/'static-check')],capture_output=True,text=True);(OUT/'native-build.log').write_text(compile.stdout+compile.stderr);assert compile.returncode==0,compile.stderr
 subprocess.run([str(work/'static-check'),str(OUT/'native-input.json'),str(OUT/'native-output.json')],check=True)
 native=json.loads((OUT/'native-output.json').read_text());error=0
 assert len(native['scores'])==len(cases)
 for t,n in zip(cases,native['scores']):
  py=R.evaluate(t['c'],t['b'],t['p'])
  if n is None:assert np.isnan(py).all()
  else:error=max(error,float(np.max(np.abs(py-n))))
 assert error<1e-9
 expected=[[p in M.pockets(point) for p in range(6)] for point in points];assert expected==native['middle']
 k=0
 for s in samples:
  for c in s['candidates']:
   c['nativePlacementLegal']=native['legal'][k]
   if not c['nativePlacementLegal']:c['reasons'].append('pocket_or_rail_placement')
   k+=1
 audit=dict(passed=True,seconds=time.monotonic()-start,scoreCases=len(cases),maxScoreError=error,middleComparisons=len(points)*6,placementCases=len(points),mode='production score full source; exact extracted placement functions; middle assess with previously native-verified calibration and source hash lock; Float32 storage shim, no physics')
 write(OUT/'native-audit.json',audit);return audit

def dense_audit(ball,aim,positions):
 if not positions:return dict(points=0,comparisons=0,minimumMargin=None)
 x=np.linspace(-R.HX+R.R,R.HX-R.R,math.ceil((R.L-2*R.R)/.001)+1);z=np.linspace(-R.HZ+R.R,R.HZ-R.R,math.ceil((R.W-2*R.R)/.001)+1)
 xx,zz=np.meshgrid(x,z);pts=np.stack([xx.ravel(),zz.ravel()],axis=1);scores=R.evaluate(pts,ball,aim)[:,3];mask=np.isfinite(scores)&(scores>=85);pts=pts[mask];scores=scores[mask]
 assert len(pts)>0
 ghost=ball-2*R.R*(aim-ball)/np.linalg.norm(aim-ball);worst=100.
 for c in positions:
  third=np.array(c['position']);best=np.maximum.reduce([np.nan_to_num(R.evaluate(pts,third,a)[:,3],nan=0.) for a in R.ANCHORS[M.pockets(third)]])
  delta=scores-best;assert delta.min()>0
  assert np.linalg.norm(pts-third,axis=1).min()>=2*R.R
  assert F.segment_distance(third,pts,ghost).min()>=2*R.R
  assert F.segment_distance(third,ball,aim)>=2*R.R
  worst=min(worst,float(delta.min()))
 return dict(points=len(pts),comparisons=len(pts)*len(positions),minimumMargin=worst)

def process(s):
 start=time.monotonic();ball=np.array(s['second']);groups=[];filtersec=0;densesec=0
 for pocket in sorted({t['pocket'] for t in s['stops']}):
  tick=time.monotonic();aim=R.ANCHORS[pocket];stops=[dict(t,score=R.evaluate(t['position'],ball,aim).tolist()) for t in s['stops'] if t['pocket']==pocket]
  for t in stops:t['inside']=bool(np.isfinite(t['score'][3]) and t['score'][3]>=85)
  eligible=[t['rank'] for t in stops if t['inside']];results=[]
  candidates=[c for c in s['candidates'] if not c['reasons']]
  if eligible and candidates:
   x=np.arange(-R.HX+R.R,R.HX-R.R,.01);z=np.arange(-R.HZ+R.R,R.HZ-R.R,.01);xx,zz=np.meshgrid(x,z);pts=np.stack([xx.ravel(),zz.ravel()],axis=1);f=R.evaluate(pts,ball,aim)[:,3];pts=pts[np.isfinite(f)&(f>=85)];pts=np.concatenate([pts,np.array([t['position'] for t in stops])])
  for c in s['candidates']:
   if c['reasons']:res=dict(status='initial_rejected')
   elif not eligible:res=dict(status='no_new85_first_route')
   elif F.segment_distance(c['position'],ball,aim)<2*R.R:res=dict(status='rejected',reason='blocks_second_target_path')
   else:
    witness=F.assess_points(pts,ball,aim,np.array(c['position']))
    res=dict(status='rejected',witness=witness) if witness else F.certify(ball,aim,np.array(c['position']))
   results.append(dict(candidate=c['id'],**res))
  filtersec+=time.monotonic()-tick
  groups.append(dict(pocket=pocket,stops=stops,eligibleRanks=eligible,checks=results))
 valid=[];unresolved=[]
 for c in s['candidates']:
  eligible=[g for g in groups if g['checks'][c['id']]['status']=='bounded_pass']
  if eligible:valid.append(dict(c,pocket2Options=[dict(pocket=g['pocket'],firstRouteIDs=[s['stops'][i]['routeID'] for i in g['eligibleRanks']]) for g in eligible]))
  elif any(g['checks'][c['id']]['status']=='unresolved' for g in groups):unresolved.append(c['id'])
 blocks=collections.defaultdict(list)
 for c in valid:blocks[(c['id']//12//2)*6+c['id']%12//2].append(c)
 chosen=[]
 for b,cs in sorted(blocks.items()):chosen.append(rng('second-nonempty-2x2-preview-20261025-v1'+'\0'+identity(s)+'\0'+str(b)).choice(sorted(cs,key=lambda c:c['id'])))
 chosen=sorted(chosen,key=lambda c:c['id']);final=sorted(rng('three-ball-after-block-random3-20261027-v1'+'\0'+identity(s)).sample(chosen,min(3,len(chosen))),key=lambda c:c['id'])
 assert len(final)==min(3,len(blocks)) and len({c['id'] for c in final})==len(final)
 # Every selected position is checked for EACH pocket2 option it retains.
 # A failed dense check aborts the run: never silently drop or resample it.
 tick=time.monotonic()
 for g in groups:
  audited=[c for c in final if g['checks'][c['id']]['status']=='bounded_pass']
  g['dense']=dense_audit(ball,R.ANCHORS[g['pocket']],audited)
  g['dense']['auditedCandidateIDs']=[c['id'] for c in audited]
 densesec+=time.monotonic()-tick
 return dict(sample=s,groups=groups,counts=dict(candidates=72,openingPassed=sum(not c['reasons'] for c in s['candidates']),regionPassed=len(valid),unresolvedPositions=len(unresolved),afterBlock=len(chosen),selected=len(final)),unresolvedIDs=unresolved,blockSelectedIDs=[c['id'] for c in chosen],selectedPositions=final,timing=dict(total=time.monotonic()-start,filter=filtersec,dense=densesec))

def main():
 started=time.monotonic();OUT.mkdir(parents=True,exist_ok=True)
 binding=json.loads((ROOT/'output/three-ball-middle-filter-20261027/source-binding.json').read_text());assert all(sha(ROOT/e['path'])==e['sha256'] for e in binding['production'])
 sourcepaths=[R.SOURCE,M.SOURCE,ROOT/'QiuJi/Core/Scene/AngleSceneCalculator.swift',HERE/'run.py',F.HERE/'filter.py',F.HERE/'pocket_rules.py',R.HERE/'region.py'];frozen={str(p.relative_to(ROOT)):sha(p) for p in sourcepaths}
 samples,prep=prepare();print('PREPARED',prep['seconds'],flush=True);oracle=native_checks(samples);write(OUT/'inputs.json',samples);print('NATIVE',oracle,flush=True)
 tick=time.monotonic();results=[]
 with ProcessPoolExecutor(max_workers=WORKERS) as pool:
  futures={pool.submit(process,s):s['number'] for s in samples}
  for f in as_completed(futures):
   result=f.result();results.append(result);write(OUT/f"sample-{result['sample']['number']:03}.json",result)
   write(OUT/'progress.json',dict(completed=len(results),total=len(samples),seconds=time.monotonic()-tick))
   print('DONE',len(results),result['sample']['number'],result['counts'],round(result['timing']['total'],3),flush=True)
 pooltime=time.monotonic()-tick;results.sort(key=lambda r:r['sample']['number'])
 totals=collections.Counter()
 for r in results:totals.update(r['counts'])
 assert len({identity(r['sample']) for r in results})==128
 assert all(sha(ROOT/p)==h for p,h in frozen.items())
 assert all(sha(ROOT/p)==h for p,h in prep['archiveShardSHA'].items())
 assert sha(INPUT/'selected-bank.jsonl.gz')==prep['sourceSHA']
 summary=dict(passed=True,samples=128,workers=WORKERS,counts=dict(totals),selectedHistogram=dict(collections.Counter(r['counts']['selected'] for r in results)),poolWallSeconds=pooltime,prepareSeconds=prep['seconds'],nativeCheckSeconds=oracle['seconds'],endToEndSeconds=time.monotonic()-started,taskSeconds=sum(r['timing']['total'] for r in results),filterTaskSeconds=sum(r['timing']['filter'] for r in results),denseTaskSeconds=sum(r['timing']['dense'] for r in results),denseComparisons=sum(g['dense']['comparisons'] for r in results for g in r['groups']),regionGroups=sum(len(r['groups']) for r in results),firstRouteRefs=sum(len(s['refs']) for s in samples),sourceHashes=frozen,input=prep,shotSimulations=0,trajectoryExported=False,scoreRegionDefinition='same fixed score>=85 over entire ball-center rectangle; no contour rendering; coarse witnesses + conservative full-domain subdivision + 1mm audit for final selected positions across ALL retained pocket2 options',thirdPocketPolicy='middle-region legal candidate set only; no final designated pocket or second-to-third verification')
 write(OUT/'summary.json',summary);write(OUT/'formations.json',dict(protocol=summary['thirdPocketPolicy'],items=[dict(id=identity(r['sample'])+'/third-cell:'+str(c['id']),board=r['sample']['board'],second=r['sample']['second'],third=c['position'],pocket2Options=c['pocket2Options'],pocket3Candidates=c['legalPockets3']) for r in results for c in r['selectedPositions']]))
 print('SUMMARY',json.dumps({k:v for k,v in summary.items() if k not in ['input','sourceHashes']}),flush=True)
if __name__=='__main__':main()
