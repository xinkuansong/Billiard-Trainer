from pathlib import Path
import json,math,hashlib,itertools,collections
root=Path(__file__).resolve().parents[2];out=root/'output/defense-own-potential-20261105'
scenarios={x['label']:x for x in json.loads((out/'scenario.json').read_text())['cases']}
radius=json.loads((root/'output/defense-approved-filter-20261104/geometry.json').read_text())['radius']
checks=0;metricchecks=0;seen=set();rows=[]

def own_metric(v,target,blocker):
    global metricchecks
    key=json.dumps([target,blocker,v],sort_keys=True)
    if key in seen:return
    seen.add(key);metricchecks+=1
    assert len(v['pockets'])==6 and sorted(x['pocket'] for x in v['pockets'])==list(range(6))
    positive=[];geometric=[]
    dx,dz=blocker[0]-target[0],blocker[1]-target[1]
    for p in v['pockets']:
        w=p.get('geometricDegrees');clear=p.get('clearDegrees')
        if w is None:
            assert clear is None and p['status'] in ['unavailable','no-known-positive-window'];continue
        assert math.isfinite(w) and w>0;geometric.append(w)
        assert clear is not None and clear>=0 and clear<=w+1e-8
        computed=max([(b-a)*180/math.pi for a,b in p['clearIntervals']],default=0)
        assert abs(clear-computed)<1e-8
        for a,b in p['clearIntervals']:
            assert b>a
            for i in range(1,33):
                angle=a+(b-a)*i/33;ux,uz=math.cos(angle),math.sin(angle)
                t=max(0,dx*ux+dz*uz)
                distance=math.hypot(dx-t*ux,dz-t*uz)
                assert distance>=2*radius-2e-7,(distance,p)
        if clear>0:positive.append(clear)
    assert v['bestClearDegrees']==(max(positive) if positive else None)
    assert v['bestGeometricDegrees']==(max(geometric) if geometric else None)
    assert v['openPocketCount']==len(positive)
    assert v['unavailableCount']==sum(p['status']=='unavailable' for p in v['pockets'])

def effort(s):return 2.5*abs(s['spinX'])+abs(s['spinY'])+max(0,s['speed']-4)*.25

def dominates(a,b):
    ea,eb=effort(a['shot']),effort(b['shot']);va,vb=a['shot']['speed'],b['shot']['speed'];wa,wb=a['own']['bestClearDegrees'],b['own']['bestClearDegrees']
    return ea<=eb and va<=vb and wa>=wb and (ea<eb or va<vb or wa>wb)

for label in ['F01','F02','F03','F04','F05']:
    folder=out/label;data=json.loads((folder/'routes.json').read_text());cs=json.loads((folder/'candidate-metrics.json').read_text());old=json.loads((folder/'old-route-metrics.json').read_text())
    q=scenarios[label]['question'];enemy=next(b['position'] for b in q['balls'] if b['number']==9);initial8=next(b['position'] for b in q['balls'] if b['number']==8)
    own_metric(data['ownBefore'],initial8,enemy);before=data['ownBefore']['bestClearDegrees'] or 0
    for c in cs:
        assert c['defenseScore']>=90;own_metric(c['own'],c['finalPositions']['_8'],enemy)
        w=c['own']['bestClearDegrees'];assert c['ownPreserved']==(w is not None and w>0 and w+1e-8>=before)
        for p in c.get('probes',[]):
            if 'own' in p:
                own_metric(p['own'],p['finalPositions']['_8'],enemy)
                pw=p['own']['bestClearDegrees'];preserve=pw is not None and pw>0 and pw+1e-8>=before
                assert p['ownPreserved']==preserve
                assert p['passes']==(p['defensePasses'] and preserve)
        if 'jointPasses' in c:assert c['jointPasses']==sum(p['passes'] for p in c['probes'])
    eligible=[c for c in cs if c['ownPreserved'] and c.get('jointPasses')==4]
    front=[a for a in eligible if not any(dominates(b,a) for b in eligible)]
    assert len(front)==data['paretoCount']==len(data['routes'])
    for i,t in enumerate(data['tiers']):
        assert t['tier']==i
        if i:assert data['tiers'][i-1]['stableJointCandidates']==0
    for r in data['routes']:
        checks+=1;s=r['shot'];assert r['replayVerified'] and r['ownPreserved'] and r['probePasses']==4
        assert r['effect']['score']>=90 and r['baseScore']>=90 and abs(r['measuredCutDegrees']-s['cutDegrees'])<=.5
        assert any(c['shot']==s for c in front)
        assert not any(e['kind']=='pocket' for e in r['events'])
        assert not any('_9' in e.get('balls',[]) for e in r['events'] if e['kind']=='ballBall')
        assert math.dist(r['finalPositions']['_9'],enemy)<1e-6
        for k,frames in r['tracks'].items():
            assert all(math.isfinite(v) for frame in frames for v in frame)
            assert all(b[0]>=a[0] for a,b in zip(frames,frames[1:]))
            assert math.dist(frames[-1][1:],r['finalPositions'][k])<1e-5
        for a,b in itertools.combinations(r['finalPositions'].values(),2):assert math.dist(a,b)>=2*radius-1e-5
        own_metric(r['ownAfter'],r['finalPositions']['_8'],enemy)
    olddeclined=[];oldunknown=[]
    for c in old:
        own_metric(c['after'],c['finalPositions']['_8'],enemy)
        a=c['after']['bestClearDegrees']
        if a is None:oldunknown.append(c['id'])
        elif a+1e-8<before:olddeclined.append(c['id'])
    rows.append({'label':label,'candidateMetrics':len(cs),'retained':len(data['routes']),'stableJoint':len(eligible),'oldKnownAngleDeclined':olddeclined,'oldNoConfirmedPositiveWindow':oldunknown,'oldCount':len(old),'knownBranches':collections.Counter(p['status'] for p in data['ownBefore']['pockets'])})
manifest=json.loads((out/'source-manifest.json').read_text());drift=[p for p,h in manifest.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=h];assert not drift
report={'passed':True,'routesChecked':checks,'uniqueOwnMetricRecordsChecked':metricchecks,'sourceDrift':drift,'cases':rows,'scope':['all candidates and probes with own metrics checked','six pockets and no fabricated zeros for unknown windows','positive retained rays clear 2R blocker (32 interior samples per interval)','full replay physical events and final positions','Pareto membership independently recomputed with speed included','expansion only after no stable joint candidate','old no-window and known reduction separated'],'nativeGeometryChecks':json.loads((out/'geometry-checks.json').read_text())}
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
