"""Independent event/parameter/early-exit audit, selection and duplicate ledger."""
from pathlib import Path
import collections, gzip, hashlib, json, math, sqlite3, struct
import numpy as np
from scan import ROOT, OUT, sha


def f32(x):return struct.unpack('f',struct.pack('f',x))[0]


def check_trial(row,seed,probe):
    delta=list(map(f32,probe['delta']));actual=row['input']
    assert [actual[k] for k in ('v','sx','sy')]==[f32(f32(seed['v'])*f32(1+delta[1])),f32(f32(seed['sx'])+delta[2]),f32(f32(seed['sy'])+delta[3])]
    if delta[0]==0:assert actual['dir']==list(map(f32,seed['dir']))
    expected=math.atan2(f32(seed['dir'][1]),f32(seed['dir'][0]))+math.radians(delta[0])
    measured=math.atan2(actual['dir'][1],actual['dir'][0]);diff=math.atan2(math.sin(expected-measured),math.cos(expected-measured))
    assert abs(diff)<8e-7
    events=row['events'];assert all(e['index']==i for i,e in enumerate(events))
    assert all(math.isfinite(e['time']) for e in events)
    assert all(a['time']<=b['time'] for a,b in zip(events,events[1:]))
    hits=[(i,e) for i,e in enumerate(events) if e['kind']=='ballBall' and 'cueBall' in e['balls']]
    first=bool(hits) and set(hits[0][1]['balls'])=={'cueBall','object'}
    hit=next((i for i,e in hits[1:] if set(e['balls'])=={'cueBall','kTarget'}),None) if first else None
    later=hit is not None
    pot=any(e['kind']=='pocket' and e['ball']=='object' and e['pocket']==f"pocket_{seed['pocket']}" for e in events)
    scratch=any(e['kind']=='pocket' and e['ball']=='cueBall' for e in events)
    assert [row[k] for k in ('firstA','laterB','potA','scratch')]==[bool(first),later,pot,scratch]
    assert row['success']==bool(row['complete'] and first and later and pot)
    rails=[e['cushion'] for e in events[hits[0][0]+1:hit] if e['kind']=='cushion' and e['ball']=='cueBall' and 0<=e['cushion']<6] if later else []
    assert rails==row['railsBeforeK']
    if row['reasons']!=['inaccessible']:
        reasons=[s for s,flag in [('incomplete',not row['complete']),('wrong-first-ball',not first),('no-cue-B-contact',not later),('A-not-in-specified-pocket',not pot)] if flag]
        assert row['reasons']==reasons


def grade_attempt(attempt,seed,candidate,reference,protocol):
    results=attempt['results'];assert results[0]['probeID']=='baseline'
    probes={p['id']:p for p in protocol['probes']};probes['baseline']=dict(delta=[0,0,0,0])
    assert len({r['probeID'] for r in results})==len(results)
    for row in results:check_trial(row,seed,probes[row['probeID']])
    match=results[0]['railsBeforeK']==reference[:candidate['expectedRails']]
    assert match==attempt['nominalRouteMatch']
    grade=0;offset=1;small_joint=-1
    if results[0]['success'] and match:
        for li,level in enumerate(('small','medium','large')):
            ps=[p for p in protocol['probes'] if p['level']==level]
            axis_failed=False;jfail=jpass=0
            for p in ps:
                assert offset<len(results),(attempt['id'],'missing',p['id'])
                row=results[offset];offset+=1;assert row['probeID']==p['id']
                if p['kind']=='axis' and not row['success']:axis_failed=True;break
                if p['kind']=='joint':
                    if row['success']:jpass+=1
                    else:jfail+=1
                    if jfail>6:break
            if level=='small':small_joint=jpass
            if axis_failed or jfail>6:break
            assert jpass+jfail==32;grade=li+1
    assert offset==len(results)
    assert grade==attempt['grade'] and small_joint==attempt['smallJointPass']
    return grade


