"""Portable data/evidence bundle; excludes build caches and Python environment."""
from pathlib import Path
import hashlib,json,zipfile,os
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('DEFENSE_PILOT_OUTPUT',str(ROOT/'output/defense-bank-2500-20261103/review')))
audit=json.loads((OUT/'audit.json').read_text());assert audit['passed'] and audit['questions']==2500 and not audit['partial']
assert json.loads((OUT/'gallery-check.json').read_text())['passed']
assert json.loads((OUT/'visual-review.json').read_text())['passed']
files=[OUT/p for p in ['bank.json','bank-twoA.json','bank-twoB.json','bank-own.json','bank-black.json','bank-joint.json','index.json','protocol.json','geometry.json','audit.json','gallery-check.json','visual-review.json','visual-sample.json','package-manifest.json','runtime-bindings.json','refill-report.json','summary.json','review.html','README.md']]
files+=sorted(p for p in (OUT/'runtime').rglob('*') if p.is_file())
files+=sorted((OUT/'questions').rglob('*.json'))+sorted((OUT/'figures').glob('*'))
assert len(list((OUT/'questions').rglob('*.json')))==2500
archive=OUT/'defense-bank-2500.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in files:z.write(p,p.relative_to(OUT))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert len(z.namelist())==len(files)
print(json.dumps({'file':str(archive),'files':len(files),'bytes':archive.stat().st_size}))
(OUT/'delivery.json').write_text(json.dumps({'questions':2500,'classCounts':audit['counts'],'coverage':audit['coverage'],'archive':archive.name,'archiveBytes':archive.stat().st_size,'archiveSHA256':hashlib.sha256(archive.read_bytes()).hexdigest(),'crcVerified':True,'scope':'offline validated candidate data; not App integration or real-table acceptance'},ensure_ascii=False,indent=2))
