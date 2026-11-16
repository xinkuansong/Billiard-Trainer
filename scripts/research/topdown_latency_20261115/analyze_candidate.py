"""Summarize actual candidate metrics exported as XCTest JSON attachments."""
import argparse, json, math, statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('attachments',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
results=[]; sessions={}
for f in a.attachments.rglob('*'):
    if not f.is_file() or f.stat().st_size > 2_000_000: continue
    try: data=json.loads(f.read_text())
    except (UnicodeError,ValueError):continue
    if not isinstance(data,dict) or 'mode' not in data or 'rows' not in data:continue
    key=(data['mode'], data['rows'][0]['t'])
    if key not in sessions or len(data['rows'])>len(sessions[key][1]['rows']):sessions[key]=(f,data)
for f,data in sessions.values():
    rows=data['rows']; activations=[r for r in rows if r['event']=='activation']; samples=[r for r in rows if r['event']=='sample']
    if not activations or not samples: continue
    values=[r['firstDidMs'] for r in activations if 'firstDidMs' in r]
    hidden=[r for r in samples if r['phase']=='hidden']
    end=hidden[-1]['t'] if hidden else 0; idle=[r for r in hidden if r['t'] >= end-9]
    exited=[r for r in samples if r['phase']=='exited']
    entry=[r for r in samples if r['phase']=='entry']
    tail=idle or samples[-1:]
    stat={'file':str(f),'mode':data['mode'],'activations':len(activations),'firstDidCount':len(values),
          'firstMs':values[0] if values else None,'medianMs':statistics.median(values) if values else None,
          'p95Ms':sorted(values)[math.ceil(len(values)*.95)-1] if values else None,'maxMs':max(values) if values else None,
          'over100ms':sum(v>100 for v in values),'buildsDuringOpen':sum(r['builds'] for r in activations),
          'footprintPeakMiB':max(r['footprint'] for r in samples)/2**20,
          'footprintEntryMiB':statistics.median(r['footprint'] for r in entry[-3:])/2**20 if entry else None,
          'footprintEndMiB':statistics.median(r['footprint'] for r in tail)/2**20,
          'residentEndMiB':statistics.median(r['resident'] for r in tail)/2**20,
          'measurementErrors':sum(r['rusageStatus']!=0 or r['vmStatus']!=0 for r in samples),
          'events':[r for r in rows if r['event'] in ['hostCreated','firstMainFrame','prepareStart','prepareComplete','hostDismantled']]}
    if len(idle)>1:
        first,last=idle[0],idle[-1];duration=last['t']-first['t']
        stat.update(idleDuration=duration,idleCPUPercent=100*(last['cpu']-first['cpu'])/duration,
                    idleOverlayFrames=last['overlayFrames']-first['overlayFrames'],
                    idleMainFrames=last['mainFrames']-first['mainFrames'],
                    idleFootprintDeltaMiB=(last['footprint']-first['footprint'])/2**20)
    if exited:
        stat.update(overlayAliveAfterExit=exited[-1].get('overlayAlive'),
                    footprintAfterExitMiB=statistics.median(r['footprint'] for r in exited[-3:])/2**20)
    results.append(stat)
a.out.write_text(json.dumps(results,indent=2,ensure_ascii=False))
print(json.dumps(results,indent=2,ensure_ascii=False))
