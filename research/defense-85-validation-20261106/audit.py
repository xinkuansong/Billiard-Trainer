from pathlib import Path
import json,math,hashlib,itertools,collections
root=Path(__file__).resolve().parents[2];out=root/'output/defense-85-validation-20261106'
scenarios=json.loads((out/'scenario.json').read_text())['cases']
radius=json.loads((out/'85-01/geometry.json').read_text())['radius']
metricchecks=0;seen=set()
# Reuse independently sampled ray/disk validation, not the Swift interval implementation.
source=(root/'research/defense-own-potential-20261105/audit.py').read_text()
exec(source[source.index('def own_metric'):source.index('\ndef effort')])
def branch(e):
    if e.get('fullDirectBlock') or e.get('potContactsBlocked'):return 'blocked'
    if e.get('estimateReason'):return 'estimated'
    if (e.get('pipeRoute') or {}).get('zeroWidthEstimate'):return 'zero-width'
    return 'formula'
def stable(c,t):
    return c['defenseScore']>=t and c['ownPreserved'] and len(c.get('probes',[]))==4 and all(p.get('score',-1)>=t and p.get('ownPreserved',False) for p in c['probes'])
def path(c,t):return 'intrinsic' if c['baseScore']>=t else 'blocking-added'
rows=[];nroute=0
for case in scenarios:
    label=case['label'];d=out/label;data=json.loads((d/'routes.json').read_text());cs=json.loads((d/'candidate-metrics.json').read_text());scan=json.loads((d/'scan-adaptive.json').read_text())
    assert hashlib.sha256((d/'scan-adaptive.json').read_bytes()).hexdigest()==case['scanSHA256']
    q=case['question'];enemy=case['target'];initial8=next(b['position'] for b in q['balls'] if b['number']==8)
    own_metric(data['ownBefore'],initial8,enemy);before=data['ownBefore']['bestClearDegrees'] or 0
    for c in cs:
        assert 75<=c['defenseScore']<=100 and 0<=c['baseScore']<=100
        own_metric(c['own'],c['finalPositions']['_8'],enemy)
        assert math.dist(c['finalPositions']['cueBall'],enemy)>=.30-1e-6
        w=c['own']['bestClearDegrees'];assert c['ownPreserved']==(w is not None and w>0 and w+1e-8>=before)
        assert c['stableThresholds']==[t for t in [75,80,85] if stable(c,t)]
        for p in c.get('probes',[]):
            if 'own' not in p:assert not p['passes'];continue
            own_metric(p['own'],p['finalPositions']['_8'],enemy)
            pw=p['own']['bestClearDegrees'];assert p['ownPreserved']==(pw is not None and pw>0 and pw+1e-8>=before)
            assert p['passes']==(p['score']>=75 and p['ownPreserved'])
            assert math.dist(p['finalPositions']['_9'],enemy)<1e-6
            assert math.dist(p['finalPositions']['cueBall'],enemy)>=.30-1e-6
    leaf=[r for r in scan['rows'] if 'score' in r]
    area=lambda r:(r['bounds'][2]-r['bounds'][0])*(r['bounds'][3]-r['bounds'][1])
    totalarea=sum(map(area,leaf));thresholds=[]
    for t,native in zip([75,80,85],data['thresholdResults']):
        nominal=[c for c in cs if c['defenseScore']>=t];valid=[c for c in cs if stable(c,t)]
        assert native['nominal']==len(nominal) and native['robust']==len(valid)
        assert native['preservesOwn']==sum(c['ownPreserved'] for c in nominal)
        pathways={p:sum(path(c,t)==p for c in valid) for p in ['intrinsic','blocking-added']}
        assert pathways==native['paths']
        thresholds.append({**native,'areaPercent':100*sum(area(r) for r in leaf if r['score']>=t)/totalarea,'robustBranches':dict(collections.Counter(branch(c['effect']) for c in valid)),'nominalBranches':dict(collections.Counter(branch(c['effect']) for c in nominal)),'robustWithoutEstimateInAllProbes':sum(branch(c['effect']) in ['formula','blocked'] and all(branch(p['effect']) in ['formula','blocked'] for p in c['probes']) for c in valid)})
    assert all(thresholds[i]['robust']>=thresholds[i+1]['robust'] and thresholds[i]['areaPercent']+1e-8>=thresholds[i+1]['areaPercent'] for i in [0,1])
    for r in data['routes']:
        nroute+=1;assert r['replayVerified'] and r['probePasses']==4 and r['ownPreserved']
        assert abs(r['measuredCutDegrees']-r['shot']['cutDegrees'])<=.5
        c=next(c for c in cs if c['shot']==r['shot']);assert stable(c,75) and c['stableThresholds']==r['stableThresholds']
        assert abs(r['effect']['score']-c['defenseScore'])<1e-7
        assert not any(e['kind']=='pocket' for e in r['events'])
        assert not any('_9' in e.get('balls',[]) for e in r['events'] if e['kind']=='ballBall')
        assert math.dist(r['finalPositions']['_9'],enemy)<1e-6
        assert math.dist(r['finalPositions']['cueBall'],enemy)>=.30-1e-6
        for k,frames in r['tracks'].items():
            assert all(math.isfinite(v) for frame in frames for v in frame)
            assert all(b[0]>=a[0] for a,b in zip(frames,frames[1:]))
            assert math.dist(frames[-1][1:],r['finalPositions'][k])<1e-5
        for a,b in itertools.combinations(r['finalPositions'].values(),2):assert math.dist(a,b)>=2*radius-1e-5
        own_metric(r['ownAfter'],r['finalPositions']['_8'],enemy)
    probeReasons=collections.Counter()
    for c in cs:
        for p in c.get('probes',[]):
            if p.get('reason'):probeReasons[p['reason']]+=1
            elif not p.get('ownPreserved',False):probeReasons['own-window-declined']+=1
            elif p.get('score',-1)<75:probeReasons['below-75']+=1
            else:probeReasons['pass-75']+=1
    rows.append({'probeOutcomes':dict(probeReasons),'label':label,'initialMaximum':case['maximum'],'thresholds':thresholds,'retained':len(data['routes']),'counts':data['counts'],'dedup':len(cs),'probed':data['probedCandidates'],'seconds':data['seconds'],'lastTier':data['tiers'][-1]['tier']})
