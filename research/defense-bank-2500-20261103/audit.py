"""Full independent audit. Run with audit-env/bin/python (NumPy)."""
from pathlib import Path
import ast, collections, hashlib, json, math, os, sys, tarfile
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ.get('DEFENSE_PILOT_OUTPUT',str(ROOT/'output/defense-bank-2500-20261103')))
partial='--partial' in sys.argv
geom=json.loads((OUT/'geometry.json').read_text());R=geom['radius'];L=geom['length'];W=geom['width'];CUE=geom['cueKey']
for file,names in [('research/defense-pilot-20261103/review.py',['comfort']),('research/defense-three-20261103/review.py',['proof'])]:
    for node in ast.parse((ROOT/file).read_text()).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:exec(compile(ast.Module(body=[node],type_ignores=[]),file,'exec'))

def sweep(c,bs,t):
    c=np.asarray(c);t=np.asarray(t);bs=np.asarray(bs)
    delta=t-c;distance=np.linalg.norm(delta);half=math.asin(2*R/distance)
    angles=np.linspace(math.atan2(delta[1],delta[0])-half,math.atan2(delta[1],delta[0])+half,4097)
    directions=np.stack((np.cos(angles),np.sin(angles)),axis=1)
    # Independent quadratic line/disc first intersection with expanded 2R circles.
    points=np.vstack((t,bs));offset=c-points
    linear=2*offset@directions.T;constant=(offset*offset).sum(axis=1)[:,None]-(2*R)**2
    disc=linear*linear-4*constant
    near=(-linear-np.sqrt(np.maximum(0,disc)))/2
    near=np.where((disc>=-1e-11)&(near>=0),near,np.inf)
    assert np.isfinite(near[0]).all()
    return int(np.count_nonzero(near[1:].min(axis=0)>=near[0]))

assert proof([0,0],[[.25,-.05],[.25,.05]],[1,0])[0]
assert sweep([0,0],[[.25,-.05],[.25,.05]],[1,0])==0
assert all(sweep([0,0],[b],[1,0])>0 for b in [[.25,-.05],[.25,.05]])
assert not proof([0,0],[[.5,-.065],[.5,.065]],[1,0])[0]
assert sweep([0,0],[[.5,-.065],[.5,.065]],[1,0])>0
assert sweep([0,0],[[1.3,0]],[1,0])==4097
assert proof([0,0],[[.25,0]],[1,0])[0]

def check_positions(ps,keys):
    assert set(ps)==set(keys)
    values=list(ps.values())
    for i,p in enumerate(values):
        assert len(p)==2 and all(math.isfinite(v) for v in p)
        assert abs(p[0])<=L/2-R+1e-5 and abs(p[1])<=W/2-R+1e-5
        for q in values[i+1:]:assert math.dist(p,q)>=2*R-1e-5

def audit(q,r,full_required=False,teaching=False,tracks=False):
    own,enemy=q['ownKey'],q['enemyKey'];keys=list(q['positions']);ps=r['positions'];check_positions(ps,keys)
    blockers=[own]+(['_8'] if len(keys)==4 else [])
    c,t=ps[CUE],ps[enemy];bs=[ps[k] for k in blockers]
    assert r['settled'] and not r['pocketed'] and not any(e['kind']=='pocket' for e in r['events'])
    hit=next(e for e in r['events'] if e['kind']=='ballBall')
    assert set(hit['balls'])=={CUE,own}
    assert not any(e['kind']=='ballBall' and CUE in e['balls'] and set(e['balls'])!={CUE,own} and e['time']<=hit['time'] for e in r['events'])
    assert any(e['kind']=='cushion' and e['time']>hit['time'] for e in r['events'])
    if teaching:
        assert all(0<=e['index']<6 for e in r['events'] if e['kind']=='cushion')
        for key in [enemy]+(['_8'] if len(keys)==4 else []):assert math.dist(ps[key],q['positions'][key])<1e-5
    assert r['shot']['spinX']==0
    if tracks:
        assert set(r['tracks'])==set(keys)
        for key,track in r['tracks'].items():
            assert math.dist(track[0][1:],q['positions'][key])<1e-5
            assert math.dist(track[-1][1:],ps[key])<1e-4
            assert all(x[0]<=y[0] for x,y in zip(track,track[1:]))
    else:assert not r['tracks']
    full,intervals,half=proof(c,bs,t)
    assert r['occlusion']['full']==full
    assert abs(r['occlusion']['halfAngle']-half)<1e-6
    assert len(r['occlusion']['intervals'])==len(intervals)
    for a,b in zip(r['occlusion']['intervals'],intervals):assert max(abs(x-y) for x,y in zip(a,b))<1e-5
    visible=sweep(c,bs,t)
    if full_required:assert full
    if full:assert visible==0 and r['defenseScore']==100 and not r['opportunities']
    for option in r['opportunities']:
        for key,value in comfort(c,t,option['aim']).items():assert abs(value-option[key])<2e-4
    return visible

