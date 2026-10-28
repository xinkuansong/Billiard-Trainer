"""Independent, event-based acceptance and adversarial evidence checks."""
from pathlib import Path
import copy, collections, hashlib, json, math, struct
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/k-ball-samples-20261028'
C,A,B='cueBall','object','kTarget'
def pair(e,a,b): return e['kind']=='ballBall' and set(e['balls'])=={a,b}
def accepted(row):
    ev=row['events']; first=next((i for i,e in enumerate(ev) if e['kind']=='ballBall' and C in e['balls']),None)
    if row['termination']!='settled' or first is None or not pair(ev[first],C,A):return False
    k=next((i for i,e in enumerate(ev) if i>first and pair(e,C,B)),None)
    return (k is not None and any(e['kind']=='pocket' and e['ball']==A and e['pocket']==f"pocket_{row['seed']['pocket']}" for e in ev)
            and not any(e['kind']=='pocket' and e['ball']==C for e in ev) and C not in row['pocketedBalls'])
def run():
    rows=json.loads((OUT/'samples.json').read_text()); replay=json.loads((OUT/'replay.json').read_text()); generation=json.loads((OUT/'generation.json').read_text())
    assert len(rows)==len(replay)==30
    assert len({r['seed']['layout'] for r in rows})==30
    assert collections.Counter(r['category'] for r in rows)=={0:10,1:10,2:10}
    radius=generation['radius']; rejected=0; residuals=[]; signatures=set()
    seed_rows=json.loads((OUT/'seeds.json').read_text());seed_map={(s['layout'],s['route']):s for s in seed_rows}
    f32=lambda x:struct.pack('f',x)
    for row,again in zip(rows,replay):
        assert accepted(row),row['id']
        assert row['id']==again['id'] and again['success'] and again['exactReplay']
        assert len(again['perturbations'])==8
        s=row['seed'];old=seed_map[s['layout'],s['route']]
        for key in ('v','sx','sy'):assert f32(s[key])==f32(old[key])
        for key in ('cue','object','dir'):assert all(f32(a)==f32(b) for a,b in zip(s[key],old[key]))
        ev=row['events'];assert all(e['index']==i for i,e in enumerate(ev))
        assert all(a['time']<=b['time'] for a,b in zip(ev,ev[1:]))
        first=next(i for i,e in enumerate(ev) if pair(e,C,A));hit=next(i for i,e in enumerate(ev) if i>first and pair(e,C,B))
        rails=[e['cushion'] for e in ev[first+1:hit] if e['kind']=='cushion' and e['ball']==C and 0<=e['cushion']<6]
        assert rails==row['railsBeforeK'] and min(len(rails),2)==row['category']
        positions=[s['cue'],s['object'],row['B']]
        assert all(math.dist(a,b)>2*radius for i,a in enumerate(positions) for b in positions[i+1:])
        assert all(abs(p[0])<=1.27-radius and abs(p[1])<=.635-radius for p in positions)
        # Mirror-equivalent layouts are one coverage item (rounded at 0.1 mm).
        key=min(tuple(round(v*sign,4) for p in positions for v,sign in zip(p,(sx,sz))) for sx in (-1,1) for sz in (-1,1))
        assert key not in signatures;signatures.add(key)
        t=ev[hit]['time']
        contact=[]
        for name in (C,B):
            tr=row['tracks'][name];assert all(all(math.isfinite(v) for v in p) for p in tr)
            assert all(a[0]<b[0] for a,b in zip(tr,tr[1:]))
            p=next(p for p in tr if p[0]==t);contact.append(p[1:])
        residual=abs(math.dist(*contact)-2*radius);residuals.append(residual)
        assert residual<0.0001,(row['id'],residual)
        changes=[]
        r=copy.deepcopy(row);r['termination']='timeLimit';changes.append(r)
        r=copy.deepcopy(row);r['events']=[e for e in ev if not pair(e,C,B)];changes.append(r)
        r=copy.deepcopy(row);r['events']=[e for e in ev if not(e['kind']=='pocket' and e['ball']==A)];changes.append(r)
        r=copy.deepcopy(row);r['seed']['pocket']=(s['pocket']+1)%6;changes.append(r)
        r=copy.deepcopy(row);r['events'].insert(0,{'kind':'ballBall','balls':[C,B]});changes.append(r)
        r=copy.deepcopy(row);r['events'].append({'kind':'pocket','ball':C,'pocket':'pocket_0'});changes.append(r)
        r=copy.deepcopy(row);r['events'][first],r['events'][hit]=r['events'][hit],r['events'][first];changes.append(r)
        for r in changes:assert not accepted(r);rejected+=1
    perturb=collections.Counter(sum(p['success'] for p in r['perturbations']) for r in replay)
    report={'passed':True,'samples':30,'uniqueLayouts':30,'mirrorUniqueAtPoint1mm':len(signatures),'categories':dict(collections.Counter(len(r['railsBeforeK']) for r in rows)),
            'pockets':dict(collections.Counter(r['seed']['pocket'] for r in rows)),
            'eventExactReplays':30,'perturbations':240,'perturbationSuccesses':sum(k*v for k,v in perturb.items()),
            'perturbationSuccessCountHistogram':dict(perturb),'adversarialRejections':rejected,
            'maxContactResidualMeters':max(residuals),'BPocketedIDs':[r['id'] for r in rows if B in r['pocketedBalls']],
            'sha256':{name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['samples.json','replay.json','seeds.json','source-binding.json']}}
    (OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':run()
