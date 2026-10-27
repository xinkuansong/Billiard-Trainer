from pathlib import Path
import gzip,json,math,statistics as st
from collections import Counter

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-stability-20261027';FOLDER=OUT/'stage2'
def main():
    winner=json.loads((FOLDER/'selection.json').read_text())['selected'][-1]
    rows={};mass=None
    with gzip.open(FOLDER/'raw.jsonl.gz','rt') as f:
        for line in f:
            r=json.loads(line);q=r['input']
            if q['cohort']!='holdout' or q['condition']!='original' or q['policy'] not in ['C',winner]:continue
            mass=r['parameters']['ballMass'];index={n:i for i,n in enumerate(r['canonicalNames'])}
            sm=next(s for s in r['samples'] if round(s['delay']*1000)==5);by=dict(zip(r['names'],sm['states']))
            v=[math.sqrt(sum(x*x for x in by[n]['v'])) for n in r['canonicalNames']]
            first={};sequence=[]
            for e in r['eventTrace']:
                if e['kind']!='ball' or e['t']-r['t0']>.005:continue
                names=[e['pre'+s]['name'] for s in ['A','B']]
                sequence.append(dict(us=(e['t']-r['t0'])*1e6,pair=sorted(index.get(n,-1) for n in names)))
                for side,other in [('A','B'),('B','A')]:
                    src=index.get(e['pre'+side]['name'],-1);dst=index.get(e['pre'+other]['name'],-1)
                    if src not in [6,7,8,9] or dst not in [10,11,12,13,14]:continue
                    loss=.5*mass*(sum(x*x for x in e['pre'+side]['v'])-sum(x*x for x in e['post'+side]['v']))
                    if loss>1e-5:first.setdefault(src,dict(target=dst,us=(e['t']-r['t0'])*1e6,lossJ=loss))
            rows[q['rackID'],q['policy']]=dict(id=q['rackID'],policy=q['policy'],speeds=v,energy=[.5*mass*x*x for x in v],firstRearLoss=first,sequence=sequence)
    summary={}
    for p in ['C',winner]:
        a=[r for (rid,pol),r in rows.items() if pol==p];assert len(a)==200
        summary[p]=dict(slotMeanSpeeds=[st.mean(r['speeds'][i] for r in a) for i in range(15)],slotMeanEnergy=[st.mean(r['energy'][i] for r in a) for i in range(15)],
            firstLossRoutes={str(i):dict(Counter(str(r['firstRearLoss'].get(i,{}).get('target','none')) for r in a)) for i in [6,7,8,9]},
            bothFirstTo12=sum(all(r['firstRearLoss'].get(i,{}).get('target')==12 for i in [7,8]) for r in a))
    examples=[]
    ids=sorted({rid for rid,p in rows});rank=sorted(ids,key=lambda rid:st.pvariance(rows[rid,winner]['speeds'])-st.pvariance(rows[rid,'C']['speeds']))
    for rid in [rank[0],rank[len(rank)//2],rank[-1]]:
        a,b=rows[rid,'C'],rows[rid,winner];seq1,seq2=a['sequence'],b['sequence']
        n=next((i for i,(x,y) in enumerate(zip(seq1,seq2)) if x['pair']!=y['pair']),min(len(seq1),len(seq2)))
        examples.append(dict(id=rid,delta=st.pvariance(b['speeds'])-st.pvariance(a['speeds']),firstDivergence=n,C=a,new=b))
    for name,obj in [('rear-mechanism-summary.json',summary),('rear-mechanism-examples.json',examples)]:
        (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
