from pathlib import Path
import importlib.util,math,random,json,statistics as st
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-front-core-20261027'
spec=importlib.util.spec_from_file_location('core_study',ROOT/'research/rack-core-energy-20261027/study.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
R,M,L,F,seed,SLOTS,CORE=old.R,old.M,old.L,old.F,old.seed,old.SLOTS,old.CORE
SENSITIVE=[1,2,4,7,8]
PARENT=dict(rotations=dict(feed=60,corefront=0,corerear=90,back=0))
def write(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
def definitions():
    ans={'parentB':dict(kind='rotate',angles=[0]*5)}
    def add(name,slots,angle):ans[name]=dict(kind='rotate',angles=[angle if i in slots else 0 for i in SENSITIVE])
    for a in [-180,-135,-90,-45,45,90,135]:add(f'front_{a}',[4],a)
    for group,indices in [('entry',[1,2]),('exit',[7,8])]:
        for a in [-120,-90,-60,-30,30,60,90,120,180]:add(f'{group}_{a}',indices,a)
    for phase in ['seed','locked']:
        for entering in ['toward','lateral']:
            for front in ['forward','backward']:
                ans[f'gate_{phase}_{entering}_{front}']=dict(kind='gate',phase=phase,entering=entering,front=front)
    for a in [-90,-45,45,90,180]:add(f'stagger_{a}',[1],a)
    rng=random.Random(202610271001);seen={tuple(v['angles']) for v in ans.values() if v['kind']=='rotate'}
    while len(ans)<99:
        v=tuple(rng.choice([-180,-120,-90,-60,-30,0,30,60,90,120,180]) for _ in range(5))
        if v in seen:continue
        seen.add(v);ans[f'mixed_{len(ans)-39:02}']=dict(kind='rotate',angles=list(v))
    assert len(ans)==99
    return ans

def positions(generated,definition):
    parent=old.positions(generated,PARENT);ans=[p[:] for p in parent];slots=generated['slots'];original=[[b['x'],b['z']] for b in generated['rack']]
    rng=random.Random(seed(f"layout-directions:{generated['input']['seed']}"))
    for _ in range(15):rng.uniform(-math.pi,math.pi)
    phase=rng.uniform(-math.pi/6,math.pi/6)
    for j,i in enumerate(SENSITIVE):
        x,z=slots[i];bx,bz=parent[i];mag=math.dist(slots[i],original[i]);sign=-1 if z<0 else 1
        if definition['kind']=='rotate':
            angle=definition['angles'][j]
            if angle==0:continue
            theta=math.atan2(bz-z,bx-x)+math.radians(angle)*sign
        else:
            if i in [1,2]:vx,vz=(-math.sqrt(3)/2,-.5*sign) if definition['entering']=='toward' else (0,-sign)
            elif i==4:vx,vz=(1,0) if definition['front']=='forward' else (-1,0)
            else:vx,vz=-math.sqrt(3)/2,.5*sign
            theta=math.atan2(vz,vx)+(phase*sign if definition['phase']=='seed' else 0)
        ans[i]=[F(x+mag*math.cos(theta)),F(z+mag*math.sin(theta))]
    for i,(s,p) in enumerate(zip(slots,ans)):
        assert abs(math.dist(s,p)-math.dist(s,original[i]))<1e-7 and math.dist(s,p)<.00009015
        for j in range(i):assert math.dist(p,ans[j])-2*R>.0000195
        if i not in SENSITIVE:assert p==parent[i]
    assert ans[0]==original[0]
    return ans

def metrics(row):
    names=row['canonicalNames'];byName={'_'+str(b['number']):b for b in row['rack']}
    # Analysis-only identity normalization; a registration permutation must not change initial references.
    s=old.metrics(dict(row,rack=[byName[n] for n in names]));front=names[4]
    for sample in row['samples']:
        ms=round(sample['delay']*1000);states=dict(zip(row['names'],sample['states']));b=states[front]
        s[f'frontSpeed{ms}']=math.sqrt(sum(v*v for v in b['v']))
        initial=next(a for a in row['rack'] if '_'+str(a['number'])==front)
        s[f'frontTravel{ms}']=math.hypot(b['p'][0]-initial['x'],b['p'][2]-initial['z'])
        s[f'allMeanSpeed{ms}']=st.mean(math.sqrt(sum(v*v for v in states[n]['v'])) for n in names)
    s['frontObjective']=min(s['frontSpeed5'],s['frontSpeed20'])
    s['frontAbove1']=int(s['frontObjective']>=1)
    s['frontAbove05']=int(s['frontObjective']>=.5)
    firstIn=None;firstLoss=None;gains=losses=0.;peak=0.;lossCount=0;gainsBeforeLoss=0
    for ev in row['eventTrace']:
        if ev['kind']!='ball' or ev['t']-row['t0']>.005:continue
        for side,oth in [('A','B'),('B','A')]:
            if ev['pre'+side]['name']!=front:continue
            e=lambda k:.5*M*sum(v*v for v in ev[k]['v'])
            before,after=e('pre'+side),e('post'+side);delta=after-before;peak=max(peak,before,after)
            if delta>0:
                if firstIn is None:firstIn=ev['t']-row['t0']
                if firstLoss is None:gainsBeforeLoss+=1
                gains+=delta
            else:
                if firstLoss is None:firstLoss=ev['t']-row['t0']
                losses-=delta;lossCount+=1
    s.update(frontPeakJ=peak,frontPositiveChanges=gains,frontNegativeChanges=losses,frontLossCount=lossCount,frontGainsBeforeFirstLoss=gainsBeforeLoss,
             frontFirstInMS=1000*(firstIn if firstIn is not None else 30),frontFirstLossMS=1000*(firstLoss if firstLoss is not None else 30),frontHasLoss=int(firstLoss is not None))
    return s
aggregate=old.aggregate
def eligible(a,p):return all(a[p][k]>=f*a['parentB'][k] for k,f in [('energy5',.95),('nEff5',.9),('active5',.9),('gap20',.9),('coreEnergy5',.9)])
