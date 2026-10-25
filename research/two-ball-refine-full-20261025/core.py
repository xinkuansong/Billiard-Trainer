from pathlib import Path
import sys,json,gzip,hashlib,time,math,subprocess,traceback,collections,copy
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'research/two-ball-independent125-full-20261024'))
import runtime_common as common
from contract import normalize
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry
from filter_second_ball_preview import score,independent_segment_distance,independent_score
read=lambda p:json.loads(p.read_text())
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'),allow_nan=False))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
D=read(ROOT/'output/two-ball-top5-random-five-20261025/data.json');G=Geometry(**{k:D['geometry'][k] for k in ('length','width','radius')});diameter=G.radius*2
POLICY={'angleMax':25,'similarityThreshold':60,'topK':5,'seedsPerB':8,'velocityDelta':[-.2,-.1,.1,.2],'verticalDelta':[-.06,-.03,.03,.06],'horizontalDelta':[-.03,.03], 'velocityRange':[.6,4.5],'tipRadius':.5,'keepMainRailSequence':True,'seedSelection':'up to 8 collision-clear failing routes closest to 25 degrees; unique main-rail sequences first, then fill by angle','zeroRepair':'zero-side replacements that gain a rail may enter local repair with empty expected rail sequence', 'stagePolicy':'speed first; vertical next; side last for rail routes only; stop refining each seed after first stage with qualifying result; no aim retries','sourceRanking':'OP/cos(cut), pocket options restricted to <=25 degrees before minimum; no first stroke penalty','collision':'post-contact <=2R+.002; precontact chord <=2R; unknown earlier cue contact excluded','coordinates':'world XZ metres; +X right,+Z down on landscape; Y up'}
def events(r):return [e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall']
def railseq(r):return [e['cushionID'] for e in events(r) if e['afterFirstContact'] and e['surface']=='mainRail']
def reason(r):
 if r['status']!='success':return r['status']
 if any(e['surface']!='mainRail' for e in events(r)):return 'jawLinerOrUnknown'
 if any(e['time']<r['firstContactTime'] for e in events(r)):return 'preContactPathUnavailable'
 if not railseq(r) and r['spinX']!=0:return 'noRailSideSpin'
 return None
def nearest(b,path):return min(independent_segment_distance(b,a,c) for a,c in zip(path,path[1:])) if len(path)>1 else math.dist(b,path[0])
def assess(r,b,board):
 path=[p[1:] for p in r['trajectory2mm']['points']]
 if nearest(b,path)<=diameter+.002 or nearest(b,[board['cue'],path[0]])<=diameter:return None,'collision'
 if math.dist(b,r['cueStop'])<diameter:return None,'overlap'
 options=[score(r['cueStop'],b,a,G.radius,i) for i,a in enumerate(G.anchors())]
 eligible=[m for m in options if m['score'] is not None]
 good=[m for m in eligible if m['angle']<=25]
 if good:return min(good,key=lambda m:(m['score'],m['pocket'])),None
 return min(eligible,key=lambda m:(m['angle'],m['score']),default=None),'angle'
def params(r):return (common.f32(r['velocity']),common.f32(r['spinX']),common.f32(r['spinY']))
def category(x,y):return 'center' if x==y==0 else 'vertical' if x==0 else 'horizontal' if y==0 else 'mixed'
def independent_angle(cue,b,a):
 v=[a[i]-b[i] for i in (0,1)];length=math.hypot(*v);n=[v[i]/length for i in (0,1)];ghost=[b[i]-diameter*n[i] for i in (0,1)];inc=[ghost[i]-cue[i] for i in (0,1)];return math.degrees(math.atan2(abs(inc[0]*n[1]-inc[1]*n[0]),inc[0]*n[0]+inc[1]*n[1]))
# Coordinate regression independent of the main cut-angle function.
assert abs(independent_angle([-1,0],[0,0],[1,0]))<1e-10
assert abs(independent_angle([-diameter-1,-1],[0,0],[1,0])-45)<1e-10
assert independent_segment_distance([2,1],[0,0],[1,0])==math.sqrt(2)

def process(old,worker,no,record=None,source_hash=None):
 start=time.perf_counter();idx=old['simulationSource'];source=ROOT/idx['part']
 if record is None:
  receipt=read(ROOT/'output/two-ball-independent125-full-20261024/receipts'/f'{source.name.split(".")[0]}.json');assert sha(source)==receipt['sha256'];source_hash=receipt['sha256']
  record=json.loads(gzip.decompress(source.read_bytes()).splitlines()[idx['rowInPart']])
 assert record['id']==old['id'];board=record['board'];original=[r for r in record['rows'] if r['status']=='success']
 cache={params(r):r for r in original};generated=[];byID={r['comboIndex']:r for r in original};counter=10000;simsec=0.;newstats=collections.Counter();provenance={};requests=[]
 def simulate(specs,stage):
  nonlocal counter,simsec
  pending={}
  for v,x,y,parent in specs:
   key=tuple(common.f32(z) for z in (v,x,y))
   if not .6<=key[0]<=4.5 or key[1]**2+key[2]**2>.25+1e-8:continue
   if key in cache or key in pending:continue
   c={'comboIndex':counter,'tipID':parent.get('tipID',0),'speedID':parent.get('speedID',0),'velocity':key[0],'spinX':key[1],'spinY':key[2]};counter+=1
   pending[key]=(c,parent)
  if pending:
   cs=[c for c,p in pending.values()];batch=worker.run(board,cs);simsec+=batch['elapsedSeconds'];requests.append({'stage':stage,'parameters':cs})
   for r,(key,(c,parent)) in zip(batch['rows'],pending.items(),strict=True):
    normalize(r);r['strokeCategory']=category(r['spinX'],r['spinY']);r['origin']={'stage':stage,'parentComboIndex':parent['comboIndex'],'originalComboIndex':parent.get('origin',{}).get('originalComboIndex',parent['comboIndex'])};provenance[r['comboIndex']]=r['origin'];cache[key]=r;byID[r['comboIndex']]=r;generated.append(r);newstats[r['status']]+=1
    assert r['directionRetries']==0 and r['simulationCalls'] in (0,1)
    if r['status']=='success':
     k=r['trajectory2mm'];assert k['maxDeviationMeters']<=.002+1e-8 and math.dist(k['points'][-1][1:],r['cueStop'])<1e-6
  return [cache[tuple(common.f32(z) for z in (v,x,y))] for v,x,y,p in specs if tuple(common.f32(z) for z in (v,x,y)) in cache]
 # Replay one unmodified row per layout using exactly the frozen solver.
 replaysec=0.
 if original:
  ref=original[0];t=time.perf_counter();rr=worker.run(board,[{k:ref[k] for k in ('comboIndex','tipID','speedID','velocity','spinX','spinY')}])['rows'][0];normalize(rr)
  assert rr['status']==ref['status'] and rr['cueStop']==ref['cueStop'] and rr['trajectory2mm']==ref['trajectory2mm'];replaysec=time.perf_counter()-t
 safe=[r for r in original if old['candidates'] and reason(r) in (None,'noRailSideSpin')];zero=[r for r in safe if not railseq(r) and r['spinX']!=0]
 simulate([(r['velocity'],0,r['spinY'],r) for r in zero],'removeSideSpin')
 base=[];repair=[];basereject=collections.Counter()
 for r in original:
  if r in zero:
   q=cache[(common.f32(r['velocity']),0,common.f32(r['spinY']))]
   why=reason(q) or ('railSequenceChanged' if railseq(q)!=railseq(r) else None)
   if why:
    basereject['zero:'+why]+=1
    if why=='railSequenceChanged':repair.append(q)
   else:base.append(q)
  elif reason(r):basereject[reason(r)]+=1
  else:base.append(r)
 base=list({r['comboIndex']:r for r in base}.values());candidates=[];candidateStats=[]
 for c in old['candidates']:
  b=c['position'];qualified={};failed=[];rejects=collections.Counter()
  for r in base:
   m,why=assess(r,b,board)
   if not why:qualified[r['comboIndex']]={'comboIndex':r['comboIndex'],**m}
   else:
    rejects[why]+=1
    if why=='angle' and m:failed.append((m['angle'],r['comboIndex'],r,railseq(r)))
  for r in repair:
   m,why=assess(r,b,board)
   if m and why in (None,'angle'):failed.append((max(25,m['angle']),r['comboIndex'],r,[]))
  basecount=len(qualified);failed.sort(key=lambda f:(f[0],f[1]));seeds=[];seqs=set()
  for f in failed:
   seq=tuple(f[3])
   if seq not in seqs and len(seeds)<8:seeds.append(f);seqs.add(seq)
  for f in failed:
   if len(seeds)>=8:break
   if f not in seeds:seeds.append(f)
  before=len(generated);tested=set();recovered=0;decisions=[]
  for angle,idx,r,expectedseq in seeds:
   v,x,y=params(r)
   stages=[('speed',[(v+dv,x,y,r) for dv in POLICY['velocityDelta']]),('vertical',[(v+dv,x,y+dy,r) for dy in POLICY['verticalDelta'] for dv in (0,-.1,.1)])]
   if expectedseq:stages.append(('side',[(v+dv,x+dx,y,r) for dx in POLICY['horizontalDelta'] for dv in (0,-.1,.1)]))
   for stage,specs in stages:
    variants=simulate(specs,stage);got=False;checks=[]
    for q in variants:
     tested.add(q['comboIndex'])
     why=reason(q) or ('railSequenceChanged' if railseq(q)!=expectedseq else None)
     if why:checks.append({'comboIndex':q['comboIndex'],'reason':why});continue
     m,why=assess(q,b,board)
     checks.append({'comboIndex':q['comboIndex'],'reason':why})
     if not why:qualified[q['comboIndex']]={'comboIndex':q['comboIndex'],**m};got=True
    decisions.append({'seedComboIndex':r['comboIndex'],'expectedMainRails':expectedseq,'stage':stage,'checks':checks,'stageSucceeded':got})
    if got:recovered+=1;break
  ranked=sorted(qualified.values(),key=lambda q:(q['score'],q['comboIndex']))
  candidates.append({k:copy.deepcopy(v) for k,v in c.items() if k not in ('top5','eligibleCount','rejected')}|{'refineDecisions':decisions,'ranked':ranked,'eligibleCount':len(ranked),'baseEligible25':basecount,'newQualified':len(ranked)-basecount,'seedCount':len(seeds),'rescuedSeedCount':recovered,'baselineRejected':dict(rejects),'tuneUniqueTested':len(tested),'newSimulationsForB':len(generated)-before})
  candidateStats.append({'cellID':c['cellID'],'beforeEligible':c['eligibleCount'],'beforeTop':len(c['top5']),'beforeTopWithin25':sum(q['angle']<=25 for q in c['top5']),'baseEligible25':basecount,'afterEligible':len(ranked),'addedByTune':len(ranked)-basecount})
 used={q['comboIndex'] for c in candidates for q in c['ranked']};nativeInput={'routes':[{'comboIndex':i,'points':byID[i]['trajectory2mm']['points']} for i in sorted(used)],'candidates':[{'cellID':c['cellID'],'ranked':[q['comboIndex'] for q in c['ranked']]} for c in candidates]}
 inp=OUT/f'dedup-{no}-input.json';dst=OUT/f'dedup-{no}-output.json';write(inp,nativeInput);subprocess.run([str(HERE/'dedup'),str(inp),str(dst)],check=True);native=read(dst)
 topUsed=set()
 for c,result,st in zip(candidates,native['results'],candidateStats,strict=True):
  lookup={q['comboIndex']:q for q in c['ranked']};c['top5']=[lookup[i] for i in result['top5']];topUsed.update(result['top5']);st['afterTop']=len(c['top5'])
  for q in c['top5']:
   r=byID[q['comboIndex']];assert not reason(r);assert not assess(r,c['position'],board)[1];assert q['angle']<=25
   independently=independent_angle(r['cueStop'],c['position'],G.anchors()[q['pocket']]);assert abs(independently-q['angle'])<1e-7
   assert math.isclose(q['score'],independent_score(r['cueStop'],c['position'],G.anchors()[q['pocket']],G.radius),rel_tol=1e-9)
 write(OUT/f'generated-{no}.json',{'board':board,'rows':generated,'requests':requests})
 stats={'id':old['id'],'originalSuccess':len(original),'originalJawOrOther':sum(reason(r)=='jawLinerOrUnknown' for r in original),'zeroSideRequests':len(zero),'baseCount':len(base),'baseRejected':dict(basereject),'newSimulationStatus':dict(newstats),'newSimulationCount':len(generated),'workerSeconds':simsec,'replaySeconds':replaysec,'elapsedSeconds':time.perf_counter()-start,'dedupSeconds':native['nativeSeconds'],'candidates':candidateStats,'sourceSHA256':source_hash,'replayExact':True if original else None,'verifiedTopPairs':native['verifiedTopPairs']}
 result={'id':old['id'],'board':board,'defaultCellID':old.get('defaultCellID'),'validFirstShots':len(base),'candidates':candidates,'routes':[byID[i] for i in sorted(topUsed)],'stats':stats}
 write(OUT/f'result-{no}.json',result)
 return result