def finite_distance(p,a,b):
    # Independent scalar clamped projection, including segment endpoints.
    dx,dz=b[0]-a[0],b[1]-a[1];den=dx*dx+dz*dz
    u=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/den)) if den else 0
    return math.hypot(p[0]-a[0]-u*dx,p[1]-a[1]-u*dz)


def min_path_dist(p,pts):
    return min(finite_distance(p,a,b) for a,b in zip(pts,pts[1:])) if len(pts)>1 else math.dist(p,pts[0])


def pre_k_points(item):
    e=item['baseline']['events'];first=next(i for i,x in enumerate(e) if x['kind']=='ballBall' and set(x['balls'])=={'cueBall','object'})
    hit=next(x['time'] for x in e[first+1:] if x['kind']=='ballBall' and set(x['balls'])=={'cueBall','kTarget'})
    return [p[1:] for p in item['tracks']['cueBall'] if e[first]['time']<=p[0]<=hit]


_path_cache={}
def dense_path(item):
    if item['id'] not in _path_cache:
        points=pre_k_points(item);dense=[]
        for a,b in zip(points,points[1:]):
            n=max(1,math.ceil(math.dist(a,b)/.01))
            dense.extend([[a[k]+(b[k]-a[k])*i/n for k in (0,1)] for i in range(n)])
        if points:dense.append(points[-1])
        _path_cache[item['id']]=np.asarray(dense)
    return _path_cache[item['id']]


def directed_near(p,q,d):
    if len(q)<2:return bool(len(q)) and np.all(np.linalg.norm(p-q[0],axis=1)<d)
    starts=q[:-1];delta=np.diff(q,axis=0);den=np.sum(delta*delta,axis=1)
    for offset in range(0,len(p),128):
        rel=p[offset:offset+128,None,:]-starts
        u=np.clip(np.sum(rel*delta,axis=2)/np.where(den>0,den,1),0,1)
        dist=np.linalg.norm(rel-u[:,:,None]*delta,axis=2)
        if not np.all(np.min(dist,axis=1)<d):return False
    return True


def path_near(a,b,d):
    # 1cm maximum spacing, with a 5mm Lipschitz margin, bounds the entire
    # polyline rather than just the original 60Hz vertices.
    pa,pb=dense_path(a),dense_path(b)
    return bool(len(pa) and len(pb)) and directed_near(pa,pb,d-.005) and directed_near(pb,pa,d-.005)