manifest=json.loads((out/'source-manifest.json').read_text());drift=[p for p,h in manifest.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=h];assert not drift
assert hashlib.sha256((root/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()).hexdigest()==json.loads((out/'scenario.json').read_text())['bankSHA256']
summary={'cases':rows,'thresholds':[{'threshold':t,'layouts':sum(r['thresholds'][i]['robust']>0 for r in rows),'robustCandidates':sum(r['thresholds'][i]['robust'] for r in rows),'blockingAdded':sum(r['thresholds'][i]['paths']['blocking-added'] for r in rows)} for i,t in enumerate([75,80,85])]}
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
report={'passed':True,'routesChecked':nroute,'uniqueOwnMetricsChecked':metricchecks,'sourceDrift':drift,'thresholdMonotonicity':True,'samePool':True,'bankUnchanged':True,'limitations':['bounded shortlist validation; unprobed candidates are not failures','ten selected 85-bin cases, no population inference', 'search stops at first spin tier with robust primary goal 80; 85 is diagnostic only', 'own window nondecline is provisional, not a calibrated comfort threshold','four separate direction/speed probes, not a measured success probability','static map area estimated from valid sample-centre leaves','own potential is confirmed-window lower bound; no future cue prediction','scoring branches kept separate; zero-width is not calibrated difficulty']}
(out/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(summary['thresholds']));print(json.dumps(report))
for r in rows:print(r['label'],round(r['initialMaximum'],2),[(t['threshold'],round(t['areaPercent'],2),t['robust'],t['paths'],t['robustBranches']) for t in r['thresholds']])
