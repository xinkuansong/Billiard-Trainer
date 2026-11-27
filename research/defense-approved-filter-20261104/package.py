from pathlib import Path
import json,hashlib,zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-approved-filter-20261104'
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=read(OUT/'catalog-summary.json');g=read(OUT/'geometry-audit.json')
assert c['passed'] and g['complete'] and c['acceptedTargets']+c['windowQuarantinedTargets']==g['passedTargets']
manifest=read(OUT/'source-manifest.json')
core={p:sha(ROOT/p)==h for p,h in manifest.items() if any(n in p for n in ['AngleSceneCalculator.swift','ShotComfortScore.swift','TableGeometry.swift','TableGeometry+QiuJi.swift','BTPhysicsConstants.swift'])}
assert len(core)==5 and all(core.values())
(OUT/'core-current-audit.json').write_text(json.dumps(core,indent=2))
files=list((OUT/'catalogs').glob('*'))+[OUT/n for n in ['README.md','protocol.json','catalog-summary.json','summary.json','geometry.json','geometry-audit.json','geometry-quarantine.json','controls-audit.json','input-manifest.json','algorithm.json','source-manifest.json','export-source-manifest.json','core-current-audit.json','window-convergence-audit.json','window-quarantine.json','initial-export-gate.json','approved-sample-dispositions.json']]
with zipfile.ZipFile(OUT/'defense-opening-catalogs.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
 for p in files:archive.write(p,p.relative_to(OUT))
with zipfile.ZipFile(OUT/'defense-opening-catalogs.zip') as archive:assert archive.testzip() is None
report=dict(files=len(files),zipSHA256=sha(OUT/'defense-opening-catalogs.zip'),bytes=(OUT/'defense-opening-catalogs.zip').stat().st_size,geometryPassed=c['acceptedTargets'],roleCounts=c['uniqueRoleCounts'])
(OUT/'package-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
