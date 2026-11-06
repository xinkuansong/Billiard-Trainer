"""Install the second fixed-bank pass and repeat the final-bundle App host checks."""
from pathlib import Path
import subprocess,sys,time
w=Path(sys.argv[1]).resolve()
scripts=Path(__file__).resolve().parent
out=w/'refined'
while not (w/'bank-refined.json').is_file():time.sleep(10)
def run(*args):subprocess.run([sys.executable,*map(str,args)],check=True)
run(scripts/'stage_refinement.py',w,'bank')
run(scripts/'promote.py',out,'bank')
run('scripts/import_bank_practice.py','--verify','--report',out/'bank-rebuild.json')
args=[sys.executable,'scripts/simulator_fleet.py','run','--role','compact-phone-floor','--task','jaw-fixed-refined-app',
      '--',sys.executable,str(scripts/'host_sequence.py'),'{udid}',str(out),'kball','bank']
while True:
    result=subprocess.run(args,capture_output=True,text=True)
    print(result.stdout,result.stderr,flush=True)
    if result.returncode==0:break
    message=result.stdout+result.stderr
    if 'Device is already in use' in message or 'Core device is running' in message:time.sleep(45)
    else:raise RuntimeError('Final host run needs a retry')
