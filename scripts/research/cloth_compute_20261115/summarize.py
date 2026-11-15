"""Summarize every ordered timing arm; never trim frames or select best runs."""
from pathlib import Path
import json, statistics, argparse, hashlib

p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
d=json.loads(a.input.read_text());rows=[]
for r in d['rows']:
    result={k:v for k,v in r.items() if k not in ['times','comparisons','captureFrames','cameraTransform']}
    for kind in sorted({t['kind'] for t in r['times']}):
        out={}
        for metric in ['gpuMS','cpuEncodeMS','wallMS']:
            changes=[];values={arm:[] for arm in ['A','B']}
            for cycle in range(6):
                parts={arm:[v for t in r['times'] if t['kind']==kind and t['cycle']==cycle and t['arm']==arm for v in t[metric]] for arm in ['A','B']}
                if not all(parts.values()):continue
                changes.append((1-statistics.median(parts['B'])/statistics.median(parts['A']))*100)
                for arm in values:values[arm]+=parts[arm]
            out[metric]={'savingPercent':statistics.median(changes),'cycles':changes,
                         'aMS':statistics.median(values['A']),'bMS':statistics.median(values['B']),
                         'fasterCycles':sum(x>0 for x in changes),'frameCount':sum(map(len,values.values()))}
        result[kind]=out
    if 'AB' in result:
        cost=sum(x['gpuMS'] for x in r['captureFrames'])+(r['prepare']['gpuMS'] if r['variant']=='reuse' else 0)
        # Conservatively charge every capture used by the harness, not just the fastest.
        g=result['AB']['gpuMS'];saving=g['aMS']-g['bMS']
        result['allCapturePlusPreparationGPU_MS']=cost
        result['amortizedSavingPercent']={str(n):(1-(g['bMS']+cost/n)/g['aMS'])*100 for n in [1,2,8,60]}
        result['observedBreakEvenFrames']=None if saving<=0 else cost/saving
    rows.append(result)
report={'source':str(a.input),'sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'rows':rows,
        'scope':d['scope'],'note':'Warm same-command compute+render; capture/prepare charged separately. No FPS, phone energy or whole-page claim.'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
for r in rows:
    print(r['pose'],r['variant'],'quality',r['maximumChannelDifference'],
          'AB GPU',r.get('AB',{}).get('gpuMS',{}).get('savingPercent'),
          'breakEvenFrames',r.get('observedBreakEvenFrames'))
