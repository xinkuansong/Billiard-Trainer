"""Resume on a leased simulator, check every grid key, then replay every changed seed in the installed App."""
import json,subprocess,sys,time
from pathlib import Path
work=Path(sys.argv[1]).resolve()
repo=Path(__file__).resolve().parents[2]
scripts=Path(__file__).resolve().parent

def lease(task,role,action,worker):
    while True:
        cmd=[sys.executable,'scripts/simulator_fleet.py','run','--role',role,'--task',task,'--',
             sys.executable,worker,'{udid}',work,action]
        result=subprocess.run(list(map(str,cmd)),cwd=repo,capture_output=True,text=True)
        print(result.stdout,result.stderr,flush=True)
        if result.returncode==0:return
        message=result.stdout+result.stderr
        if 'Device is already in use' in message or 'Core device is running' in message:time.sleep(30)
        else:raise RuntimeError('Simulator step failed: '+task)

# The effort report is generated only after the initial fixed-bank sweep returned its device.
while not (work/'two-extra-efforts.json').exists():time.sleep(30)
lease('jaw-separation-all-layouts','compact-phone-floor','separation',scripts/'boot_command.py')
audited=json.loads((work/'sep/audited.json').read_bytes())
assert audited['checked']==audited['expected']==3130112
while not (work/'two-app-replay.json').exists():time.sleep(30)
lease('jaw-separation-final-replay','compact-phone-floor','sep',scripts/'check_app.py')
report=json.loads((work/'sep-app-replay.json').read_bytes())
assert not report['failed'] and report['seen']==sum(row.get('adjusted',0) for row in audited['settings'])
(work/'sep/complete.json').write_text(json.dumps(dict(checked=audited['checked'],appReplayed=report['seen'])))
