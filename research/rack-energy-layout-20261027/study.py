"""Frozen-engine layout experiment; no production imports are mutated."""
import math, random, hashlib, struct, statistics as st, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/rack-energy-layout-20261027'
CAL=json.load(open(ROOT/'output/rack-center-mechanism-20261026/calibration.json'))
R=.028574999421834946
L=2.5399999618530273
M=.17000000178813934
F=lambda x:struct.unpack('f',struct.pack('f',x))[0]
SLOTS=[(r,c) for r in range(5) for c in range(r+1)]
def seed(label):return int.from_bytes(hashlib.sha256(label.encode()).digest()[:8],'big')
def definitions():
    out={k:dict(kind=k) for k in ['baseline','independent','inward','outward','forward','backward','transverse_in','transverse_out','inner_first','outer_first','row_alternate','reverse_offsets']}
    # Fixed symmetric direction templates, generated before viewing outcomes.
    rng=random.Random(202610270601)
    for k in range(20):
        angles=[]; lookup={}
        for r,c in SLOTS:
            key=(r,min(c,r-c))
            if key not in lookup:lookup[key]=rng.uniform(-math.pi,math.pi) if c!=r-c else rng.choice([0.,math.pi])
            angles.append(lookup[key] if c<=r/2 else -lookup[key])
        out[f'template_{k:02}']=dict(kind='template',angles=angles)
    return out

def positions(base, policy, definition):
    slots=base['slots']; p=[[b['x'],b['z']] for b in base['rack']]
    if policy=='baseline':return p
    rng=random.Random(seed(f"layout-directions:{base['input']['seed']}"))
    independent=[rng.uniform(-math.pi,math.pi) for _ in slots]
    phase=rng.uniform(-math.pi/6,math.pi/6)
    cx=st.mean(s[0] for s in slots)
    ans=[]
    for i,((x,z),(bx,bz),(rr,cc)) in enumerate(zip(slots,p,SLOTS)):
        if i==0:ans.append([bx,bz]);continue # Identical apex and actual strike for every paired policy.
        mag=math.hypot(bx-x,bz-z); sign=1 if z>0 else -1 if z<0 else 0
        kind=definition['kind']; outer=cc==0 or cc==rr
        if kind=='independent':theta=independent[i]
        elif kind=='reverse_offsets':theta=math.atan2(bz-z,bx-x)+math.pi
        else:
            vectors={'inward':(cx-x,-z),'outward':(x-cx,z),'forward':(1,0),'backward':(-1,0),
                     'transverse_in':(0,-sign or 1),'transverse_out':(0,sign or 1),
                     'inner_first':(-1 if outer else 1,-.5*sign),
                     'outer_first':(1 if outer else -1,.5*sign),
                     'row_alternate':((-1)**rr,sign)}
            theta=definition['angles'][i] if kind=='template' else math.atan2(vectors[kind][1],vectors[kind][0])
            theta+=phase*(sign or 1)
        ans.append([F(x+mag*math.cos(theta)),F(z+mag*math.sin(theta))])
    # Double arithmetic checks actual Float-rounded geometry, not requested coordinates.
    for i,(s,b,q) in enumerate(zip(slots,p,ans)):
        assert abs(math.dist(s,b)-math.dist(s,q))<1e-7
        assert math.dist(s,q)<.00009015
        for j in range(i):assert math.dist(q,ans[j])-2*R>0.0000195
    assert ans[0]==p[0]
    return ans

