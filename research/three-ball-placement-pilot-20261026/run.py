from pathlib import Path
import gzip,json,os,select,subprocess,sys,time,traceback,collections,math
import experiment as E
ROOT,HERE,OUT=E.ROOT,E.HERE,E.OUT
class Worker:
 def __init__(self,uid,binary):
  self.log=(OUT/'native.log').open('w');self.raw=gzip.open(OUT/'raw.jsonl.gz','wt',compresslevel=6);self.count=0;self.kinds=collections.Counter()
  self.p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
  self.ready=self.receive('READY');E.write(OUT/'metadata.json',self.ready)
 def receive(self,tag):
  deadline=time.monotonic()+120
  while time.monotonic()<deadline:
   if not select.select([self.p.stdout],[],[],max(0,deadline-time.monotonic()))[0]:break
   line=self.p.stdout.readline()
   if not line:raise RuntimeError('worker exited '+str(self.p.poll()))
   if line.startswith(tag+'\t'):return json.loads(line.split('\t',1)[1])
   if line.startswith('ERROR\t'):raise RuntimeError(line)
   self.log.write(line);self.log.flush()
  raise TimeoutError('Native response exceeded 120s')
 def run(self,q,kind):
  self.p.stdin.write(json.dumps(q,separators=(',',':'))+'\n');self.p.stdin.flush();r=self.receive('RESULT');self.count+=1;self.kinds[kind]+=1
  self.raw.write(json.dumps(dict(kind=kind,request=q,result=r),separators=(',',':'),allow_nan=False)+'\n');self.raw.flush()
  if self.count%100==0:E.write(OUT/'progress.json',dict(requests=self.count,kinds=dict(self.kinds),updatedAt=time.time()))
  return r
 def close(self):
  self.p.stdin.close()
  try:self.p.wait(timeout=15)
  except subprocess.TimeoutExpired:self.p.terminate();self.p.wait(timeout=15)
  self.raw.close();self.log.close();return self.p.returncode

def request(id,cue,obj,pocket,param,obstacles=(),aim=None):
 return dict(id=id,cue=cue,object=obj,pocket=pocket,aim=aim or E.ANCHORS[pocket],obstacles=list(obstacles),**{k:param[k] for k in ['v','sx','sy']},**({'dir':param['dir']} if 'dir' in param else {}))

