"""Reconcile all exported-target windows with the unchanged convergence limit."""
from pathlib import Path
import hashlib,json,struct

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-approved-filter-20261104'
AUDIT=ROOT/'output/defense-window-audit-20261104'
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert read(AUDIT/'execution.json')['exitCode']==0
assert read(AUDIT/'summary.json')['complete']
assert read(AUDIT/'source-manifest.json')==read(OUT/'source-manifest.json')
assert read(AUDIT/'research-patch.json')==read(OUT/'research-patch.json')
for name,h in read(AUDIT/'audit-source-manifest.json').items():assert sha(ROOT/name)==h
checks=read(AUDIT/'checks.json')
positions=read(AUDIT/'positions.json')
assert len(checks)==6*len(positions)
windows={}
for index,w in enumerate(checks):
    position=positions[index//6]
    assert w['pocket']==index%6
    # Foundation JSON decimal serialization can change Double low bits. The
    # real calculator input is SCNVector3(Float,0,Float); require those exact
    # input bits plus the ordered row identity, never approximate deduplication.
    assert [struct.pack('f',v) for v in position]==[struct.pack('f',v) for v in w['target']]
    windows[(tuple(position),w['pocket'])]=w
assert len(windows)==len(checks)
records=[q for f in sorted((OUT/'results').glob('*-accepted.json')) for q in read(f)]
expected={(tuple(q['positions'][q['own']]),p) for q in records for p in range(6)}
assert set(windows)==expected
assert read(AUDIT/'summary.json')['searchEdgeHits']==0
passing=[];quarantine=[];maximum=0.0
for q in records:
    position=tuple(q['positions'][q['own']])
    bad=[]
    for o in q['ownAttack']['options']:
        w=windows[(position,o['pocket'])]
        assert abs(w['fineWidth']-o['objectWidth'])<1e-10,('Replay changed',q['sourceID'],o['pocket'])
        maximum=max(maximum,w['difference'])
        if w['difference']>=.001:bad.append(w)
    if bad:
        quarantine.append(dict(ordinal=q['ordinal'],own=q['own'],sourceID=q['sourceID'],windows=bad))
    else:passing.append([q['ordinal'],q['own']])
report=dict(complete=True,limitDegrees=.001,originalGlobalGatePassed=read(OUT/'summary.json')['windowCoarseFineMax']<.001,
            acceptedTargetMaximumDifference=maximum,uniqueTargetPositions=len(expected)//6,windowsChecked=len(checks),
            replayMetricsMatched=True,passing=passing,quarantine=quarantine,
            evidence={str(p.relative_to(ROOT)):sha(p) for p in [AUDIT/'checks.json',AUDIT/'summary.json',AUDIT/'audit-source-manifest.json']})
(OUT/'window-convergence-audit.json').write_text(json.dumps(report,separators=(',',':')))
print(json.dumps({k:v for k,v in report.items() if k not in ['passing','quarantine','evidence']},indent=2))
print('Passing targets:',len(passing),'Quarantined targets:',len(quarantine))
