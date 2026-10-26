"""One scalar dispersion index, finite-table calibration, independently checked atlas data."""
from pathlib import Path
import hashlib, json, math, random, statistics, time
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'output/multi-ball-generation-20261026'
VERSION='mean-nearest-finite-table-v1'

def write(name,data):
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def nearest(points):
    points=np.asarray(points,dtype=np.float64)
    d=np.linalg.norm(points[..., :,None,:]-points[...,None,:,:],axis=-1)
    d[...,np.arange(points.shape[-2]),np.arange(points.shape[-2])]=np.inf
    return d.min(axis=-1)

def scalar_mean(points):
    return statistics.mean(min(math.hypot(a[0]-b[0],a[1]-b[1]) for j,b in enumerate(points) if j!=i) for i,a in enumerate(points))

def calibrate(meta):
    L,W,R=meta['length'],meta['width'],meta['radius']
    half=np.array([L/2-R,W/2-R]);pockets=np.array(meta['pockets'])
    # Whole iid configurations are accepted/rejected, not sequential point addition.
    # Reference domain matches the conservative production draggable-ball domain.
    reference={}
    for n in range(4,16):
        datasets=[];audit=[]
        for split,count in [('train',50000),('holdout',10000)]:
            rng=np.random.default_rng(2026102600+n+(1000 if split=='holdout' else 0))
            values=[];attempted=0;stored=[]
            while sum(len(a) for a in values)<count:
                p=rng.uniform(-half,half,size=(1024,n,2));attempted+=len(p)
                nn=nearest(p)
                valid=(nn.min(axis=1)>=2*R)
                valid &= (np.linalg.norm(p[:,:,None,:]-pockets[None,None,:,:],axis=-1).min(axis=(1,2))>=2*R+0.005)
                remaining=count-sum(len(a) for a in values)
                accepted=p[valid][:remaining];v=nn[valid].mean(axis=1)[:remaining]
                values.append(v)
                if len(stored)<12:stored.extend(accepted[:12-len(stored)].tolist())
            a=np.concatenate(values)
            for p in stored:
                assert abs(scalar_mean(p)-float(nearest(p).mean()))<1e-12
            datasets.append(a)
            audit.append(dict(split=split,count=count,attempted=attempted,mean=float(a.mean()),
                standardError=float(a.std(ddof=1)/math.sqrt(count)),checkPoints=stored))
        train,held=datasets
        den=float(train.mean());theory=0.5*math.sqrt(L*W/n)
        uncertainty=math.hypot(audit[0]['standardError'],audit[1]['standardError'])
        assert abs(held.mean()-den)<5*uncertainty
        reference[str(n)]=dict(expectedMeanM=den,theoryMeanM=theory,correctionFactor=den/theory,
            relativeSE=audit[0]['standardError']/den,holdoutMeanIndex=float(held.mean()/den),
            holdoutPercentiles={str(q):float(np.percentile(held/den,q)) for q in [1,5,10,50,90,95,99]},
            splits=audit)
    result=dict(version=VERSION,method='mean nearest centre distance / random finite-table expected mean',
        calibrationSampling='whole independent uniform configurations; reject entire set for overlaps or production pocket-clearance violation',
        domain=dict(length=L,width=W,radius=R,centerInset=R,pocketClearanceCenterM=2*R+0.005,pockets=meta['pockets']),reference=reference)
    write('calibration.json',result)
    return result

def metrics(points,cal):
    n=len(points);d=float(nearest(points).mean());ref=cal['reference'][str(n)]
    return dict(index=d/ref['expectedMeanM'],theoryIndex=d/ref['theoryMeanM'],meanNearestCM=d*100,metricVersion=VERSION)

