from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-no-pocket-20261105'
r=json.loads((OUT/'report.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
resource=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz';assert sha(resource)==r['sourceSHA256'];assert sha(ROOT/'QiuJi/Resources/defense-free-bank.json.gz')==r['freeSHA256']
source=ROOT/'QiuJi/Features/DefensePractice/DefenseQuestionPreparer.swift';s=source.read_text();(OUT/'before'/source.name).write_text(s)
oldfp='defense-grid20-fixedmirror-v3-3982-58470-399e5846-786c3a90';newfp='defense-no-pocket-v4-3777-58470-'+r['outputSHA256'][:8]+'-'+r['freeSHA256'][:8]
for old,new in {oldfp:newfp,r['sourceSHA256']:r['outputSHA256'],r['oldSourceFingerprint']:r['sourceFingerprint']}.items():assert s.count(old)==1;s=s.replace(old,new)
tests=ROOT/'QiuJiTests/DefensePracticeTests.swift';t=tests.read_text();(OUT/'before'/tests.name).write_text(t)
for old,new in {'trajectory.count,3982':'trajectory.count,3777','references).count,9836':'references).count,9119','["one":752,"three":1142,"two_black":1038,"two_own":1050]':'["one":709,"three":1102,"two_black":980,"two_own":986]'}.items():assert t.count(old)==1;t=t.replace(old,new)
source.write_text(s);tests.write_text(t)
new=(OUT/'app-package'/resource.name).read_bytes();assert hashlib.sha256(new).hexdigest()==r['outputSHA256'];tmp=resource.with_suffix('.new');tmp.write_bytes(new);tmp.replace(resource)
(OUT/'publication.json').write_text(json.dumps(dict(published=True,fingerprint=newfp,**r),ensure_ascii=False,indent=2)+'\n');print(newfp)
