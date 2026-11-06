from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,sys,hashlib,json
device=sys.argv[1];out=Path(sys.argv[2]).resolve()
ledger=out/'rows';ledger.mkdir(exist_ok=True)
runner=out/'Runner.app/Runner'
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()
stamp={p.name:digest(p) for p in [runner,runner.with_name('libAuditApp.dylib'),runner.with_name('bank-practice-bank.json'),runner.with_name('training-grid-bank-manifest.json'),runner.with_name('TwoBallBank')/'index.json']}
stamp['KBallBank']=digest(runner.with_name('KBallBank')/'index.json')
fingerprint=ledger/'snapshot'
if fingerprint.exists() and json.loads(fingerprint.read_text())!=stamp:raise RuntimeError('snapshot changed; use a new result directory')
fingerprint.write_text(json.dumps(stamp,indent=2))
def sim(*args,**kwargs):
    return subprocess.run(['xcrun','simctl',*map(str,args)],check=True,**kwargs)
def work(task):
    family,lane,lanes=task
    with (out/f'{family}.{lane}.log').open('a') as f:
        sim('spawn',device,runner,family,lane,lanes,ledger,stdout=f,stderr=subprocess.STDOUT)
sim('boot',device)
try:
    sim('bootstatus',device,'-b')
    tasks=[('bank',i,8) for i in range(8)]+[('kball',i,4) for i in range(4)]+[('two',i,16) for i in range(16)]
    with ThreadPoolExecutor(max_workers=14) as pool:list(pool.map(work,tasks))
finally:
    sim('shutdown',device)
