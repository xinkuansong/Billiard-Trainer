from pathlib import Path
import os,sys,json,subprocess,importlib.util
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/bank-sample-20261101'
def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('bank_build',HERE/'build.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        app=mod.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','bank-sample-20261101','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
    else:
        _,uid,worker=sys.argv[1:]
        def run(*args):subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            run('geometry',OUT/'geometry.json');run('generate',OUT);run('verify',OUT)
        finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