def energy(s):return .5*M*(sum(v*v for v in s['v'])+.4*R*R*sum(w*w for w in s['w']))
def ulp(x):return math.ldexp(1.,max(-126,math.frexp(abs(x))[1]-1)-23)
def metrics(row):
    assert row['status']=='settled',row['status']
    slots=row['slots']; neighbors=[(i,j) for i in range(15) for j in range(i) if math.dist(slots[i],slots[j])<2*R+.001]
    assert len(neighbors)==30
    names=row['canonicalNames']; result={}
    for sample in row['samples']:
        ms=round(sample['delay']*1000); states=dict(zip(row['names'],sample['states'])); a=[states[n] for n in names]
        v2=[sum(v*v for v in s['v']) for s in a]; total=sum(v2); shares=[e/total for e in v2]
        speeds=[math.sqrt(e) for e in v2]; rates=[]; gaps=[]
        for i,j in neighbors:
            dp=[a[i]['p'][k]-a[j]['p'][k] for k in [0,2]]; dv=[a[i]['v'][k]-a[j]['v'][k] for k in [0,2]]; d=math.hypot(*dp)
            rates.append(sum(x*y for x,y in zip(dp,dv))/d);gaps.append(d-2*R)
        result.update({f'nEff{ms}':1/sum(e*e for e in shares),f'cornerShare{ms}':shares[10]+shares[14],
                       f'active{ms}':sum(v>=1 for v in speeds),f'sep{ms}':sum(v>1e-5 for v in rates)/30,
                       f'gap{ms}':st.mean(gaps),f'rate{ms}':st.mean(rates),f'energy{ms}':.5*M*total,
                       f'slow{ms}':sum(v<.1 for v in speeds),f'maxSpeed{ms}':max(speeds),
                       f'interiorShare{ms}':sum(shares[i] for i in [4,7,8])})
    stats=dict(contacts=0,nonApproaching=0,gapOutsideBudget=0,energyGain=0,maxOverlap=0.,maxMomentumResidual=0.)
    for e in row['eventTrace']:
        if e['kind']!='ball':continue
        a,b=e['preA'],e['preB'];aa,bb=e['beforeKissA'],e['beforeKissB']
        dp=[b['p'][i]-a['p'][i] for i in [0,2]];d=math.hypot(*dp)
        closing=-sum(dp[j]*(b['v'][i]-a['v'][i]) for j,i in enumerate([0,2]))/d
        gap=math.hypot(bb['p'][0]-aa['p'][0],bb['p'][2]-aa['p'][2])-2*R
        budget=4*(math.hypot(ulp(aa['p'][0])+ulp(bb['p'][0]),ulp(aa['p'][2])+ulp(bb['p'][2]))+ulp(R))
        gain=energy(e['postA'])+energy(e['postB'])-energy(a)-energy(b)
        momentum=math.sqrt(sum((M*(e['postA']['v'][i]+e['postB']['v'][i]-a['v'][i]-b['v'][i]))**2 for i in range(3)))
        stats['contacts']+=1;stats['nonApproaching']+=closing<=0;stats['gapOutsideBudget']+=gap>budget+1e-14
        stats['energyGain']+=gain>1e-6;stats['maxOverlap']=max(stats['maxOverlap'],-gap);stats['maxMomentumResidual']=max(stats['maxMomentumResidual'],momentum)
    pts=[p for n,p in row['board'].items() if n!='cueBall'];n=len(pts)
    result.update(score=st.mean(min(math.dist(a,b)*L for j,b in enumerate(pts) if i!=j) for i,a in enumerate(pts))/CAL['reference'][str(n)]['expectedMeanM'] if n>1 else 0.,
                  tail=max(s['tail'] for s in row['spinTail']),peakSpin=max(s['peakWy'] for s in row['spinTail']),scratch=int(row['cueScratched']),
                  cpuMS=1000*row['cpuSeconds'],pocketed=len(row['pocketed']),duration=row['duration'],**stats)
    result['objective']=result['nEff5']/15+result['sep20']+result['active5']/15
    result.update(policy=row['input']['policy'],cohort=row['input']['cohort'],id=row['input']['rackID'],condition=row['input']['condition'])
    return result

def aggregate(rows):
    return {p:{k:st.mean(s[k] for s in a) for k in a[0] if isinstance(a[0][k],(float,int)) and k!='id'}|dict(n=len(a))
            for p in sorted({s['policy'] for s in rows}) if (a:=[s for s in rows if s['policy']==p])}

def write(name,data):(OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
