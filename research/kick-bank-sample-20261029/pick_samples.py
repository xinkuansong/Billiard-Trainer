from pathlib import Path
import json,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-sample-20261029'
rows=json.loads((OUT/'accepted.json').read_text());selected=[]
for n in range(1,6):
    used=set()
    for category,quota in [('zero',3),('left',2),('right',1)]:
        options=[r for r in rows if r['n']==n and r['category']==category]
        # Favor distinct cue cells/routes; retain three longitudinal variants in the full data.
        for _ in range(quota):
            if not options:break
            options.sort(key=lambda r:(r['seed']['cell'] in used,abs(r['offsetR']),r['seed']['id']))
            row=options.pop(0);selected.append(row);used.add(row['seed']['cell'])
            options=[r for r in options if r['seed']['id']!=row['seed']['id']]
for i,row in enumerate(selected):row['displayID']=f'K{i+1:02d}'
(OUT/'selected.json').write_text(json.dumps(selected))
print('SELECTED',len(selected),dict(collections.Counter(r['n'] for r in selected)),flush=True)
