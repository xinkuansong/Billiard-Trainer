"""Sweep extra spin axes in layouts that have already established a positive clean window."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json,shutil,subprocess,sys,time,hashlib

device,folder=sys.argv[1:]
work=Path(folder).resolve()
out=work/'refined/settings'
binary=work/'Runner.app/SettingsTwo'
out.mkdir(exist_ok=True)
(out/'plan.json').write_text(json.dumps(dict(layouts=13358,driver=hashlib.sha256(binary.read_bytes()).hexdigest())))
def chunk(start):
    end=min(13358,start+64)
    def ready():
        return all((out/f'settings-{i}.json').exists() for i in range(start,end))
    if ready():return
    for attempt in range(3):
        while shutil.disk_usage(work).free<3*1024**3:time.sleep(30)
        with (out/f'chunk-{start}.log').open('a') as f:
            code=subprocess.run(['xcrun','simctl','spawn',device,binary,'two-settings',str(start),'1',out,str(end),work/'rows'],stdout=f,stderr=subprocess.STDOUT).returncode
        if code==0 and ready():return
        time.sleep(30)
    raise RuntimeError(f'Settings range failed: {start}..{end}')
with ThreadPoolExecutor(max_workers=3) as pool:
    for _ in pool.map(chunk,range(0,13358,64)):pass
tried=matched=0
for i in range(13358):
    row=json.loads((out/f'settings-{i}.json').read_bytes());tried+=row['tried'];matched+=len(row['choices'])
(out/'complete.json').write_text(json.dumps(dict(tried=tried,matched=matched)))
