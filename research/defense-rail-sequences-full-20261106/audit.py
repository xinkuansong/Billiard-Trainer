"""Independent schema, role, physics, score, window and pairwise diversity audit."""
import math,itertools

def own_metric(v,target,blockers,radius):
    assert len(v['pockets'])==6 and sorted(p['pocket'] for p in v['pockets'])==list(range(6))
    positives=[]
    for p in v['pockets']:
        w=p.get('geometricDegrees');clear=p.get('clearDegrees')
        if w is None:
            assert clear is None and p['status'] in ('unavailable','no-known-positive-window');continue
        assert math.isfinite(w) and w>0 and clear is not None and 0<=clear<=w+1e-8
        assert abs(clear-max(((b-a)*180/math.pi for a,b in p['clearIntervals']),default=0))<1e-8
        for a,b in p['clearIntervals']:
            assert b>a
            for i in range(1,17):
                angle=a+(b-a)*i/17;ux,uz=math.cos(angle),math.sin(angle)
                for blocker in blockers:
                    dx,dz=blocker[0]-target[0],blocker[1]-target[1]
                    t=max(0,dx*ux+dz*uz)
                    assert math.hypot(dx-t*ux,dz-t*uz)>=2*radius-2e-7
        if clear>0:positives.append(clear)
    assert v['bestClearDegrees']==(max(positives) if positives else None)
    assert v['openPocketCount']==len(positives)

def effect(e,opponent):
    assert e['scoringVersion']=='defense-target-pipe-always-scored-v8'
    assert e['opponentBallNumber']==opponent and not e.get('failure') and not e.get('unavailableReason')
    s=e['score'];assert math.isfinite(s) and 0<=s<=100
    if e.get('fullDirectBlock') or e.get('potContactsBlocked'):assert s==100
    else:
        a=e['targetPipeToleranceDegrees'];c=e['comfort']
        assert a>=0 and 0<=c<=100 and abs(s-100*math.sqrt((1-c/100)/(1+a)))<1e-7

def topology(events):return [(e['kind'],tuple(sorted(e.get('balls',[]))),e.get('ball'),e.get('index'),e.get('pocket')) for e in events]
def rail_sequences(events,own):
    return {'cue':[e['index'] for e in events if e['kind']=='cushion' and e['ball']=='cueBall'],
            'target':[e['index'] for e in events if e['kind']=='cushion' and e['ball']==own]}
def physics(events,positions,q,radius):
    own='_'+str(q['ownBallNumber']);enemy='_'+str(q['opponentBallNumber'])
    fixed={'_'+str(b['number']):b['position'] for b in q['balls'] if b['number']!=q['ownBallNumber']}
    assert set(positions)=={'cueBall'}|{'_'+str(b['number']) for b in q['balls']}
    for k,v in fixed.items():assert math.dist(positions[k],v)<1e-6
    assert math.dist(positions['cueBall'],positions[enemy])>=.30-1e-6
    assert all(math.isfinite(x) for p in positions.values() for x in p)
    assert all(math.dist(a,b)>=2*radius-1e-5 for a,b in itertools.combinations(positions.values(),2))
    assert events and all(b['time']>=a['time'] for a,b in zip(events,events[1:]))
    contact=False;ownrail=False;railafter=False
    for e in events:
        assert e['kind']!='pocket'
        if e['kind']=='ballBall':
            assert set(e['balls'])=={'cueBall',own} and not ownrail
            contact=True
        elif e['kind']=='cushion':
            assert e['index'] in range(6)
            if contact:railafter=True
            if contact and e['ball']==own:ownrail=True
    assert contact and railafter

def audit(record,metrics,expected,identity):
    assert record['question']==expected and record['identity']==identity
    q=expected;r=record['result'];scan=record['scan'];radius=scan['radius']
    assert r['questionID']==q['id'] and r['ownBallNumber']==q['ownBallNumber'] and r['opponentBallNumber']==q['opponentBallNumber']
    assert len(scan['rows'])==1250 and scan['has85Region']==(scan['maximumSampled']>=85)
    scores=[row['score'] for row in scan['rows'] if 'score' in row];assert max(scores)==scan['maximumSampled']
    own='_'+str(q['ownBallNumber']);op=q['opponentBallNumber']
    blockers=[b['position'] for b in q['balls'] if b['number']!=q['ownBallNumber']]
    own_metric(r['ownBefore'],next(b['position'] for b in q['balls'] if b['number']==q['ownBallNumber']),blockers,radius)
    before=r['ownBefore']['bestClearDegrees'] or 0
    assert len(metrics)==r['deduplicatedCount']
    for c in metrics:
        effect(c['effect'],op);effect(c['baseEffect'],op)
        assert c['defenseScore']==c['effect']['score'] and c['defenseScore']>=80
        own_metric(c['own'],c['finalPositions'][own],blockers,radius)
        w=c['own']['bestClearDegrees'];assert c['ownPreserved']==(w is not None and w>0 and w+1e-8>=before)
    assert len(r['routes'])==r['retainedCount']<=6 and r['admitted']==(len(r['routes'])>=2)
    assert r['diversityVersion']=='per-ball-rail-sequences-v2'
    for route in r['routes']:
        assert route['railSequences']==rail_sequences(route['events'],own)
        effect(route['effect'],op);assert route['effect']['score']>=80
        physics(route['events'],route['finalPositions'],q,radius)
        assert route['replayVerified'] and route['ownPreserved'] and route['probePasses']==4
        assert abs(route['measuredCutDegrees']-route['shot']['cutDegrees'])<=.5
        own_metric(route['ownAfter'],route['finalPositions'][own],blockers,radius)
        assert route['ownAfter']['bestClearDegrees']>0 and route['ownAfter']['bestClearDegrees']+1e-8>=before
        for k,frames in route['tracks'].items():
            assert frames and math.dist(frames[-1][1:],route['finalPositions'][k])<1e-5
            assert all(math.isfinite(x) for f in frames for x in f)
            assert all(b[0]>=a[0] for a,b in zip(frames,frames[1:]))
        probes=route['probes'];assert len(probes)==4
        assert {(p['angleDelta'],p['speedScale']) for p in probes}=={(-.1,1),(.1,1),(0,.95),(0,1.05)}
        for p in probes:
            assert p['passes'] and p['physicalVerified'] and p['ownPreserved']
            effect(p['effect'],op);effect(p['baseEffect'],op);assert p['score']==p['effect']['score']>=80
            physics(p['events'],p['finalPositions'],q,radius)
            own_metric(p['own'],p['finalPositions'][own],blockers,radius)
            assert p['own']['bestClearDegrees']>0 and p['own']['bestClearDegrees']+1e-8>=before
    for a,b in itertools.combinations(r['routes'],2):
        assert rail_sequences(a['events'],own)!=rail_sequences(b['events'],own)
    return dict(id=q['id'],kind=q['kind'],retained=r['retainedCount'],admitted=r['admitted'],maximumSampled=scan['maximumSampled'],has85Region=scan['has85Region'],seconds=record['wallSeconds'],parameters=r['counts'].get('parameters',0),physics=r['counts'].get('physics',0),routesByPath={'region':sum(x['baseScore']>=80 for x in r['routes']),'blocking':sum(x['baseScore']<80 for x in r['routes'])})