def run():
    assert json.loads((OUT/'execution.json').read_text())['complete']
    protocol=json.loads((OUT/'protocol.json').read_text());g=json.loads((OUT/'geometry.json').read_text());diameter=2*g['radius']
    assert sha(OUT/'jobs.jsonl')==protocol['sourceJobSHA256']
    assert sha(OUT/'candidate-regions.jsonl')==protocol['candidateAuditSHA256']
    db=sqlite3.connect(OUT/'pool.sqlite');counts=collections.Counter();allselected=[];source_slots=[];probe_failures=collections.Counter()
    seen=set();maxdistance=0
    execution=json.loads((OUT/'execution.json').read_text())
    assert execution['workerSHA256']==json.loads((OUT/'build.json').read_text())['executableSHA256']
    binding=json.loads((OUT/'source-binding.json').read_text())
    assert sha(ROOT/'research/k-ball-full-20261029/main.swift')==binding['entrySHA256']
    for source in binding['sources']:assert sha(ROOT/source['path'])==source['sha256'],source['path']
    for name in ('float-B-audit.json','source-check.json','focused-checks.json','smoke-audit.json'):
        assert json.loads((OUT/name).read_text())['passed']
    def results():
        for file in execution['compressedFiles']:
            path=OUT/file['path'];assert sha(path)==file['sha256']
            digest=hashlib.sha256()
            with gzip.open(path,'rb') as stream:
                for line in stream:
                    digest.update(line);yield json.loads(line)
            assert digest.hexdigest()==file['uncompressedSHA256']
    for wi in [0]:
        jobs={j['key']:j for i in range(4) for j in map(json.loads,(OUT/f'jobs-{i}.jsonl').open())}
        for result in results():
            key=result['key'];assert key not in seen;seen.add(key);job=jobs[key]
            pool={c['id']:c for group in job['groups'] for c in group['candidates']}
            row=json.loads(db.execute('SELECT data FROM routes WHERE key=?',(key,)).fetchone()[0]);pts=[p[1:] for p in row['route']['trajectory2mm']['points']]
            assert 5<=row['board']['angle']<=50
            for c in pool.values():
                p=c['B'];rail=g['rails'][c['railID']];dist=finite_distance(p,rail['start'],rail['end']);maxdistance=max(maxdistance,dist)
                assert dist<=.1 and abs(dist-c['centerRailDistance'])<1e-12
                assert sum((p[k]-rail['start'][k])*rail['normal'][k] for k in (0,1))>=g['radius']
                assert abs(p[0])<=g['length']/2-g['radius'] and abs(p[1])<=g['width']/2-g['radius']
                assert min_path_dist(p,pts[c['lo']:c['hi']+1])<=.45*diameter+1e-12
                assert min_path_dist(p,pts[:c['lo']+1])>diameter+.002
                assert finite_distance(p,job['seed']['cue'],pts[0])>diameter+.002
                assert min(math.dist(p,job['seed'][k]) for k in ('cue','object'))>diameter+.002
                assert all(min(finite_distance(p,a,po['lip'][(i+1)%len(po['lip'])]) for i,a in enumerate(po['lip']))>=.30 for po in g['pockets'])
                assert c['sourceAngle']<=45
            attempted={a['id']:a for a in result['attempted']};assert len(attempted)==len(result['attempted'])
            assert set(attempted).isdisjoint(result['untestedAfterGoodCandidate'])
            assert set(attempted)|set(result['untestedAfterGoodCandidate'])==set(pool)
            for a in result['attempted']:
                grade_attempt(a,job['seed'],pool[a['id']],job['referenceRailIDs'],protocol)
                counts['candidateBaselines']+=1;counts['perturbations']+=len(a['results'])-1
                counts['baselinePassed']+=a['results'][0]['success']
                counts['scratchSuccessesAcrossTrials']+=sum(t['success'] and t['scratch'] for t in a['results'])
                probe_failures.update(reason for t in a['results'] for reason in t['reasons'])
            selected_byaxis={s['candidate']['axis']:s for s in result['selected']};assert len(selected_byaxis)==len(result['selected'])<=2
            for group in job['groups']:
                axis=group['axis'];considered=[];stop=False
                for c in group['candidates']:
                    if stop:assert c['id'] not in attempted;continue
                    assert c['id'] in attempted;a=attempted[c['id']];considered.append(a)
                    if a['grade']>=2:stop=True
                positive=[a for a in considered if a['grade']>=1]
                if not positive:
                    assert axis not in selected_byaxis;source_slots.append(dict(route=key,axis=axis,status='noTolerancePass'));continue
                best=max(positive,key=lambda a:(a['grade'],a['smallJointPass']))
                s=selected_byaxis[axis];assert s['candidate']==pool[best['id']] and s['grade']==best['grade']
                assert s['baseline']==best['results'][0] and s['exactReplay']
                counts['selectedReplays']+=1
                for points in s['tracks'].values():
                    assert all(all(math.isfinite(v) for v in p) for p in points)
                    assert all(a[0]<=b[0] for a,b in zip(points,points[1:]))
                item=dict(id=best['id'],routeKey=key,seed=job['seed'],sourceGenerationAngle=row['board']['angle'],**s)
                allselected.append(item);source_slots.append(dict(route=key,axis=axis,status='selectedBeforeDedup',id=best['id']))
        assert {j for j in jobs}<=seen
    assert len(seen)==json.loads((OUT/'candidate-summary.json').read_text())['counts']['routes']
    counts['simulations']=counts['candidateBaselines']+counts['perturbations']+counts['selectedReplays']
    # Merge near-identical training questions only when initial cue/A, pocket,
    # timing, observed rail, actual cushion sequence and pre-K path agree.
    groups=collections.defaultdict(list)
    for item in allselected:
        c=item['candidate'];s=item['seed'];key=tuple(s['cue']+s['object'])+(s['pocket'],c['axis'],c['railID'],tuple(item['baseline']['railsBeforeK']))
        groups[key].append(item)
    retained=[];duplicate=[]
    for rows in groups.values():
        winners=[]
        for item in sorted(rows,key=lambda s:(-s['grade'],s['id'])):
            same=next((w for w in winners if math.dist(w['candidate']['B'],item['candidate']['B'])<diameter and path_near(w,item,diameter)),None)
            if same:
                duplicate.append(dict(removed=item['id'],representative=same['id'],removedRoute=item['routeKey'],representativeRoute=same['routeKey'],BdistanceMeters=math.dist(same['candidate']['B'],item['candidate']['B']),note='near duplicate; representative has its own tested B/shot, not a verified replacement on removed route'))
            else:winners.append(item)
        retained+=winners
    retained.sort(key=lambda s:(s['routeKey'],s['candidate']['axis']))
    with (OUT/'selected.jsonl').open('w') as f:
        for item in retained:f.write(json.dumps(item,ensure_ascii=False)+'\n')
    with (OUT/'validated-before-dedup.jsonl').open('w') as f:
        for item in allselected:f.write(json.dumps(item,ensure_ascii=False)+'\n')
    (OUT/'duplicates.json').write_text(json.dumps(duplicate,ensure_ascii=False))
    removed={d['removed']:d['representative'] for d in duplicate}
    for slot in source_slots:
        if slot.get('id') in removed:slot.update(status='nearDuplicateRemoved',representative=removed[slot['id']])
    (OUT/'source-slots.json').write_text(json.dumps(source_slots,ensure_ascii=False))
    grades={1:'敏感',2:'常规',3:'宽容'};routes=collections.Counter(s['routeKey'] for s in retained)
    summary=dict(complete=True,counts=dict(counts),validatedBeforeDedup=len(allselected),selected=len(retained),duplicates=len(duplicate),retainedRoutes=len(routes),retainedLayouts=len({s['seed']['layout'] for s in retained}),grades=dict(collections.Counter(grades[s['grade']] for s in retained)),byTiming=dict(collections.Counter(s['candidate']['axis'] for s in retained)),byObservedRail=dict(collections.Counter(s['candidate']['railOrdinal'] for s in retained)),byPocket=dict(collections.Counter('中袋' if s['seed']['pocket'] in (4,5) else '角袋' for s in retained)),routesWithBoth=sum(n==2 for n in routes.values()),routesWithOne=sum(n==1 for n in routes.values()),selectedScratches=sum(s['baseline']['scratch'] for s in retained),maxCandidateCenterDistanceMeters=maxdistance,failures=dict(probe_failures),limits='bounded seeded candidate sampling; early-stopped cumulative simulation grades, not human success probability; no B outcome or scratch rejection; duplicate aliases do not claim substituted B validated on removed route')
    assert max(routes.values(),default=0)<=2
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    audit=dict(passed=True,checks=['all jobs and candidate dispositions accounted','scalar finite-segment B geometry','Float parameter perturbations','ordered events and scratch ignored','exact cumulative early-stop grading','quota one per timing per route','selected baseline exact native replay','duplicate provenance retained'],sourceSHA256={n:sha(OUT/n) for n in ['scan-audit.json','candidate-summary.json','protocol.json','source-binding.json','selected.jsonl','validated-before-dedup.jsonl','duplicates.json','source-slots.json','float-B-audit.json','source-check.json','focused-checks.json','smoke-audit.json']},compressedResultSHA256={f['path']:f['sha256'] for f in execution['compressedFiles']},summary=summary)
    (OUT/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));db.close();print(json.dumps(summary,ensure_ascii=False,indent=2),flush=True)


if __name__=='__main__':run()
