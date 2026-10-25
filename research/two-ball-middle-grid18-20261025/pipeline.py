from pathlib import Path
import collections,copy,gzip,hashlib,itertools,json,math,os,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'research/two-ball-refine-full-20261025'))
import core as C
common=C.common
SOURCE=ROOT/'output/two-ball-refine-full-20261025'
A=ROOT/'output/two-ball-middle-filter-20261025';B=ROOT/'output/two-ball-grid18-20261025'
KEYS=('comboIndex','trialID','strokeCategory','velocity','spinX','spinY','strikeDirection','aimOffsetRadians','cueStop','cueMainRailsAfterContact','cueJawsAfterContact','cueOtherCushionsAfterContact','trajectory2mm','origin')
POLICY={'version':1,'inputLayouts':13570,'inputB':173577,'inputRecommendations':816076,'middlePockets':[4,5],'middleValidation':{'centerHit':True,'fixedGhostDirection':True,'adaptiveSpeedsMax':5,'speedRange':[.5,8.0],'requires':'direct selected pot; complete simulation; no scratch; accessible center strike','failureMeans':'failed bounded validation, not mathematical impossibility','replaceFailedPocketInStageA':False},'grid':{'speedDelta':[-.3,-.2,-.1,0,.1,.2,.3],'verticalDelta':[-.15,-.1,-.05,0,.05,.1,.15],'sideDelta':[-.1,-.05,0,.05,.1],'speedRange':[.6,4.5],'tipRadius':.5,'maxPerRoot':245,'earlyStop':False},'angleMax':18,'keepMainRailCountAndOrder':True,'stateChange':'reject before difficulty scoring','zeroRailSideSpin':0,'jawRoutes':'reject','collisionMarginMeters':.002,'roots':'stage A surviving recommendations only','ranking':'minimum second-shot OP/cos(cut); verify middle options; ascending S then comboIndex; union of every eligible grid variant; greedy P2>=60 dedup top5','secondPocketDuringGrid':'best of six physically screened middle / geometrical corner options within18','originalsUnchanged':True}
def enc(v):return json.dumps(v,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
def read(p):return json.loads(p.read_text())
def sha(p):return common.sha(p)
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);t=p.with_name(p.name+'.tmp');t.write_bytes(enc(v));os.replace(t,p)
def seq(r):
 s=[v['cushionID'] for v in r['trajectory2mm']['cushions']]
 assert len(s)==r['cueMainRailsAfterContact'] and all(type(i)==int and 0<=i<6 for i in s)
 return tuple(s)
def compact(r):return {k:r[k] for k in KEYS if k in r}
def inc(d,k,n=1):d[str(k)]=d.get(str(k),0)+n
def merge(a,b):
 for k,v in b.items():
  if isinstance(v,dict):merge(a.setdefault(k,{}),v)
  else:a[k]=a.get(k,0)+v
 return a
class Middle:
 def __init__(self,w):self.w=w;self.cache={};self.proofs=[]
 def request(self,cue,b,pocket):
  vals=[*[common.f32(x) for x in cue],*[common.f32(x) for x in b],pocket]
  key=hashlib.sha256(enc(vals)).hexdigest()
  return {'key':key,'cue':cue,'object':b,'pocket':pocket,'aim':C.G.anchors()[pocket]}
 def evaluate(self,requests):
  pending={r['key']:r for r in requests if r['key'] not in self.cache}
  values=list(pending.values())
  for i in range(0,len(values),32):
   batch=values[i:i+32];self.w.p.stdin.write(enc({'command':'middle','requests':batch}).decode()+'\n');self.w.p.stdin.flush()
   results=self.w.receive('RESULT',180)['results'];assert len(results)==len(batch)
   for req,r in zip(batch,results,strict=True):
    assert r['key']==req['key'] and r['request']['pocket'] in (4,5)
    assert len(r['trials'])<=5
    assert r['passed']==any(t['passed'] for t in r['trials'])
    for t in r['trials']:
     if t['passed']:assert t['settled'] and t['targetPotted'] and not t['cuePocketed'] and t['route']=='direct-pot'
    self.cache[req['key']]=r;self.proofs.append(r)
  return [self.cache[r['key']] for r in requests]
 def one(self,cue,b,p):return self.evaluate([self.request(cue,b,p)])[0]