index=json.loads((OUT/'index.json').read_text());assert len({q['id'] for q in index})==len(index)
counts=collections.Counter();coverage=collections.defaultdict(collections.Counter);bases=collections.defaultdict(list)
source_cache={};checks=[];hashes={};stress_counts=collections.defaultdict(collections.Counter)
for i,entry in enumerate(index):
    raw=(OUT/entry['file']).read_bytes();q=json.loads(raw);hashes[entry['file']]=hashlib.sha256(raw).hexdigest()
    assert all(q[k]==entry[k] for k in ['id','family','zone','positions','openingComfort'])
    family=q['family'];keys=[CUE,q['ownKey'],q['enemyKey']]+([] if family.startswith('two') else ['_8'])
    assert (q['ownKey'],q['enemyKey'])==({'twoA':('_1','_8'),'twoB':('_8','_9')}.get(family,('_1','_9')))
    check_positions(q['positions'],keys);counts[family]+=1;coverage[family][q['zone']]+=1
    ps=q['positions'];c,b,t=ps[CUE],ps[q['ownKey']],ps[q['enemyKey']]
    actual_zone='short' if L/2-abs(b[0])-R<.18 else 'long' if W/2-abs(b[1])-R<.18 else 'open'
    assert actual_zone==q['zone'];bases[family].append([c,b])
    assert q['exactReplay'] and 0<=q['openingComfort']<=40
    assert max(o['score'] for o in q['openingOpportunities'])==q['openingComfort']
    for option in q['openingOpportunities']:
        for key,value in comfort(c,b,option['aim']).items():assert abs(value-option[key])<2e-4
    blockers=[q['ownKey']]+([] if family.startswith('two') else ['_8'])
    assert sweep(c,[ps[k] for k in blockers],t)>4097/2
    seed=q['sourceProposal'];source=seed['source']
    if source not in source_cache:
        data=(ROOT/source).read_bytes();source_cache[source]=(hashlib.sha256(data).hexdigest(),{r['id']:r for r in json.loads(data)})
    sha,source_rows=source_cache[source];assert sha==seed['sourceSHA256']
    original=source_rows[seed['sourceID']]
    assert original['positions'][CUE]==seed['cue'] and original['positions'][original['ownKey']]==seed['own'] and original['reference']['shot']==seed['shot']
    audit(q,q['reference'],True,True,True)
    final=q['reference']['positions'];fc,ft=final[CUE],final[q['enemyKey']]
    solos={k:sweep(fc,[final[k]],ft) for k in blockers}
    if family in ['twoA','twoB','own']:assert solos[q['ownKey']]==0
    if family=='own':assert solos['_8']>0
    if family=='black':assert solos['_8']==0 and solos['_1']>0
    if family=='joint':
        assert all(v>4097*.05 for v in solos.values())
        # Independent continuous angular interval subtraction; >5% is not a ray-count rounding rule.
        dt=math.dist(fc,ft);half=math.asin(2*R/dt)
        for key in blockers:
            b=final[key];db=math.dist(fc,b);assert dt-db-4*R>0
            delta=math.atan2(b[1]-fc[1],b[0]-fc[0])-math.atan2(ft[1]-fc[1],ft[0]-fc[0]);delta=math.atan2(math.sin(delta),math.cos(delta))
            bh=math.asin(2*R/db)
            left=max(0,min(half,delta-bh)+half);right=max(0,half-max(-half,delta+bh))
            assert (left+right)/(2*half)>.05,(q['id'],key,'continuous exposure')
    mirrored=lambda p:[-p[0],p[1]]
    assert proof(mirrored(fc),[mirrored(final[k]) for k in blockers],mirrored(ft))[0]
    assert sweep(mirrored(fc),[mirrored(final[k]) for k in blockers],mirrored(ft))==0
    assert len(q['perturbations'])==8
    reference_shot=q['reference']['shot'];reference_angle=math.atan2(reference_shot['direction'][1],reference_shot['direction'][0])
    combos=set()
    for p in q['perturbations']:
        assert 'rejection' not in p and p['shot']==p['result']['shot']
        da=p['angleDeltaDegrees'];sf=p['speedFactor'];combos.add((round(da,2),round(sf,2)))
        actual=math.atan2(p['shot']['direction'][1],p['shot']['direction'][0])-reference_angle
        actual=math.degrees(math.atan2(math.sin(actual),math.cos(actual)))
        assert abs(actual-da)<1e-4 and abs(p['shot']['speed']/reference_shot['speed']-sf)<1e-6
        assert p['shot']['spinY']==reference_shot['spinY']
        audit(q,p['result'],True,True)
    assert combos=={(a,v) for a in [-.15,0,.15] for v in [.95,1,1.05] if a!=0 or v!=1}
    assert audit(q,q['comparison'],tracks=True)>4097/4
    assert len(q['stressProbes'])==16
    per_stress=collections.defaultdict(collections.Counter)
    for p in q['stressProbes']:
        if 'rejection' in p:state='rejected'
        else:
            rays=audit(q,p['result']);state='full' if p['result']['occlusion']['full'] else 'exposed' if rays else 'unproven'
        stress_counts[family+'/'+p['tier']][state]+=1;per_stress[p['tier']][state]+=1
    checks.append(dict(id=q['id'],family=family,zone=q['zone'],soloExposedRays=solos,stress=per_stress,passed=True))
    if (i+1)%100==0:print(f'AUDIT {i+1}/{len(index)}',flush=True)

