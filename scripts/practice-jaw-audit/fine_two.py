"""Recheck all first-pass positive-window misses at smaller input increments in the App solver."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,time

device=sys.argv[1]
work=Path(sys.argv[2]).resolve()
output=work/'refined'
scripts=Path(__file__).resolve().parent

def run(*cmd):
    subprocess.run(list(map(str,cmd)),check=True)

def sim(*cmd):
    run('xcrun','simctl',*cmd)

def ready(lo,hi):
    return all((output/'rows'/f'two-{i}.json').exists() for i in range(lo,hi))

def chunk(lo):
    hi=min(13358,lo+96)
    if ready(lo,hi):return
    for attempt in range(3):
        while shutil.disk_usage(work).free<3*1024**3:time.sleep(30)
        with (output/'two-fine-logs'/f'{lo}.log').open('a') as f:
            result=subprocess.run(['xcrun','simctl','spawn',device,work/'Runner.app/FineTwo','two',str(lo),'1',output/'rows',
                                   str(hi),work/'rows'],stdout=f,stderr=subprocess.STDOUT)
        if result.returncode==0 and ready(lo,hi):return
        if 'First-pass replay diverged' in (output/'two-fine-logs'/f'{lo}.log').read_text():
            raise RuntimeError(f'Divergence in layouts {lo}..{hi}')
        time.sleep(30)
    raise RuntimeError(f'Incomplete range {lo}..{hi}')

index=json.loads((work/'Runner.app/TwoBallBank/index.json').read_bytes())
assert len(index['layouts'])==13358
(output/'two-fine-logs').mkdir(exist_ok=True)
trace=dict(binary=hashlib.sha256((work/'Runner.app/FineTwo').read_bytes()).hexdigest(),
           source=json.loads((work/'rows/snapshot').read_bytes()),deltas=[0.0025,0.005,0.015,0.03])
(output/'two-fine-snapshot.json').write_text(json.dumps(trace,indent=2))
sim('boot',device)
try:
    sim('bootstatus',device,'-b')
    with ThreadPoolExecutor(max_workers=4) as pool:
        for _ in pool.map(chunk,range(0,13358,96)):pass
    assert ready(0,13358)
    sim('spawn',device,work/'Runner.app/Efforts',output)
finally:
    sim('shutdown',device)
run(sys.executable,scripts/'pack.py',output,'two')
shutil.copy2(work/'two-stage.json',output/'two-previous-stage.json')
run(sys.executable,scripts/'promote.py',output,'two')
# All three fixed banks are now final in the workspace. Use the maintained App host build.
link=output/'host-build'
if link.is_symlink():link.unlink()
link.symlink_to(work/'host-build')
run(sys.executable,scripts/'check_app.py',device,output,'two')