def stage_a(old,w,tmp):
 started=time.perf_counter();out=copy.deepcopy(old);routes={r['comboIndex']:r for r in old['routes']};m=Middle(w)
 requests=[m.request(routes[q['comboIndex']]['cueStop'],c['position'],q['pocket']) for c in old['candidates'] for q in c['top5'] if q['pocket'] in (4,5)]
 m.evaluate(requests);deleted=[];used=set();stats={'layouts':1,'BPositions':len(old['candidates']),'beforeTop':sum(len(c['top5']) for c in old['candidates']),'middleChecked':0,'deleted':0,'afterTop':0,'topCountHistogram':{},'middlePassed':0,'unchangedCorner':0}
 for c in out['candidates']:
  keep=[]
  for q in c['top5']:
   if q['pocket'] in (4,5):
    p=m.one(routes[q['comboIndex']]['cueStop'],c['position'],q['pocket']);stats['middleChecked']+=1
    if not p['passed']:
     deleted.append({'cellID':c['cellID'],'recommendation':q,'proofKey':p['key']});stats['deleted']+=1;continue
    q['middleProofKey']=p['key'];stats['middlePassed']+=1
   else:stats['unchangedCorner']+=1
   keep.append(q);used.add(q['comboIndex'])
  c['beforeMiddleFilterTopCount']=len(c['top5']);c['top5']=keep;c['middleFilterTopCount']=len(keep);inc(stats['topCountHistogram'],len(keep));stats['afterTop']+=len(keep)
 out['routes']=[r for r in old['routes'] if r['comboIndex'] in used];out['schema']='two-ball-middle-validated-top5-v1'
 out['previousStats']=out.pop('stats');out['stats']=stats
 stats['middleUniqueRequests']=len(m.proofs);stats['middleSimulationCalls']=sum(len(r['trials']) for r in m.proofs);stats['layoutSeconds']=time.perf_counter()-started
 assert stats['beforeTop']==stats['afterTop']+stats['deleted']
 trace={'id':old['id'],'deleted':deleted,'middleProofs':m.proofs,'stats':stats}
 return out,trace,stats

def grid(root):
 v,x,y=C.params(root);n=0;pruned=collections.Counter();keys=[]
 for dv,dy,dx in itertools.product(POLICY['grid']['speedDelta'],POLICY['grid']['verticalDelta'],POLICY['grid']['sideDelta']):
  n+=1;k=tuple(common.f32(t) for t in (v+dv,x+dx,y+dy))
  if not .6<=k[0]<=4.5:pruned['velocityOutOfRange']+=1
  elif k[1]**2+k[2]**2>.25+1e-8:pruned['tipOutsideDisk']+=1
  elif not seq(root) and k[1]!=0:pruned['zeroRailSideSpin']+=1
  else:keys.append(k)
 assert n==245 and len(keys)+sum(pruned.values())==245
 assert C.params(root) in keys
 return keys,dict(pruned)

def candidate_options(r,b,board):
 path=[p[1:] for p in r['trajectory2mm']['points']]
 if C.nearest(b,path)<=C.diameter+.002 or C.nearest(b,[board['cue'],path[0]])<=C.diameter:return [],'collision'
 options=[C.score(r['cueStop'],b,a,C.G.radius,i) for i,a in enumerate(C.G.anchors())]
 options=[v for v in options if v['score'] is not None and v['angle']<=18]
 return sorted(options,key=lambda q:(q['score'],q['pocket'])),None if options else 'angle'

