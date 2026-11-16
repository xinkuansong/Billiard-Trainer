"""Report per-activation CPU stages and renderer callback boundaries."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('directory', type=Path)
a = p.parse_args()
result = []
for path in sorted(a.directory.rglob('activation-*.json')):
    events = json.loads(path.read_text())
    def first(name):
        return next((x['ms'] for x in events if x['event'] == name), None)
    did = first('overlayDidRender')
    before = [x for x in events if did is None or x['ms'] <= did]
    stages = {}
    for name in ['createSCNView', 'backgroundColor', 'isPlaying', 'rendersContinuously', 'antialiasing', 'autoLighting', 'sync', 'overlayUpdate']:
        xs = [x for x in before if x['event'] == name]
        ds = [x.get('durationMs', x.get('waitMs', 0) + x.get('lockedMs', 0)) for x in xs]
        stages[name] = {'count': len(xs), 'sumMs': sum(ds), 'maxMs': max(ds, default=0)}
    row = {'file': str(path), 'activation': events[0]['activation'], 'firstWillMs': first('overlayWillRender'),
           'firstDidMs': did, 'attachedMs': first('overlayAttached'),
           'buildStartMs': first('buildStart'), 'buildCompleteMs': first('buildTreeComplete'),
           'stagesBeforeDidRender': stages, 'begin': next(x for x in events if x['event'] == 'begin'),
           'build': next((x for x in events if x['event'] == 'buildStart'), None)}
    result.append(row)
print(json.dumps(result, ensure_ascii=False, indent=2))
