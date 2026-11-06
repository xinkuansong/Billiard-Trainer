"""Run bounded same-physics simulator workers; only complete groups count."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile,time

device,folder,workers=sys.argv[1:]
work=Path(folder).resolve()
rows=work/'rows'
binary=work/'Runner.app/ChunkRunner'
count=48986  # checked against the independent decoder of all 270 grid pools
stamp=json.loads((rows/'snapshot').read_bytes())
for name in ('libAuditApp.dylib','training-grid-bank.json'):
    assert hashlib.sha256((binary.parent/name).read_bytes()).hexdigest()==stamp[name]

def run(start,end,output,log):
    args=['xcrun','simctl','spawn',device,binary,str(start),'1',output,str(end)]
    return subprocess.run(args,stdout=log,stderr=subprocess.STDOUT).returncode

with tempfile.TemporaryDirectory(dir=work) as scratch, (work/'chunk-parity.log').open('a') as log:
    for i in (0,1,8,30):
        assert run(i,i+1,scratch,log)==0
        assert json.loads((Path(scratch)/f'sep-{i}.json').read_bytes())==json.loads((rows/f'sep-{i}.json').read_bytes())
(work/'chunk-runtime.json').write_text(json.dumps(dict(driverSHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                                    original=stamp['Runner'],groupsCompared=[0,1,8,30],lanes=int(workers))))

def chunk(start):
    end=min(start+64,count)
    def pending():
        return any(not (rows/f'sep-{i}.json').exists() for i in range(start,end))
    if not pending():return
    logfile=work/'chunk-logs'/f'{start}.log'
    for attempt in range(3):
        # Let this job's previous workers release their working sets before spawning more.
        while shutil.disk_usage(work).free<3*1024**3:time.sleep(45)
        with logfile.open('a') as log:
            code=run(start,end,rows,log)
        if code==0 and not pending():return
        time.sleep(20)
    raise RuntimeError(f'Incomplete chunk {start}..{end}; inspect {logfile}')
(work/'chunk-logs').mkdir(exist_ok=True)
with ThreadPoolExecutor(max_workers=int(workers)) as pool:
    for _ in pool.map(chunk,range(0,count,64)):pass
