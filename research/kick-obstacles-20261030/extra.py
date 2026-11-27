"""Supplement two-cushion candidates with the same frozen native executable."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/kick-obstacles-20261030'
PYTHON='/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3'
worker=ROOT/'output/local-test-runs/a4e8d8366a2945deaa3e0b325f4ceb9e/work/KBallWorker.app/Worker'
if len(sys.argv)==1:
    assert hashlib.sha256(worker.read_bytes()).hexdigest()==json.loads((OUT/'build.json').read_text())['executableSHA256']
    rows=json.loads((ROOT/'output/kick-grid-filtered-20261030/selected.json').read_text())
    requests=[{'id':'O07','row':next(r for r in rows if r['displayID']=='F11')},{'id':'O08','row':next(r for r in rows if r['displayID']=='F15')}]
    (OUT/'requests-extra.json').write_text(json.dumps(requests))
    subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','compact-pad','--task','kick-obstacles-extra-20261030','--',PYTHON,__file__,'worker','{udid}'],check=True)
else:
    from place import place
    uid=sys.argv[2]
    def run(*args):subprocess.run(['xcrun','simctl','spawn',uid,str(worker),*map(str,args)],check=True)
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        run('scan',OUT/'requests-extra.json',OUT)
        requests=json.loads((OUT/'requests-extra.json').read_text());placed=[];fail=[]
        for r in requests:
            p,f=place(r,json.loads((OUT/(r['id']+'-scan.json')).read_text()))
            if p:placed.append(p);print('EXTRA PLACED',r['id'],len(p['obstacles']),flush=True)
            else:fail.append(dict(id=r['id'],**f));print('EXTRA REJECT',r['id'],f,flush=True)
        (OUT/'placed-extra.json').write_text(json.dumps(placed));(OUT/'placement-failures-extra.json').write_text(json.dumps(fail,indent=2))
        run('check',OUT/'placed-extra.json',OUT)
    finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
