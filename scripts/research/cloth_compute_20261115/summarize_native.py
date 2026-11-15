"""Summarize H17 native full-scene results without trimming timing samples."""
from pathlib import Path
import argparse, hashlib, json, statistics
p=argparse.ArgumentParser();p.add_argument('evidence',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
found=[]
for f in (a.evidence/'attachments').glob('*.json'):
    try:d=json.loads(f.read_text())
    except (UnicodeError,json.JSONDecodeError):continue
    if isinstance(d,dict) and d.get('study')=='H17-current-production-compute':found.append((f,d))
if len(found)!=1:raise ValueError(f'Expected one native report, got {len(found)}')
f,d=found[0];rows=[]
for r in d['rows']:
    out={k:v for k,v in r.items() if k not in ['times','quality']}
    out['qualityFrames']=len(r['quality'])
    out['quality']=r['quality']
    for kind in sorted({t['kind'] for t in r['times']}):
        out[kind]={}
        for metric in ['gpuSpanMS','cpuEncodeMS','cpuWallMS','cpuFullSyncWallMS']:
            changes=[];all_values={k:[] for k in ['A','B']}
            for cycle in range(6):
                values={arm:[f[metric] for t in r['times'] if t['kind']==kind and t['cycle']==cycle and t['arm']==arm for f in t['frames']] for arm in ['A','B']}
                if not all(values.values()):raise ValueError('Incomplete balanced cycle')
                changes.append((1-statistics.median(values['B'])/statistics.median(values['A']))*100)
                for arm in values:all_values[arm]+=values[arm]
            out[kind][metric]={'savingPercent':statistics.median(changes),'cycles':changes,
                'aMS':statistics.median(all_values['A']),'bMS':statistics.median(all_values['B']),
                'fasterCycles':sum(v>0 for v in changes),'frameCount':sum(map(len,all_values.values()))}
    if 'AB' in out:
        g=out['AB']['gpuSpanMS'];save=g['aMS']-g['bMS']
        costs={v['epoch']:sum(x['gpuSpanMS'] for x in v['captureFrames'])+v['prepare']['gpuMS'] for v in r['preparations']}
        out['epochPreparationGPU_MS']=costs
        out['initialBreakEvenFrames']=None if save<=0 else costs['initial']/save
        out['initialAmortizedSavings']={str(n):(1-(g['bMS']+costs['initial']/n)/g['aMS'])*100 for n in [1,2,8,60]}
    rows.append(out)
report={'source':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'completed':d['completed'],
    'device':d['device'],'animated':d.get('animated',False),'rows':rows,'scope':d['scope'],'timing':d['timing']}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
for r in rows:
    print(r['pose'],'quality',r['maximumChannelDifference'],'AA',r['aaMaximum'],'restore',r['restoreMaximum'],
        {k:round(r[k]['gpuSpanMS']['savingPercent'],3) for k in ['AA','AB','DI'] if k in r})
