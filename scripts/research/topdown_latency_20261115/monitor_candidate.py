"""Read-only process/container monitor; preserve owned research JSON before lease cleanup."""
import argparse,json,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--job',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True);seen={}
for _ in range(180):
    state=json.loads((a.job/'job.json').read_text())
    device=a.job/'evidence/device-result.json'
    if device.exists():
        uid=json.loads(device.read_text()).get('udid')
        if uid:
            c=subprocess.run(['xcrun','simctl','get_app_container',uid,'com.xinkuan.qiuji','data'],capture_output=True,text=True)
            if c.returncode==0:
                directory=Path(c.stdout.strip())/'Documents'
                for f in directory.glob('Candidate-*.json'):
                    try:raw=f.read_bytes();data=json.loads(raw)
                    except (OSError,ValueError):continue
                    (a.out/f.name).write_bytes(raw)
                    opens=[r for r in data['rows'] if r['event']=='activation']
                    values=[r['firstDidMs'] for r in opens if 'firstDidMs' in r]
                    phase=next((r['phase'] for r in reversed(data['rows']) if r['event']=='sample'),None)
                    progress=(len(opens)//5,phase=='exited')
                    if seen.get(f.name)!=progress:
                        print(json.dumps({'session':f.stem,'mode':data['mode'],'opens':len(opens),'firstMs':values[0] if values else None,'maxMs':max(values) if values else None,'phase':phase}),flush=True)
                        seen[f.name]=progress
    if state['state'] in ['succeeded','failed','cancelled','interrupted']:
        print('FINAL '+state['state'],flush=True);break
    time.sleep(10)
else: raise SystemExit('Monitor deadline reached; preserve partial data and inspect job')
