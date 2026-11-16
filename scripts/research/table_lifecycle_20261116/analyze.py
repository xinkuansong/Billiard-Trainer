"""Analyze exported XCTest JSON attachments without opening the original xcresult."""
import argparse, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('attachments',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
samples=[]
for path in a.attachments.rglob('*'):
    if not path.is_file() or path.stat().st_size>5_000_000: continue
    try: value=json.loads(path.read_bytes())
    except (ValueError,UnicodeError): continue
    if isinstance(value,dict) and 'checkpoint' in value and 'objects' in value:
        value['attachment']=str(path);samples.append(value)
samples.sort(key=lambda x:x['time'])
rows=[];late=[];retired={}
for s in samples:
    alive=[x for x in s['objects'] if x['alive']]
    counts={kind:sum(x['kind']==kind for x in alive) for kind in ['vm','scene','renderer','coordinator']}
    row={'checkpoint':s['checkpoint'],'time':s['time'],'alive':counts,
         'owners':[x['owner'] for x in alive if x['kind']=='vm'],'jobs':s['jobs'],
         'completedJobs':s['completedJobs'],'attachment':s['attachment']}
    rows.append(row)
    for o in s['objects']:
        if o['id'] in retired and (o['frames'],o['ticks'])!=retired[o['id']]:
            late.append({'checkpoint':s['checkpoint'],'object':o})
        if not o['alive']:retired[o['id']]=(o['frames'],o['ticks'])
returns=[r for r in rows if r['checkpoint'].endswith('-returned')]
summary={'checkpoints':len(rows),'entered':sum(r['checkpoint'].endswith('-entered') for r in rows),
         'returned':len(returns),'returnAnomalies':[r for r in returns if any(r['alive'].values()) or r['jobs']],
         'lateActivityAfterRelease':late,'rows':rows,
         'scope':'Instrumented simulator full navigation; weak object observations and callback counts, not device energy or leak-proof full regression.'}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k!='rows'},ensure_ascii=False,indent=2))
