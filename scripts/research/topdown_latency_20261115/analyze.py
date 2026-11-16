"""Summarize raw callback timings without treating them as display presentation."""
import csv
import json
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])
rows = []
def percentile(values, fraction):
    if not values:
        return None
    values = sorted(values)
    return values[min(len(values)-1, int((len(values)-1)*fraction))]

for sample in sorted(root.glob('arm*/samples/activation-*.json')):
    events = json.loads(sample.read_text())
    def first(kind):
        return next((e['ms'] for e in events if e['event'] == kind), None)
    sync = [e for e in events if e['event'] == 'sync']
    steady = [e for e in sync if e['created'] == 0 and e['geometryCopies'] == 0]
    updates = [e for e in events if e['event'] == 'overlayUpdate']
    frames = [e['ms'] for e in events if e['event'] == 'overlayDidRender']
    gaps = [b-a for a,b in zip(frames, frames[1:])]
    build_start, build_end = first('buildStart'), first('buildTreeComplete')
    row = dict(arm=sample.parents[1].name, activation=events[0]['activation'],
        buildStartMs=build_start, buildMs=build_end-build_start if build_end is not None else None,
        attachedMs=first('overlayAttached'), firstWillMs=first('overlayWillRender'), firstDidMs=first('overlayDidRender'),
        builds=sum(e['event']=='buildStart' for e in events), syncs=len(sync),
        nodes=max((e['visited'] for e in sync),default=0), created=sum(e['created'] for e in sync),
        geometryCopies=sum(e['geometryCopies'] for e in sync),
        syncTotalMs=sum(e['waitMs']+e['lockedMs'] for e in sync),
        waitTotalMs=sum(e['waitMs'] for e in sync), waitMaxMs=max((e['waitMs'] for e in sync),default=0),
        steadyMedianMs=statistics.median([e['waitMs']+e['lockedMs'] for e in steady]) if steady else None,
        steadyP95Ms=percentile([e['waitMs']+e['lockedMs'] for e in steady], .95),
        steadyMaxMs=max((e['waitMs']+e['lockedMs'] for e in steady), default=0),
        renderFrames=len(frames), frameGapMedianMs=statistics.median(gaps) if gaps else None,
        frameGapP95Ms=percentile(gaps,.95), frameGapMaxMs=max(gaps,default=0),
        panUpdates=sum(e['source']=='pan' for e in updates),
        displayLinkUpdates=sum(e['source']=='displayLink' for e in updates),
        swiftUIUpdates=sum(e['source']=='swiftUI' for e in updates),
        idleUpdates=sum(e['source']=='idleInvalidation' for e in updates))
    rows.append(row)
if rows:
    with (root/'summary.csv').open('w') as out:
        writer=csv.DictWriter(out, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
print(json.dumps(rows,indent=2))
