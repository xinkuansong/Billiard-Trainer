from pathlib import Path
import json,subprocess,sys,os,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output/kick-bank-sample-20261029'
RUN=ROOT/'output/local-test-runs/e87b59c719984dd7a6be68573a325d53'
def main():
    if len(sys.argv)==1:
        commands=json.loads((RUN/'evidence/commands.json').read_text());shutil.copy2(HERE/'main.swift',RUN/'work/source/main.swift')
        with (OUT/'resume-build.log').open('w') as log:
            for cmd in commands[-2:]:subprocess.run(cmd,check=True,stdout=log,stderr=subprocess.STDOUT)
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','kick-bank-sample-20261029-replay','--',sys.executable,__file__,'{udid}'],check=True)
    else:
        uid=sys.argv[1];worker=RUN/'work/KBallWorker.app/Worker'
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            subprocess.run(['xcrun','simctl','spawn',uid,str(worker),'verify',str(OUT/'accepted.json'),str(OUT/'verification.json')],check=True)
        finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
