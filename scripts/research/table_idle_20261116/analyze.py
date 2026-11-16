"""Derive measured deltas from immutable exported checkpoint attachments."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('attachments',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
samples={}
for path in a.attachments.glob('*.json'):
    v=json.loads(path.read_text())
    if not isinstance(v,dict) or 'checkpoint' not in v:continue
    assert v['usageStatus']==0,(path,v['usageStatus'])
    assert v['checkpoint'] not in samples,v['checkpoint']
    v['attachment']=str(path);samples[v['checkpoint']]=v
assert samples,'No measurement checkpoints'
intervals=[]
for name,start in samples.items():
    if not name.endswith('.start'):continue
    label=name[:-6];end=samples.get(label+'.end')
    if end is None:continue
    assert start['pid']==end['pid'],'Process changed inside measurement'
    elapsed=end['time']-start['time'];assert elapsed>0
    cpu=end['processCPUSeconds']-start['processCPUSeconds'];assert cpu>=0
    def total(s,key):return sum(o[key] for o in s['objects'])
    def delta(key):
        keys=set(start[key])|set(end[key])
        return {k:end[key].get(k,0)-start[key].get(k,0) for k in sorted(keys)}
    alive={kind:sum(o['alive'] and o['kind']==kind for o in end['objects']) for kind in ['vm','scene','renderer','coordinator']}
    intervals.append({'name':label,'seconds':elapsed,'cpuSeconds':cpu,'oneCoreCPUPercent':100*cpu/elapsed,
        'frames':total(end,'frames')-total(start,'frames'),'ticks':total(end,'ticks')-total(start,'ticks'),
        'counters':delta('counters'),'durations':delta('durations'),'aliveAtEnd':alive,
        'jobsAtStart':start['jobs'],'jobsAtEnd':end['jobs'],
        'completedJobs':end['completedJobs']-start['completedJobs'],
        'start':start['attachment'],'end':end['attachment']})
intervals.sort(key=lambda x:samples[x['name']+'.start']['time'])
ordered=sorted(samples.values(),key=lambda s:s['time'])
dead={};after_release_changes=[]
for sample in ordered:
    for obj in sample['objects']:
        if obj['id'] in dead:
            previous=dead[obj['id']]
            if obj['alive'] or obj['frames']!=previous['frames'] or obj['ticks']!=previous['ticks']:
                after_release_changes.append({'checkpoint':sample['checkpoint'],'object':obj})
        if not obj['alive']:dead.setdefault(obj['id'],obj)
last=ordered[-1]
summary={'checkpoints':len(samples),'intervals':intervals,'completed': 'final' in samples,
 'shots':sum('-finished' in n for n in samples),'scope':'Simulator process CPU deltas and instrumented call counts; no iPhone energy, GPU time, or thermal equivalence.'}
summary['lifecycle']={'trackedByKind':{kind:sum(o['kind']==kind for o in last['objects']) for kind in ['vm','scene','renderer','coordinator']},
 'aliveAtLastCheckpoint':[o for o in last['objects'] if o['alive']],
 'jobsAtLastCheckpoint':last['jobs'],'changesAfterObservedRelease':after_release_changes,
 'peakLiveVMs':max(sum(o['alive'] and o['kind']=='vm' for o in s['objects']) for s in ordered)}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(summary,ensure_ascii=False,indent=2))
for r in intervals:
    print(f"{r['name']:27} {r['seconds']:6.2f}s CPU {r['oneCoreCPUPercent']:6.2f}% frames {r['frames']:5} ticks {r['ticks']:5} calls {r['counters']}")
print('complete',summary['completed'],'checkpoints',len(samples),'shots',summary['shots'])
