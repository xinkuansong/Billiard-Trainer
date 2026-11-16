import argparse, json, statistics
from pathlib import Path

p=argparse.ArgumentParser(); p.add_argument('evidence', type=Path); a=p.parse_args()
rows=[]
for f in a.evidence.glob('round-*/samples/*/*.json'):
    d=json.loads(f.read_text()); es=d['events']; names={}
    for event in es: names.setdefault(event['event'],[]).append(event)
    identity=json.loads((f.parents[2]/'identity.json').read_text())
    if not identity['startUnix'] <= names['action'][0]['wallUnix'] <= identity['endUnix']: continue
    def first(key): return names.get(key,[{}])[0].get('ms')
    def span(begin,end):
        s,t=first(begin),first(end)
        return t-s if s is not None and t is not None else None
    did=[e for e in es if e['event']=='didRender' and e.get('contentReady')]
    row={'file':str(f), 'entry':d['entry'],'route':d['route'],'mode':identity['mode'],'arm':identity['arm'],
         'actionUnix':names['action'][0]['wallUnix'],
         'touchUpToActionMS':names['action'][0]['touchUpToActionMS'],
         'actionToAppearMS':first('onAppear.start'),
         'actionToPageSetupMS':first('pageSetupDone'),
         'actionToFirstDidMS':first('didRender'),
         'actionToContentDidMS':did[0]['ms'] if did else None,
         'actionToControlsReadyMS':first('controlsReady'),
         'vmSetupMS':span('vmSetup.start','vmSetup.end'),
         'sceneSetupMS':span('sceneSetup.start','sceneSetup.end'),
         'loadBoardMS':span('loadBoard.start','loadBoard.end'),
         'probeSyncMS':sum(e.get('durationMS',0) for e in names.get('probe.bake.sync.end',[])),
         'probeAsyncMS':sum(e.get('durationMS',0) for e in names.get('probe.bake.async.end',[])),
         'clothPrepareMS':sum(e.get('durationMS',0) for e in names.get('cloth.prepare',[])),
         'setupTableMS':sum(e.get('durationMS',0) for e in names.get('setupTable.end',[])),
         'referenceLightingMS':sum(e.get('durationMS',0) for e in names.get('referenceLighting.end',[])),
         'closeupBackdropMS':sum(e.get('durationMS',0) for e in names.get('closeupBackdrop.end',[])),
         'probeInstallTimesMS':[e['ms'] for e in names.get('probe.install',[])],
         'sceneTiming':names.get('pageSetupDone',[{}])[0].get('sceneTiming'),
         'readyDetails':names.get('controlsReady',[{}])[0]}
    rows.append(row)
rows.sort(key=lambda r:r['actionUnix'])
(a.evidence/'entry-summary.json').write_text(json.dumps(rows,indent=2))
for r in rows:
    print(json.dumps({k:(round(v,2) if isinstance(v,float) else v) for k,v in r.items()
        if k not in ['file','sceneTiming','readyDetails','entry','actionUnix']},ensure_ascii=False))
