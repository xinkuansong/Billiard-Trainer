from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,subprocess,sys
dev,folder,workers=sys.argv[1:]
work=Path(folder).resolve()
count=int(workers);rows=work/'rows';rows.mkdir(exist_ok=True)
app=work/'Runner.app'
stamp={k:hashlib.sha256((app/k).read_bytes()).hexdigest() for k in ('Runner','libAuditApp.dylib','training-grid-bank.json')}
stamp['seed']='20261106+4*gridReference+spinMask'
snap=rows/'snapshot'
if snap.exists() and json.loads(snap.read_bytes())!=stamp:raise RuntimeError('coverage snapshot changed')
snap.write_text(json.dumps(stamp,indent=2))
def lane(i):
    with (work/f'sep.{i}.log').open('a') as f:
        subprocess.run(['xcrun','simctl','spawn',dev,app/'Runner',str(i),str(count),rows],check=True,stdout=f,stderr=subprocess.STDOUT)
with ThreadPoolExecutor(max_workers=count) as pool:list(pool.map(lane,range(count)))
