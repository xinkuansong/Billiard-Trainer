"""Read-only scoring experiment on archived, independently re-aimed physics runs."""
from pathlib import Path
import json, math, hashlib, bisect

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SRC = ROOT / 'research/joint-trajectory-20261022'
def read(name): return json.loads((SRC / name).read_text())
def save(name, value): (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2))
def dist(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])
DATA = read('scan-results.json')
D = 2*DATA['radius']
SAMPLE = read('sample.json')
ROWS = {r['id']:r for r in DATA['rows']}

def clean(points):
    result = [points[0]]
    for p in points[1:]:
        if dist(result[-1], p) > 1e-10: result.append(p)
    return result

def lengths(points):
    s=[0.0]
    for a,b in zip(points, points[1:]): s.append(s[-1]+dist(a,b))
    return s

def interpolate(points, s, x):
    if x>=s[-1]: return points[-1]
    i=min(len(points)-2, max(0,bisect.bisect_right(s,x)-1))
    f=(x-s[i])/(s[i+1]-s[i])
    return [points[i][j]*(1-f)+points[i+1][j]*f for j in range(2)]

def resample(points, n=121, distance=None):
    points=clean(points)
    if len(points)==1: return points*n
    s=lengths(points)
    end=s[-1] if distance is None else distance
    return [interpolate(points,s,end*i/(n-1)) for i in range(n)]

def post(row):
    # Recover the archived post-contact boundary from the independently recorded
    # postContactLength; audit against exact first-touch sphere geometry below.
    p=row['cuePath']; suffix=[0.0]*len(p)
    for i in range(len(p)-2,-1,-1): suffix[i]=suffix[i+1]+dist(p[i],p[i+1])
    i=min(range(len(p)), key=lambda i:abs(suffix[i]-row['postContactLength']))
    residual=abs(suffix[i]-row['postContactLength'])
    assert residual<0.00005, (row['id'],residual)
    target=[SAMPLE['target']['x'],SAMPLE['target']['z']]
    assert abs(dist(p[i],target)-D)<0.0001,(row['id'],dist(p[i],target),D)
    return clean(p[i:]), i, residual

def segments(row, points):
    indexes=[0]; cursor=0
    for event in row['railEvents']:
        i=min(range(cursor,len(points)),key=lambda i:dist(points[i],event['position']))
        assert dist(points[i],event['position'])<0.0001
        indexes.append(i);cursor=i
    indexes.append(len(points)-1)
    return [points[a:b+1] for a,b in zip(indexes,indexes[1:])]

def mse(a,b): return sum(dist(x,y)**2 for x,y in zip(a,b))/len(a)
def quality(error,half): return 2**(-(error/half)**2)

def score(target, actual):
    a,_,_=post(target); b,_,_=post(actual)
    # Compare the same travelled distance in the first up-to-30 cm, without
    # translating the collision anchors. A shorter shot remains at its endpoint.
    early_length=min(.30,lengths(a)[-1])
    early=math.sqrt(mse(resample(a,distance=early_length),resample(b,distance=early_length)))
    same_route=target['rails']==actual['rails'] and actual['jaw']==0
    if same_route:
        aa=segments(target,a);bb=segments(actual,b)
        whole=math.sqrt(sum(mse(resample(x),resample(y)) for x,y in zip(aa,bb))/len(aa))
    else:
        whole=math.sqrt(mse(resample(a),resample(b)))
    endpoint=dist(target['stop'],actual['stop'])
    route=30*quality(early,D)+40*quality(whole,D)
    stop=30*quality(endpoint,2*D)
    valid=bool(actual['settled'] and actual['pot'] and not actual['scratch'] and actual['firstAccess'] and actual['contacts']==1 and actual['before']==0 and actual['objectRails']==0)
    return dict(total=route+stop,route=route,endpoint=stop,earlyCm=early*100,
                wholeCm=whole*100,stopCm=endpoint*100,sameRoute=same_route,valid=valid,
                status=('进球／母球条件未满足' if not valid else '库序不同，路线未完成' if not same_route else '路线条件满足'))

def compact(row):
    pp,contact,residual=post(row)
    keys=['id','v','sx','sy','rails','pot','scratch','settled','jaw','direction','solverDirection','postContactLength','stop','firstAccess','contacts','objectRails']
    result={k:row[k] for k in keys}
    # Archive original full arrays; visual uses original event points, no spline.
    result.update(cuePath=clean(row['cuePath']),objectPath=clean(row['objectPath']),postPath=pp,
                  contact=row['cuePath'][contact],contactIndex=contact,contactLengthResidual=residual,
                  railEvents=row['railEvents'])
    return result

