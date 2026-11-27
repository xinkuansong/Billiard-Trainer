"""Quarter-table / per-angle randomized kick examples, isolated from the app."""
from pathlib import Path
import importlib.util, json, os, random, math, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/kick-grid-filtered-20261030'

def prepare():
    import hashlib
    source=ROOT/'output/kick-grid-sample-20261030'
    prior=json.loads((source/'geometry.json').read_text())
    current=json.loads((OUT/'geometry.json').read_text())
    assert prior==current, 'Geometry drift: do not reuse old sampled origins.'
    (OUT/'sampling.json').write_bytes((source/'sampling.json').read_bytes())
    (OUT/'input-binding.json').write_text(json.dumps({name:{'path':str(source/name),'sha256':hashlib.sha256((source/name).read_bytes()).hexdigest()} for name in ['seeds.json','sampling.json']},indent=2))
    print('REUSED original independent per-angle random origins and 103680 proposals',flush=True)

def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('kick_build',ROOT/'research/k-ball-placement-20261029/build.py')
        mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        mod.HERE=HERE; mod.OUT=OUT
        app=mod.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone',
                        '--task','kick-grid-filtered-20261030','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)

    else:
        _,uid,worker=sys.argv[1:]
        def run(*args):
            subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            run('geometry',OUT/'geometry.json')
            prepare()
            run('selftest',OUT/'native-selftest.json')
            run('generate',ROOT/'output/kick-grid-sample-20261030/seeds.json',OUT)
            run('verify',OUT/'accepted.json',OUT/'verification.json')
        finally:
            subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

if __name__=='__main__': main()