def stage_b(old,w,tmp):
 started=time.perf_counter();roots={r['comboIndex']:r for r in old['routes']};cache={C.params(r):r for r in old['routes']};originalKeys=set(cache);rootkeys={};rootReject={};allkeys={};nativeStatus=collections.Counter()
 for i,r in roots.items():
  keys,prune=grid(r);rootkeys[i]=keys;rootReject[i]=prune
  for k in keys:allkeys.setdefault(k,i)
 # Replay the unchanged origin to prove the new entry keeps first-shot physics exact.
 if roots:
  r=next(iter(roots.values()));cs={k:r[k] for k in ('comboIndex','velocity','spinX','spinY')};cs.update(tipID=0,speedID=0)
  rr=w.run(old['board'],[cs])['rows'][0];C.normalize(rr)
  assert rr['status']=='success' and rr['cueStop']==r['cueStop'] and rr['trajectory2mm']==r['trajectory2mm']
 pending=[k for k in allkeys if k not in cache];nextID=max(roots,default=0)+1;newEvidence=[];newRows={};failedReasons={}
 for off in range(0,len(pending),64):
  ks=pending[off:off+64];cs=[{'comboIndex':nextID+j,'tipID':0,'speedID':0,'velocity':k[0],'spinX':k[1],'spinY':k[2]} for j,k in enumerate(ks)];nextID+=len(cs)
  batch=w.run(old['board'],cs)
  for k,r in zip(ks,batch['rows'],strict=True):
   C.normalize(r);nativeStatus[r['status']]+=1
   why=C.reason(r);r['strokeCategory']=C.category(r['spinX'],r['spinY'])
   ev={'comboIndex':r['comboIndex'],'parameters':list(k),'status':r['status'],'reject':why,'simulationCalls':r['simulationCalls']}
   if not why:ev['railSequence']=list(seq(r));cache[k]=compact(r);newRows[r['comboIndex']]=cache[k]
   else:cache[k]={'comboIndex':r['comboIndex'],'reject':why};failedReasons[k]=why
   newEvidence.append(ev)
 byID={r['comboIndex']:r for r in cache.values() if 'reject' not in r};m=Middle(w)
 for proof in old.get('_middleProofs',[]):m.cache[proof['key']]=proof
 cands=[];decisions=[];stats={'layouts':1,'BPositions':len(old['candidates']),'beforeTop':sum(len(c['top5']) for c in old['candidates']),'afterTop':0,'topCountHistogram':{},'railHistogram':{},'categoryHistogram':{},'roots':len(roots),'rawGridPoints':len(roots)*245,'uniqueGridParameters':len(allkeys),'newSimulations':len(pending),'nativeStatus':dict(nativeStatus),'rejectedBeforeScoring':{},'eligiblePairs':0,'replayExact':int(bool(roots))}
 for c in old['candidates']:
  # Crucially, compare each variant's state to its own root before any difficulty score.
  valid={};rootChecks=[]
  for ref in c['top5']:
   root=roots[ref['comboIndex']];expected=seq(root);reject=collections.Counter(rootReject[root['comboIndex']]);ids=[]
   for k in rootkeys[root['comboIndex']]:
    r=cache[k]
    why=r.get('reject')
    if why is None and seq(r)!=expected:why='railStateChanged'
    if why:reject[why]+=1;continue
    ids.append(r['comboIndex']);valid.setdefault(r['comboIndex'],[]).append(root['comboIndex'])
   rootChecks.append({'rootComboIndex':root['comboIndex'],'expectedRails':list(expected),'gridTotal':245,'beforeScoringRejected':dict(reject),'statePreservingVariants':ids})
   for why,n in reject.items():inc(stats['rejectedBeforeScoring'],why,n)
  ranked=[];checks={};middleDeleted=0
  for i,parents in valid.items():
   r=byID[i];options,why=candidate_options(r,c['position'],old['board']);chosen=None;proofkey=None
   for opt in options:
    if opt['pocket'] in (4,5):
     proof=m.one(r['cueStop'],c['position'],opt['pocket'])
     if not proof['passed']:middleDeleted+=1;continue
     proofkey=proof['key']
    chosen=opt;break
   if chosen:
    q={'comboIndex':i,**chosen,'rootComboIndices':parents}
    if proofkey:q['middleProofKey']=proofkey
    ranked.append(q);checks[i]={'eligible':True}
   else:checks[i]={'eligible':False,'reason':why or 'middleValidationFailed'}
  ranked.sort(key=lambda q:(q['score'],q['comboIndex']))
  for ch in rootChecks:
   assert sum(ch['beforeScoringRejected'].values())+len(ch['statePreservingVariants'])==245
   choice=next((q for q in ranked if ch['rootComboIndex'] in q['rootComboIndices']),None)
   ch['optimal']=choice
  # Only compact candidate metadata in the final corpus; full ranked/cause evidence is separate.
  outc={k:copy.deepcopy(v) for k,v in c.items() if k not in ('top5','eligibleCount')}
  outc.update(eligibleCount=len(ranked),ranked=ranked);cands.append(outc);stats['eligiblePairs']+=len(ranked)
  decisions.append({'cellID':c['cellID'],'roots':rootChecks,'checks':checks,'ranked':ranked,'middleFailedPocketOptions':middleDeleted})
 used={q['comboIndex'] for c in cands for q in c['ranked']}
 din={'routes':[{'comboIndex':i,'points':byID[i]['trajectory2mm']['points']} for i in sorted(used)],'candidates':[{'cellID':c['cellID'],'ranked':[q['comboIndex'] for q in c['ranked']]} for c in cands]}
 write(tmp/'dedup-in.json',din);subprocess.run([str(ROOT/'research/two-ball-refine-full-20261025/dedup'),str(tmp/'dedup-in.json'),str(tmp/'dedup-out.json')],check=True,capture_output=True);native=read(tmp/'dedup-out.json');topused=set()
 for c,n in zip(cands,native['results'],strict=True):
  lookup={q['comboIndex']:q for q in c.pop('ranked')};c['top5']=[lookup[i] for i in n['top5']];inc(stats['topCountHistogram'],len(c['top5']));stats['afterTop']+=len(c['top5'])
  for q in c['top5']:
   r=byID[q['comboIndex']];topused.add(q['comboIndex']);inc(stats['railHistogram'],r['cueMainRailsAfterContact']);inc(stats['categoryHistogram'],r['strokeCategory'])
   assert q['angle']<=18 and abs(C.independent_angle(r['cueStop'],c['position'],C.G.anchors()[q['pocket']])-q['angle'])<1e-7
   for rootid in q['rootComboIndices']:assert seq(r)==seq(roots[rootid])
 stats['verifiedTopPairs']=native['verifiedTopPairs'];stats['middleUniqueRequests']=len(m.proofs);stats['middleSimulationCalls']=sum(len(p['trials']) for p in m.proofs);stats['layoutSeconds']=time.perf_counter()-started
 out={k:copy.deepcopy(v) for k,v in old.items() if k not in ('routes','candidates','stats','previousStats','_middleProofs')};out.update(schema='two-ball-grid18-state-preserved-p2-60-top5-v1',routes=[byID[i] for i in sorted(topused)],candidates=cands,stats=stats)
 trace={'id':old['id'],'roots':[compact(r) for r in roots.values()],'gridTrials':newEvidence,'candidates':decisions,'middleProofs':m.proofs,'stats':stats}
 return out,trace,stats
