"""Finish the frozen two-ball audit through the App as each prerequisite completes."""
import json,subprocess,sys,time
from pathlib import Path
scripts=Path(__file__).resolve().parent
repo=scripts.parents[1]
work=Path(sys.argv[1]).resolve()
mode=sys.argv[2] if len(sys.argv)>2 else 'monitor'
def run(cmd):
    subprocess.run([str(a) for a in cmd],check=True,cwd=repo)
def lease(task,script,action):
    # A core may briefly still be booted while the owner shuts it down.
    while True:
        command=[sys.executable,repo/'scripts/simulator_fleet.py','run','--role','compact-pad','--task',task,
                 '--',sys.executable,script,'{udid}',work,action]
        result=subprocess.run(list(map(str,command)),capture_output=True,text=True,cwd=repo)
        print(result.stdout,result.stderr,flush=True)
        if result.returncode==0:return
        if 'Device is already in use' in result.stderr or 'Core device is running' in result.stderr:time.sleep(30)
        else:raise RuntimeError('simulator step failed')
if mode=='monitor':
    index=json.loads((work/'Runner.app/TwoBallBank/index.json').read_bytes())
    while len(list((work/'rows').glob('two-*.json')))<len(index['layouts']):time.sleep(30)
    lease('jaw-two-sort-inputs',scripts/'boot_command.py','effort')
    run([sys.executable,scripts/'pack.py',work,'two'])
    run([sys.executable,scripts/'promote.py',work,'two'])
    # The final test build shares the dedicated host build directory with bank/K.
    while not (work/'bank-app-replay.json').exists():time.sleep(30)
    lease('jaw-two-final-replay',scripts/'check_app.py','two')
    print('Two-ball final App report', (work/'two-app-replay.json').read_text(),flush=True)
