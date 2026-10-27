from pathlib import Path
import importlib.util,math,random,json,statistics as st
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-core-energy-20261027'
spec=importlib.util.spec_from_file_location('previous_study',ROOT/'research/rack-energy-layout-20261027/study.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
R,M,L,F,seed,SLOTS=old.R,old.M,old.L,old.F,old.seed,old.SLOTS
GROUPS={'feed':[1,2,3,5],'corefront':[4],'corerear':[7,8],'back':[11,12,13]}
CORE=[4,7,8]
def write(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
def definitions():
    ans={'parent':dict(rotations={k:0 for k in GROUPS})}
    for g in GROUPS:
        for angle in [-90,-45,90,180]:ans[f'{g}_{angle}']=dict(rotations={k:angle if k==g else 0 for k in GROUPS})
    rng=random.Random(202610270801);seen={tuple(v['rotations'].values()) for v in ans.values()}
    while len(ans)<41:
        v=tuple(rng.choice([-180,-90,-45,0,45,90,135]) for _ in GROUPS)
        if v in seen:continue
        seen.add(v);ans[f'combo_{len(ans)-17:02}']=dict(rotations=dict(zip(GROUPS,v)))
    for feed in [-60,60]:
        for front in [0,180]:
            for rear in [-90,90]:
                ans[f'late_{feed}_{front}_{rear}']=dict(rotations=dict(feed=feed,corefront=front,corerear=rear,back=0))
    assert len(ans)==49
    return ans

def positions(generated,definition):
    parent=old.positions(generated,'inner_first',dict(kind='inner_first'))
    if all(a==0 for a in definition['rotations'].values()):return parent
    ans=[p[:] for p in parent];slots=generated['slots'];original=[[b['x'],b['z']] for b in generated['rack']]
    for g,angle in definition['rotations'].items():
        if angle==0:continue
        for i in GROUPS[g]:
            x,z=slots[i];bx,bz=parent[i];mag=math.dist(slots[i],original[i]);sign=-1 if z<0 else 1
            theta=math.atan2(bz-z,bx-x)+math.radians(angle)*sign
            ans[i]=[F(x+mag*math.cos(theta)),F(z+mag*math.sin(theta))]
    for i,(s,p) in enumerate(zip(slots,ans)):
        assert abs(math.dist(s,p)-math.dist(s,original[i]))<1e-7 and math.dist(s,p)<.00009015
        for j in range(i):assert math.dist(p,ans[j])-2*R>.0000195
    assert ans[0]==original[0]
    return ans

def metrics(row):
    s=old.metrics(row);names=row['canonicalNames'];core=[names[i] for i in CORE];initial={n:[row['rack'][i]['x'],row['rack'][i]['z']] for i,n in enumerate(names)}
    for sample in row['samples']:
        ms=round(sample['delay']*1000);states=dict(zip(row['names'],sample['states']));e=[.5*M*sum(v*v for v in states[n]['v']) for n in core]
        s.update({f'coreEnergy{ms}':sum(e),f'coreBalanced{ms}':sum(math.sqrt(x) for x in e),f'coreActive{ms}':sum(x>=.5*M for x in e),
                  f'coreMinEnergy{ms}':min(e),f'coreTravel{ms}':st.mean(math.dist([states[n]['p'][0],states[n]['p'][2]],initial[n]) for n in core)})
        for i,ee in zip(CORE,e):s[f'slot{i}Energy{ms}']=ee
        gaps=[]
        for i in range(15):
            for j in range(i):
                if (i in CORE or j in CORE) and math.dist(row['slots'][i],row['slots'][j])<2*R+.001:
                    gaps.append(math.dist([states[names[i]]['p'][k] for k in [0,2]],[states[names[j]]['p'][k] for k in [0,2]])-2*R)
        s[f'coreNeighborGap{ms}']=st.mean(gaps)
    first={};peak={n:0 for n in core};gain=loss=0.;outsideGain=outsideLoss=0.;outPairs={}
    for ev in row['eventTrace']:
        if ev['kind']!='ball' or ev['t']-row['t0']>.005:continue
        for side,other in [('A','B'),('B','A')]:
            pre,post=ev['pre'+side],ev['post'+side];n=pre['name']
            if n not in core:continue
            before=.5*M*sum(v*v for v in pre['v']);after=.5*M*sum(v*v for v in post['v']);delta=after-before
            first.setdefault(n,ev['t']-row['t0']);peak[n]=max(peak[n],before,after);gain+=max(delta,0);loss+=max(-delta,0)
            if ev['pre'+other]['name'] not in core:
                outsideGain+=max(delta,0);outsideLoss+=max(-delta,0)
    s.update(coreSumIndividualPeak=sum(peak.values()),corePositiveChanges=gain,coreNegativeChanges=loss,
             coreOutsidePositiveChanges=outsideGain,coreOutsideNegativeChanges=outsideLoss,
             coreFirstMS=st.mean(first.get(n,30)*1000 for n in core))
    # Reward retained motion across all three, not a single fast core ball or a transient peak.
    s['coreObjective']=.5*(s['coreBalanced5']+s['coreBalanced20'])
    return s
aggregate=old.aggregate