def audit_metrics(cal):
    checks=[]
    square=np.array([[0,0],[.2,0],[0,.2],[.2,.2]])
    assert abs(nearest(square).mean()-.2)<1e-12;checks.append('known_square_20cm')
    for n in range(4,16):
        p=np.array(cal['reference'][str(n)]['splits'][0]['checkPoints'][0]);d=scalar_mean(p)
        for name,q in [('order',p[::-1]),('translation',p+[.371,-.217]),('mirror',p*[-1,1]),('rotation',p[:,::-1]*[-1,1])]:
            assert abs(float(nearest(q).mean())-d)<1e-12;checks.append(f'{n}_{name}')
        assert abs(float(nearest(p*3).mean())/(3*cal['reference'][str(n)]['expectedMeanM'])-metrics(p,cal)['index'])<1e-12
        checks.append(f'{n}_scale')
    # Constructive limitation: same mean index can conceal different local cluster structure.
    compact=np.array([[-.12,-.08],[-.06,-.08],[0,-.08],[-.12,-.02],[-.06,-.02],[0,-.02]])
    one_far=compact.copy();one_far[-1]=[1,.5]
    regular=np.array([[-.7,-.35],[0,-.35],[.7,-.35],[-.7,.35],[0,.35],[.7,.35]])
    fixtures=[]
    for name,p in [('紧密球团',compact),('五球扎堆加一颗远球',one_far),('均匀散开',regular)]:
        fixtures.append(dict(id='synthetic-'+str(len(fixtures)),label=name,kind='diagnostic',n=6,
            balls=[dict(number=i+1,x=float(a[0]),z=float(a[1])) for i,a in enumerate(p)],**metrics(p,cal)))
    assert fixtures[0]['index']<fixtures[1]['index']<fixtures[2]['index'];checks.append('cluster_outlier_spread_order')
    write('metric-tests.json',dict(passed=True,checks=checks,count=len(checks),
        limitation='A far isolated ball raises the mean even while a cluster remains; this is not a guarantee of no clusters or clearability.'))
    return fixtures