def main(uid):
 assert not (OUT/'raw.jsonl.gz').exists(),'Do not overwrite observations'
 build=subprocess.run(['make','-C',str(HERE),'build'],capture_output=True,text=True)
 (OUT/'build-launch.log').write_text(build.stdout+build.stderr)
 if build.returncode:raise RuntimeError(build.stdout+build.stderr)
 binary=Path(os.environ['QIUJI_TEST_WORK'])/'ThreeBallWorker.app/Worker'
 E.write(OUT/'run-start.json',dict(device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE'],startedAt=time.time(),protocolSHA=E.sha(OUT/'protocol.json')))
 w=None;boot=False;success=False;started=time.monotonic()
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
  w=Worker(uid,binary);assert all(w.ready[k]==E.G[k] for k in ('length','width','radius'))
  protocol=E.read(OUT/'protocol.json');samples=E.read(OUT/'samples.json');allresults=[]
  for s in samples:
   print('BASE',s['number'],s['id'],flush=True);board=s['board'];bases=[];secondSets={}
   # Pin current parameter sources and compare each first stop to the full-bank research backup.
   oldpath=ROOT/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'/(s['shard']+'.jsonl.gz')
   oldrows=[json.loads(l) for l in gzip.decompress(oldpath.read_bytes()).splitlines()];old=next(r for r in oldrows if r['id']==s['id']);oldroutes={r['comboIndex']:r for r in old['routes']}
   s['referenceSHA']=E.sha(oldpath)
   for j,(param,ref) in enumerate(zip(s['routes'],s['refs'])):
    q=request(f"s{s['number']}-first{j}",board['cue'],board['object'],board['pocket'],param,[s['second']],board['aim']);r=w.run(q,'first_baseline')
    b=dict(rank=j,parameter=param,pocket2=ref[1],request=q,result=r);bases.append(b)
    if not r['success']:continue
    assert r['rails']==param['rails']
    assert math.dist(r['stop'],oldroutes[param['id']]['cueStop'])<.000001,(s['number'],j,'source stop drift')
    co=E.comfort(r['stop'],s['second'],ref[1]);assert co and co['total']>=85
    candidates=[];stats=collections.Counter()
    for v in protocol['secondSearch']['speeds']:
     for sx,sy in protocol['secondSearch']['spins']:
      idx=len(candidates)+sum(stats.values());p=dict(v=v,sx=sx,sy=sy)
      q2=request(f"s{s['number']}-r{j}-v{v}-x{sx}-y{sy}",r['stop'],s['second'],ref[1],p)
      r2=w.run(q2,'second_search')
      if r2['success'] and (r2['rails'] or r2['sx']==0):candidates.append(dict(request=q2,result=r2))
      else:stats['no_rail_side_spin' if r2['success'] else r2['reason']]+=1
    secondSets[j]=candidates;b['searchCounts']=dict(success=len(candidates),rejected=dict(stats));print(' SECOND',j,len(candidates),dict(stats),flush=True)
   legal=w.run(dict(command='legal',points=[c['position'] for c in s['candidates']]),'placement_legal')['legal']
   results=[]
   for c,nativeOK in zip(s['candidates'],legal):
    c=dict(c);c['reasons']=list(c['reasons']);c['nativePlacementLegal']=nativeOK
    if not nativeOK:c['reasons'].insert(0,'pocket_or_rail_placement')
    c['chains']=[];c['routeChecks']=[]
    if c['reasons']:c['status']='initial_rejected';results.append(c);continue
    third=c['position'];firstOK=0;qualifiedMatches=0
    for b in bases:
     j=b['rank'];base=b['result'];rc=dict(firstRank=j,status='baseline_failed',secondMatches=0,attemptedSecond=0,attemptedThird=0);c['routeChecks'].append(rc)
     if not base['success']:continue
     q1=dict(b['request'],id=f"s{s['number']}-c{c['id']}-r{j}-first",obstacles=[s['second'],third]);r1=w.run(q1,'first_with_third')
     if not r1['success']:rc['status']='first_'+r1['reason'];continue
     if r1['rails']!=b['parameter']['rails'] or math.dist(r1['stop'],base['stop'])>.000001:
      rc['status']='first_state_changed';continue
     firstOK+=1;rc['status']='no_qualified_second_match';matches=[]
     for trial in secondSets.get(j,[]):
      r2=trial['result']
      if not E.path_clear(third,r2['cuePath']) or not E.path_clear(third,r2['targetPath']):continue
      for p3 in range(6):
       co=E.comfort(r2['stop'],third,p3)
       if co and co['total']>=85:matches.append((E.effort(r2),-co['total'],p3,trial,co))
     matches.sort(key=lambda x:(x[0],x[1],x[2],x[3]['request']['id']));rc['secondMatches']=len(matches);qualifiedMatches+=len(matches)
     # Multiple pockets can share the same second-parameter trial. Cache its full replay.
     cache={}
     for _,_,p3,trial,co in matches[:24]:
      key=trial['request']['id']
      if key not in cache:
       q2=dict(trial['request'],id=f"s{s['number']}-c{c['id']}-r{j}-second-{len(cache)}",cue=r1['stop'],obstacles=[third],dir=trial['result']['dir']);r2=w.run(q2,'second_with_third');cache[key]=(q2,r2);rc['attemptedSecond']+=1
      q2,r2=cache[key]
      if not r2['success']:continue
      actual=E.comfort(r2['stop'],third,p3)
      if not actual or actual['total']<85:continue
      # Use the actual unchanged remaining ball coordinates from each prior result.
      cActual=r2['finals']['obstacle0']
      for speed in protocol['thirdFinish']['speeds']:
       q3=request(f"s{s['number']}-c{c['id']}-r{j}-third-{rc['attemptedThird']}",r2['stop'],cActual,p3,dict(v=speed,sx=0,sy=0));r3=w.run(q3,'third_finish');rc['attemptedThird']+=1
       if r3['success']:
        c['chains'].append(dict(firstRank=j,pocket2=b['pocket2'],pocket3=p3,comfort3=actual,shots=[dict(request=q1,result=r1),dict(request=q2,result=r2),dict(request=q3,result=r3)]));rc['status']='validated';break
      if rc['status']=='validated':break
     if matches and rc['status']!='validated':rc['status']='bounded_search_unresolved'
     if len(c['chains'])>=3:break
    c['firstSurvivingRoutesTested']=firstOK;c['qualifiedSecondMatchesTested']=qualifiedMatches
    c['status']='validated' if c['chains'] else ('first_routes_rejected' if firstOK==0 else 'continuation_not_found')
    results.append(c)
    if c['id']%12==0:print(' POSITION',s['number'],c['id'],c['status'],len(c['chains']),flush=True)
   result=dict(sample=s,baselines=bases,secondSearch=secondSets,candidates=results,counts=dict(collections.Counter(c['status'] for c in results)))
   E.write(OUT/f"sample-{s['number']}.json",result);allresults.append(result)
   E.write(OUT/'progress.json',dict(samplesComplete=len(allresults),requests=w.count,kinds=dict(w.kinds),counts=[x['counts'] for x in allresults]));print('SAMPLE_DONE',s['number'],result['counts'],flush=True)
  # Independent from-start replay of every selected representative, max3 placements per sample.
  replays=[]
  for result in allresults:
   valid=[c for c in result['candidates'] if c['chains']]
   chosen=[valid[i] for i in sorted(set([0,len(valid)//2,len(valid)-1]))] if valid else []
   for c in chosen:
    chain=c['chains'][0];last=None;checks=[]
    for no,shot in enumerate(chain['shots']):
     q=dict(shot['request'],id='replay-'+shot['request']['id'])
     if last:q['cue']=last['stop']
     rr=w.run(q,'independent_chain_replay');assert rr['success']
     for field in ['stop','rails','events','finals','cuePath','targetPath']:assert rr[field]==shot['result'][field],(q['id'],field)
     checks.append(dict(shot=no+1,exact=True));last=rr
    replays.append(dict(sample=result['sample']['number'],candidate=c['id'],shots=checks))
  E.write(OUT/'replay-audit.json',dict(passed=True,replays=replays))
  binding=E.read(OUT/'source-binding.json');assert all(E.sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
  assert E.sha(E.BANK/'index.json')==protocol['bankIndexSHA']
  for s in samples:assert E.sha(E.BANK/(s['shard']+'.jsonl.gz'))==s['sourceSHA']
  totals=collections.Counter()
  for r in allresults:totals.update(r['counts'])
  E.write(OUT/'generation.json',dict(complete=True,samples=5,positions=360,counts=dict(totals),chains=sum(len(c['chains']) for r in allresults for c in r['candidates']),requests=w.count,kinds=dict(w.kinds),seconds=time.monotonic()-started,sourceUnchanged=True))
  success=True
 finally:
  code=w.close() if w else None
  shutdown=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
  E.write(OUT/'closure.json',dict(generationSucceeded=success,nativeExitCode=code,nativePID=w.ready['pid'] if w else None,shutdownExitCode=shutdown.returncode if shutdown else None,device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
  if code is not None:assert code==0
  if shutdown:assert shutdown.returncode==0,shutdown.stderr
if __name__=='__main__':
 try:main(sys.argv[1])
 except BaseException:E.write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise
