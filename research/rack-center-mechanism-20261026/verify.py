from pathlib import Path
import gzip,json,math,hashlib,statistics,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-center-mechanism-20261026'
D=json.loads((OUT/'derived.json').read_text());A=json.loads((OUT/'analysis.json').read_text());byid={r['id']:r for r in D['rows']};C=json.loads((OUT/'calibration.json').read_text());M=json.loads((OUT/'metadata.json').read_text());L,W,R=[M[k] for k in ['length','width','radius']]
old={}
for p in (ROOT/'output/rack-pattern-5000-20261026').glob('raw-*.jsonl'):
 for line in p.read_text().splitlines():
  r=json.loads(line)
  if r['input']['position']=='center':old[r['input']['rackID']]=r
seen=set();rows=0;replayed=0;unmatched=[];single=[];minOther=1e9;energy=[0.]*15;initialContactCounts=[]
for p in sorted(OUT.glob('raw-*.jsonl.gz')):
 with gzip.open(p,'rt') as f:
  for line in f:
   r=json.loads(line);i=r['input']['rackID'];ref=byid[i];assert i not in seen;seen.add(i);rows+=1
   assert r['status']=='settled' and r['input']['position']=='center' and r['input']['z']==0 and r['input']['power']==9.75
   if i<1000:
    for field in ['rack','cue','power','direction','status','termination','pocketed','board']:assert r[field]==old[i][field]
    replayed+=1
   assert len(r['rack'])==15
   pts=[(b['x'],b['z']) for b in r['rack']]
   assert min(math.dist(x,y) for j,x in enumerate(pts) for y in pts[j+1:])>=2*R-1e-7
   t=[(v[0]*L-L/2,v[1]*L-W/2) for k,v in r['board'].items() if k!='cueBall']
   score=statistics.mean(min(math.dist(x,y) for k,y in enumerate(t) if k!=j) for j,x in enumerate(t))/C['reference'][str(len(t))]['expectedMeanM']
   assert abs(score-ref['index'])<1e-12 and (score>=1.2)==bool(ref['success'])
   assert set(r['board'])|set(r['pocketed'])==set(r['names']) and not set(r['board'])&set(r['pocketed'])
   times=[e['t'] for e in r['impulseTrace']];assert all(a<=b for a,b in zip(times,times[1:]))
   name={k:j-1 for j,k in enumerate(r['names'])};sounds=[e for e in r['contacts'] if e['kind']=='ball']
   for event in r['impulseTrace']:
    ch=event['changed'];keys={c['slot'] for c in ch}
    if len(ch)==1:
     c=ch[0];assert max(abs(v) for v in c['postV'])==0 and math.sqrt(sum(v*v for v in c['preV']))<.001
     single.append(dict(rackID=i,t=event['t'],kind='single-ball stop transition',speed=math.sqrt(sum(v*v for v in c['preV']))));continue
    assert len(ch)==2
    residual=math.sqrt(sum(sum(c['postV'][k]-c['preV'][k] for c in ch)**2 for k in range(3)));assert residual<1e-5
    delta=sum(.5*.17*sum(c['postV'][k]**2-c['preV'][k]**2 for k in range(3))+.17*R*R/5*sum(c['postW'][k]**2-c['preW'][k]**2 for k in range(3)) for c in ch);assert delta<=1e-6
    if not any(e['t']==event['t'] and {name[e['a']],name[e['b']]}==keys for e in sounds):
     # Sound collection filters non-positive approach speeds. Preserve all actual velocity jumps.
     dp=[ch[1]['p'][k]-ch[0]['p'][k] for k in range(3)];norm=math.sqrt(sum(x*x for x in dp));approach=sum((ch[0]['preV'][k]-ch[1]['preV'][k])*dp[k] for k in range(3))/norm
     unmatched.append(dict(rackID=i,t=event['t'],slots=sorted(keys),approach=approach,energyChange=delta,momentumResidual=residual))
   firstOther=min([e['t'] for e in r['contacts'] if e['kind']!='ball'] or [1e9]);minOther=min(minOther,firstOther)
   assert firstOther>.005,'Primary mechanism snapshot must precede cushions'
   sample=r['samples'][1];assert abs(sample['delay']-.005)<1e-8
   st=sample['states'][1:];energies=[.5*.17*sum(v*v for v in b['v']) for b in st];total=sum(energies);inside=sum(energies[k] for k in [4,7,8]);effective=total**2/sum(e*e for e in energies)
   pps=[b['p'] for b in st];nearest=[min(math.dist(x,y) for j,y in enumerate(pps) if j!=k)-2*R for k,x in enumerate(pps)]
   assert abs(inside/total-ref['dynamic']['t5_interior_energy_share'])<1e-10
   assert abs(effective-ref['dynamic']['t5_effective_energized_balls'])<1e-10
   assert abs(statistics.mean(nearest[k] for k in [4,7,8])*1000-ref['dynamic']['t5_interior_gap_mm'])<1e-8
   if i>=1000:
    for j,e in enumerate(energies):energy[j]+=e/total/1000
assert rows==2000 and replayed==1000
for c in A['candidates']:
 for split in ['train','holdout']:
  rr=[r for r in D['rows'] if r['split']==split];selected=[r for r in rr if all((r['static'][p['feature']]<=p['threshold'])==p['le'] for p in c['conditions'])]
  expected=c[split]['selected'];assert len(selected)==expected['n'] and sum(r['success'] for r in selected)==expected['successes']
closed=json.loads((OUT/'closure.json').read_text());assert closed['generationSucceeded'] and closed['shutdownExitCode']==0 and all(c['exitCode']==0 for c in closed['workers'])
binding=json.loads((OUT/'source-binding.json').read_text());drift=[x['path'] for x in binding['production'] if hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()!=x['sha256']];assert not drift
run=json.loads((ROOT/'output/local-test-runs/bd4db7a81a33415d87458eab8cffb35b/run.json').read_text());assert run['state']=='reclaimed'
verification=dict(passed=True,independentlyScored=rows,oldExactReplays=replayed,primary5msScalarRecomputed=rows,allCandidateGroupsRecomputed=True,minFirstNonBallContactSeconds=minOther,holdoutEnergyShareBySlot=energy,sourceBindingDrift=drift,nonAudioPairImpulses=unmatched,singleBallTransitions=single,explanation='Order uses the two-ball velocity jumps, threshold1e-5m/s. Sound events are not a complete collision ledger: they require positive approach. One single-ball stopping transition excluded from collision accounting. No rack was excluded. Static candidate thresholds and primary mechanism bins remain identical to the original lock.',lifecycle=dict(id=run['id'],state=run['state'],exit_code=run['exit_code']))
(OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in verification.items() if k not in ['holdoutEnergyShareBySlot','nonAudioPairImpulses']},ensure_ascii=False));print('non-audio pair impulses',unmatched)