def analyze(cal,meta):
    L,W,R=meta['length'],meta['width'],meta['radius'];bases=[];summary=[];seen=set();checks=0
    for n in [4,5,6,7,8,9,15]:
        rows=[json.loads(x) for x in (OUT/f'raw-{n}.jsonl').read_text().splitlines()]
        expected=set(f'_{i}' for i in (range(1,16) if n==15 else (range(1,10) if n==9 else (list(range(1,n))+[9] if n in [4,5,6] else range(1,n+1)))))
        counts=dict(attempts=len(rows),invalidInput=0,incomplete=0,targetPotted=0,invalidGeometry=0,duplicate=0,accepted=0,allBallsZero=0)
        runtime=[];gaps=[];indices=[]
        for row in rows:
            job=row['input'];assert job['n']==n and 9.5<=job['power']<=10
            assert L/4<=job['x']<=L/2-R and abs(job['z'])<=W/2-R
            assert set('_'+str(b['number']) for b in row['rack'])==expected
            if row['status']=='invalid_input':counts['invalidInput']+=1;continue
            runtime.append(row['seconds'])
            if row['status']!='settled':counts['incomplete']+=1;continue
            potted=set(row['pocketed']);board=row['board']
            assert set(board)|potted==expected|{'cueBall'}
            assert not(set(board)&potted)
            assert bool(row['cueScratched'])==('cueBall' in potted)
            if potted & expected:counts['targetPotted']+=1;continue
            assert set(board)-{'cueBall'}==expected
            balls=[dict(number=int(k[1:]),x=v[0]*L-L/2,z=v[1]*L-W/2) for k,v in sorted(board.items()) if k!='cueBall']
            points=np.array([[b['x'],b['z']] for b in balls]);assert np.isfinite(points).all()
            gap=float(nearest(points).min()-2*R);gaps.append(gap)
            # Retain lip-adjacent legal positions; broad cloth bounds plus radius allowance.
            if gap < -1e-5 or (abs(points[:,0])>L/2+R).any() or (abs(points[:,1])>W/2+R).any():
                counts['invalidGeometry']+=1;continue
            signature=tuple(sorted((b['number'],round(b['x'],6),round(b['z'],6)) for b in balls))
            if (n,signature) in seen:counts['duplicate']+=1;continue
            seen.add((n,signature))
            score=metrics(points,cal);assert abs(score['meanNearestCM']/100-scalar_mean(points))<1e-12
            for b in balls:
                old=board['_'+str(b['number'])]
                assert abs((b['x']+L/2)/L-old[0])<1e-12 and abs((b['z']+W/2)/L-old[1])<1e-12
            checks+=1;counts['accepted']+=1;counts['allBallsZero']+=int(not potted);indices.append(score['index'])
            bases.append(dict(id=job['id'],kind='base',n=n,balls=balls,cueScratched=row['cueScratched'],
                power=job['power'],cueStart=[job['x'],job['z']],seed=job['seed'],
                rackStatus='production-fallback-unconfirmed' if n in [7,8] else 'production',**score))
        assert sum(counts[k] for k in ['invalidInput','incomplete','targetPotted','invalidGeometry','duplicate','accepted'])==len(rows)
        summary.append(dict(n=n,**counts,acceptanceRate=counts['accepted']/len(rows),
            nativeSeconds=sum(runtime),medianSimulationSeconds=statistics.median(runtime) if runtime else None,
            minimumSurfaceGapM=min(gaps) if gaps else None,
            indexPercentiles={str(q):float(np.percentile(indices,q)) for q in [0,10,25,50,75,90,100]} if indices else {},
            thresholdPreview={str(t):sum(x>=t for x in indices) for t in [.5,.6,.7,.8,.9,1.0]},
            rawSHA256=digest(OUT/f'raw-{n}.jsonl')))
    variants=[]
    for base in (b for b in bases if b['n']==15):
        for own_count in range(4,9):
            for opponent_mode in ['none','random']:
                seed=f"20261026/{base['id']}/{own_count}/{opponent_mode}";rng=random.Random(seed)
                solid=rng.choice([True,False]);own=list(range(1,8) if solid else range(9,16));opp=list(range(9,16) if solid else range(1,8))
                k=0 if opponent_mode=='none' else rng.randint(1,7)
                own_keep=rng.sample(own,own_count-1);opp_keep=rng.sample(opp,k)
                keep=set(own_keep+opp_keep+[8]);balls=[dict(b) for b in base['balls'] if b['number'] in keep]
                assert len(balls)==own_count+k and 8 in keep and len(keep&set(own))==own_count-1 and len(keep&set(opp))==k
                assert all(b in base['balls'] for b in balls)
                points=[[b['x'],b['z']] for b in balls]
                variants.append(dict(id=f"{base['id']}-own{own_count}-{opponent_mode}",kind='variant',baseID=base['id'],
                    n=len(balls),ownCount=own_count,ownGroup='全色' if solid else '花色',opponentMode=opponent_mode,
                    opponentCount=k,ownNumbers=own_keep+[8],balls=balls,variantSeed=seed,**metrics(points,cal)))
    write('base-candidates.json',bases);write('variants.json',variants)
    write('summary.json',dict(pilot=True,formalBankComplete=False,metric=VERSION,threshold=None,counts=summary,
        totalCandidates=len(bases),variantCount=len(variants),geometryAndMetricChecked=checks,
        mainAdmission='zero target balls pocketed; cue scratches retained and labelled',
        sourceSHA256=digest(OUT/'source-binding.json'),calibrationSHA256=digest(OUT/'calibration.json')))
    return bases,variants

def main():
    meta=json.loads((OUT/'metadata-4.json').read_text())
    calibration_path=OUT/'calibration.json'
    cal=json.loads(calibration_path.read_text()) if calibration_path.exists() else calibrate(meta)
    fixtures=audit_metrics(cal)
    assert json.loads((OUT/'generation.json').read_text())['completed']
    bases,variants=analyze(cal,meta)
    write('atlas-data.json',dict(meta=meta,reference=cal['reference'],boards=bases+variants+fixtures))
    print(json.dumps(dict(bases=len(bases),variants=len(variants),calibrationSamples=720000,metricTests=62),ensure_ascii=False))

if __name__=='__main__':main()
