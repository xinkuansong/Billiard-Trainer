"""Re-read the prior 200 held-out parent racks; no new simulation or mutation."""
from study import *
import gzip,collections
allrows=[];examples=[];edges=collections.defaultdict(lambda:[0,0.,0.])
for line in gzip.open(ROOT/'output/rack-energy-layout-20261027/raw.jsonl.gz','rt'):
    r=json.loads(line)
    if r['input']['cohort']!='holdout' or r['input']['policy']!='inner_first':continue
    s=metrics(r);allrows.append(s);names=r['canonicalNames'];events=[]
    for ev in r['eventTrace']:
        if ev['kind']!='ball' or ev['t']-r['t0']>.005:continue
        for side,other in [('A','B'),('B','A')]:
            name=ev['pre'+side]['name']
            if name not in names or names.index(name) not in CORE:continue
            partner=ev['pre'+other]['name'];idx=names.index(partner) if partner in names else -1
            ee=lambda k:.5*M*sum(v*v for v in ev[k]['v'])
            pre,post=ee('pre'+side),ee('post'+side);opre,opost=ee('pre'+other),ee('post'+other)
            slot=names.index(name)
            events.append(dict(slot=slot,partner=idx,ms=(ev['t']-r['t0'])*1000,preJ=pre,postJ=post,partnerPreJ=opre,partnerPostJ=opost))
            if post<pre and idx not in CORE:
                key=f'{slot}->{idx}';a=edges[key];a[0]+=1;a[1]+=pre-post;a[2]+=max(opost-opre,0)
    if r['input']['rackID'] in [40000,40001]:examples.append(dict(id=r['input']['rackID'],events=events))
write('parent-diagnosis.json',dict(n=len(allrows),metrics=aggregate(allrows),
    externalLossEdges={k:dict(count=v[0],coreLossJ=v[1]/200,partnerGainJ=v[2]/200) for k,v in sorted(edges.items(),key=lambda x:x[1][1],reverse=True)},
    examples=examples,note='Positive/negative changes may count energy repeatedly; individual peak sum is not a simultaneous group peak.'))
print('parent diagnosis',len(allrows))