# Pairwise class-local de-duplication independently checks all table reflections.
for family,values in bases.items():
    a=np.asarray(values);n=len(a)
    for sx,sz in [(-1,-1),(-1,1),(1,-1),(1,1)]:
        reflected=a*np.array([sx,sz]);delta=a[:,None,:,:]-reflected[None,:,:,:]
        close=(np.linalg.norm(delta,axis=3)<.06-1e-7).all(axis=2)
        assert not np.triu(close,1).any(),family

# Across classes, similar bases are allowed but explicitly counted, not claimed unique.
cross_class={}
families=list(bases)
for i,family in enumerate(families):
    a=np.asarray(bases[family])
    for other in families[i+1:]:
        b=np.asarray(bases[other]);close=np.zeros((len(a),len(b)),dtype=bool)
        for sx,sz in [(-1,-1),(-1,1),(1,-1),(1,1)]:
            delta=a[:,None,:,:]-(b*np.array([sx,sz]))[None,:,:,:]
            close|=(np.linalg.norm(delta,axis=3)<.06-1e-7).all(axis=2)
        cross_class[family+'/'+other]=int(close.sum())

verified=0
bindings=json.loads((OUT/'runtime-bindings.json').read_text()) if (OUT/'runtime-bindings.json').exists() else {'r1':{'directory':'.','mainFile':'main-r1.swift'}}
for version,binding in bindings.items():
    runtime=OUT/binding['directory'];manifest=json.loads((runtime/'source-manifest.json').read_text())
    with tarfile.open(runtime/'source-snapshot.tar.gz') as tar:
        for path,sha in manifest.items():
            data=tar.extractfile('sources/'+path.removeprefix('QiuJi/')).read()
            if path.endswith('/QiuJiApp.swift'):data=data.replace(b'// Research worker supplies main',b'@main')
            assert hashlib.sha256(data).hexdigest()==sha;verified+=1
        assert tar.extractfile('main.swift').read()==Path(__file__).with_name(binding['mainFile']).read_bytes()
    assert json.loads((runtime/'build.json').read_text())['exitCode']==0
    assert json.loads((runtime/'execution.json').read_text())['exitCode']==0
if (OUT/'runtime-bindings.json').exists():
    assert all(e['runtimeVersion'] in bindings for e in index)
    for version,binding in bindings.items():
        original=json.loads((OUT/binding['directory']/'question-hashes.json').read_text())
        for entry in index:
            if entry['runtimeVersion']==version:assert original[entry['file']]==hashes[entry['file']]
if not partial:
    assert counts==dict(twoA=500,twoB=500,own=500,black=500,joint=500),counts
    assert all(dict(v)==dict(long=250,short=150,open=100) for v in coverage.values())
    assert json.loads((OUT/'summary.json').read_text())['complete']
report=dict(passed=True,partial=partial,questions=len(index),counts=counts,coverage=coverage,exactReplays=len(index),smallProbes=8*len(index),stressProbes=16*len(index),raysPerResult=4097,dedupMinimumMeters=.06,verifiedSwiftFiles=verified,crossClassNearBasePairs=cross_class,stressCounts=stress_counts,checks=checks,sourceHashes=hashes,scope='Frozen-source physics, independent geometry and arithmetic; not App/real-table acceptance')
(OUT/('audit-partial.json' if partial else 'audit.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(dict(audit='PASS',partial=partial,counts=counts,questions=len(index)),ensure_ascii=False))
