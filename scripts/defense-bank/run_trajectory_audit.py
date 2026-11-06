"""Run the compiled iOS audit worker on an already leased simulator, never search new shots."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

uid,binary,output=sys.argv[1:4]
output=Path(output).resolve()
# Caller owns the lease; boot it if the shared fleet supplied a shutdown device.
subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
lanes=6
def lane(i):
    path=output/f'lane-{i}.json'
    with (output/f'lane-{i}.log').open('w') as log:
        subprocess.run(['xcrun','simctl','spawn',uid,str(Path(binary).resolve()),str(i),str(lanes),str(path)],stdout=log,stderr=subprocess.STDOUT,check=True)
    return json.loads(path.read_bytes())
with ThreadPoolExecutor(lanes) as workers:
    results=list(workers.map(lane,range(lanes)))
failed={k:v for r in results for k,v in r['rejected'].items()}
report=dict(questions=sum(r['questions'] for r in results),routes=sum(r['routes'] for r in results),failedRoutes=sum(map(len,failed.values())),seconds=max(r['seconds'] for r in results),digest=results[0]['digest'])
assert all(r['digest']==report['digest'] for r in results)
(output/'reject.json').write_text(json.dumps(failed,sort_keys=True))
(output/'audit.json').write_text(json.dumps(report,indent=2))
print(report)
