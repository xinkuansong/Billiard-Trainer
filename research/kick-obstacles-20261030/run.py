from pathlib import Path
import importlib.util,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/kick-obstacles-20261030'
PYTHON='/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3'
def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('kick_build',ROOT/'research/k-ball-placement-20261029/build.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        mod.HERE=HERE;mod.OUT=OUT;app=mod.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role',os.environ.get('KICK_SIM_ROLE','large-phone'),'--task','kick-obstacles-20261030','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
    else:
        _,uid,worker=sys.argv[1:]
        def run(*args):subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            requests=json.loads((OUT/'requests.json').read_text())
            extra=OUT/'requests-extra.json'
            if extra.exists():requests+=json.loads(extra.read_text())
            additional=OUT/'requests-additional.json'
            if additional.exists():requests+=json.loads(additional.read_text())
            (OUT/'requests-run.json').write_text(json.dumps(requests))
            run('scan',OUT/'requests-run.json',OUT)
            subprocess.run([PYTHON,str(HERE/'place.py'),str(OUT/'requests-run.json'),str(OUT/'placed-run.json')],check=True)
            run('check',OUT/'placed-run.json',OUT)
        finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
