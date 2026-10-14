#!/usr/bin/env python3
"""Expand explicit UI flow files into isolated device/theme jobs."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--flows',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--mode',choices=['preview','all','remaining'],default='all');a=p.parse_args()
if a.output.exists():raise SystemExit('Refusing to overwrite configuration')
base=json.loads(Path('scripts/native-atlas/roots.json').read_text());result={'batch':a.output.stem,'workers':[]}
for worker in base['workers']:
    if a.mode=='preview' and worker['id']!='standard':continue
    jobs=[]
    for env in worker['jobs']:
        standard_light=worker['id']=='standard' and env['id']=='portrait-light'
        if a.mode=='preview' and not standard_light:continue
        if a.mode=='remaining' and standard_light:continue
        for filename in a.flows:
            path=Path(filename);flow=json.loads(path.read_text())
            job={**env,'id':env['id']+'-'+path.stem,'flow':str(path),'selectors':['ScreenshotTourUITests/testNativeAtlasConfiguredFlow'],
                 'expected':[s['name'] for s in flow['steps'] if s['action']=='snapshot'],
                 'expectedCovers':[s['name'] for s in flow['steps'] if s['action']=='cover'],
                 'timeout':flow.get('timeout',420)}
            jobs.append(job)
    result['workers'].append({**worker,'jobs':jobs})
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'config':str(a.output),'jobs':sum(len(w['jobs']) for w in result['workers'])}))
