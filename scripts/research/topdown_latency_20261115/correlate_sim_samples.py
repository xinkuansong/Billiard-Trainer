"""Join activation times with bounded host sample windows; preserve overlap limits."""
import argparse,json,statistics,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('evidence',type=Path);a=p.parse_args();out={}
for arm in sorted(a.evidence.glob('arm*')):
 if not (arm/'identity.json').exists():continue
 rows=json.loads(subprocess.check_output(['python3',Path(__file__).with_name('analyze_device.py'),arm/'samples'],text=True))
 (arm/'summary.json').write_text(json.dumps(rows,indent=2))
 xs=[r['firstDidMs'] for r in rows]; windows=[json.loads(p.read_text()) for p in (arm/'host-samples').glob('window-*.json')]
 slow=[]
 for r in rows:
  if r['firstDidMs']<100:continue
  start=r['begin']['wallUnix']+(r['firstWillMs'] or 0)/1000;end=r['begin']['wallUnix']+r['firstDidMs']/1000
  matched=[w for w in windows if w['wallStart']<end and w['wallEnd']>start]
  slow.append({'activation':r['activation'],'firstDidMs':r['firstDidMs'],'firstWillMs':r['firstWillMs'],'renderIntervalSeconds':[start,end],'stages':r['stagesBeforeDidRender'],'sampleWindows':matched})
 out[arm.name]={'count':len(xs),'medianMs':statistics.median(xs),'minMs':min(xs),'maxMs':max(xs),'firstOpenMs':next(r['firstDidMs'] for r in rows if r['activation']==1),'slowOver100ms':slow,'samplerWindows':len(windows)}
(a.evidence/'correlation.json').write_text(json.dumps(out,indent=2))
for k,v in out.items():print(k, 'n',v['count'],'median',round(v['medianMs'],2),'max',round(v['maxMs'],2),'slow',[(r['activation'],round(r['firstDidMs'],1)) for r in v['slowOver100ms']])