def main():
    source_hashes={n:hashlib.sha256((SRC/n).read_bytes()).hexdigest() for n in ['scan-results.json','sample.json','compiled-harness.swift','protocol.json','snapshot-hashes.json']}
    identities=read('source-hashes-before.json')
    physics={k:v for k,v in identities.items() if k.startswith('QiuJi/Core/Physics/')}
    drift=[k for k,v in physics.items() if hashlib.sha256((ROOT/k).read_bytes()).hexdigest()!=v]
    assert not drift,drift
    scenarios=[]
    definitions=[('不吃库','four',0),('一库','four',3),('两库','two',7)]
    selections=[('目标原样','A','1111'),('力度 −8%','B','0111'),('力度 +8%','B','2111'),
                ('横打点 −0.05R','B','1101'),('纵打点 +0.05R','B','1112'),('力度／打点同时变化','B','2102')]
    mains=[r for r in ROWS.values() if r.get('directionDeltaDegrees')==0 and r.get('settled') and r.get('cuePath') and r.get('contacts')==1 and r.get('before')==0]
    for title,route,vi in definitions:
        target=ROWS[f'{route}-{vi}-A-1111'];cases=[]
        for label,tier,offset in selections:
            row=ROWS[f'{route}-{vi}-{tier}-{offset}']
            assert row['directionDeltaDegrees']==0 and row['direction']==row['solverDirection']
            cases.append(dict(label=label,shot=compact(row),score=score(target,row)))
        # Fixed parameter contrast, not chosen by score.
        row=ROWS[f'{route}-{min(12,vi+3)}-A-1111']
        cases.append(dict(label='明显加力',shot=compact(row),score=score(target,row)))
        # Intentionally select a counterexample by nearest endpoint among different routes.
        eligible=[r for r in mains if r['accepted'] and r['rails']!=target['rails']]
        row=min(eligible,key=lambda r:dist(target['stop'],r['stop']))
        cases.append(dict(label='反例：库序不同',shot=compact(row),score=score(target,row)))
        scenarios.append(dict(title=title,target=compact(target),cases=cases))
    # Meaningful mathematical invariants of the proposed metric, not engine tests.
    checks={}
    checks['identity_100']=all(abs(s['cases'][0]['score']['total']-100)<1e-9 for s in scenarios)
    checks['direction_is_solver_output']=all(c['shot']['direction']==c['shot']['solverDirection'] for s in scenarios for c in s['cases'])
    checks['scores_bounded']=all(0<=c['score']['total']<=100 for s in scenarios for c in s['cases'])
    checks['wrong_routes_never_completed']=all(not c['score']['sameRoute'] for s in scenarios for c in s['cases'][-1:])
    checks['quality_monotone']=all(quality(x,D)>quality(x+.01,D) for x in [0,.01,.03,.05,.1,.2])
    checks['half_credit_calibration']=quality(D,D)==.5 and quality(2*D,2*D)==.5
    # Ordered path must reject a reversal despite identical sets of points.
    line=[[0,0],[1,0]]
    checks['reverse_path_not_equal']=mse(resample(line),resample(line[::-1]))>.3
    checks['resampling_density_invariant']=mse(resample(line),resample([[0,0],[.2,0],[.7,0],[1,0]]))<1e-25
    target=ROWS['four-3-A-1111'];actual=ROWS['four-3-B-0111']
    altered=dict(actual,v=4.0,sx=.1,sy=-.2)
    checks['input_parameters_do_not_affect_score']=score(target,actual)==score(target,altered)
    altered=dict(actual,cuePath=[[0,0]]+actual['cuePath'])
    checks['precontact_path_does_not_affect_score']=score(target,actual)==score(target,altered)
    assert all(checks.values()),checks
    output=dict(version='prototype-r1',date='2026-10-22',ballDiameter=D,sample=SAMPLE,scenarios=scenarios,
                formula=dict(earlyPoints=30,wholePoints=40,stopPoints=30,earlyLengthMetres=.30,
                             routeHalfCreditMetres=D,stopHalfCreditMetres=2*D,samplesPerSegment=121),
                sourceHashes=source_hashes)
    save('examples.json',output)
    save('validation.json',dict(checks=checks,physicsFilesCompared=len(physics),physicsDrift=drift,
                                sourceHashes=source_hashes,caseCount=sum(len(s['cases']) for s in scenarios)))
    for s in scenarios:
        print(s['title'],s['target']['id'])
        for c in s['cases']:print(c['label'],c['shot']['id'],round(c['score']['total'],1),'stop cm',round(c['score']['stopCm'],1),c['score']['status'])

if __name__=='__main__': main()
