#!/usr/bin/env python3
"""Publish exactly the verified subset, retaining original admission and all exclusions."""
import argparse, gzip, hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser(); p.add_argument('audit_directory',type=Path); p.add_argument('--apply',action='store_true');args=p.parse_args()
def sha(data): return hashlib.sha256(data).hexdigest()
audit = {}
for path in args.audit_directory.glob('*.json'):
    value = json.loads(path.read_text())
    if isinstance(value,dict) and value.get('rule') == 'spatial-quiz-v3' and 'rows' in value:
        assert value['mode'] not in audit
        audit[value['mode']] = (path,value)
assert set(audit) == {'masse','jump'}
outputs = {}; summary = {}; excluded = []
for mode,(path,report) in audit.items():
    baseline = HERE/'before-b2'
    original_data = (baseline/(mode+'.json.gz')).read_bytes()
    original_manifest = json.loads((baseline/(mode+'-manifest.json')).read_text())
    original = json.loads(gzip.decompress(original_data)); rows = report['rows']
    assert report['fingerprint'] == sha(original_data) == original_manifest['sha256']
    assert report['planned'] == report['completed'] == len(rows) == len(original)
    assert len({r['id'] for r in rows}) == len(rows)
    assert {r['id'] for r in rows} == {q['id'] for q in original}
    accepted = {r['id'] for r in rows if r['accepted']}
    rejected = {r['id']:r for r in rows if not r['accepted']}
    assert report['passed'] == len(accepted) and report['failed'] == len(rejected) and report['unconfirmed'] == 0
    # Current review authorizes only confirmed pre-target-cushion exclusions.
    assert all(r['complete'] and r['accessible'] and not r['issues'] and 'Failure.cushionBeforeTarget)' in r['outcome'] for r in rejected.values())
    retained = [q for q in original if q['id'] in accepted]
    assert len(retained) >= 15
    compressed = original_data if not rejected else gzip.compress(json.dumps(retained,separators=(',',':'),sort_keys=True).encode(),mtime=0)
    assert json.loads(gzip.decompress(compressed)) == retained
    manifest = dict(original_manifest)
    manifest['previousAdmission'] = {k:original_manifest[k] for k in ['judgement','sha256','count','verification']}
    manifest.update(count=len(retained),sha256=sha(compressed),judgement='spatial-quiz-v3',
        distanceBins=sorted({int(q['distance']*2) for q in retained}),
        sValues=sorted({q['s'] for q in retained}),qValues=sorted({q['q'] for q in retained}),
        verification=dict(candidateSHA256=sha(original_data),auditSHA256=sha(path.read_bytes()),
            planned=report['planned'],completed=report['completed'],passed=report['passed'],failed=report['failed'],unconfirmed=0))
    target = ROOT/'CuePhys/Resources/SpatialQuizBank'
    assert (target/(mode+'.json.gz')).read_bytes() == original_data, 'Source changed since audit; stop'
    outputs[target/(mode+'.json.gz')] = compressed
    outputs[target/(mode+'-manifest.json')] = (json.dumps(manifest,separators=(',',':'),sort_keys=True)+'\n').encode()
    for q in original:
        if q['id'] in rejected: excluded.append(dict(question=q,audit=rejected[q['id']]))
    summary[mode] = dict(before=len(original),retained=len(retained),excluded=len(rejected),
        beforeSHA256=sha(original_data),afterSHA256=sha(compressed),auditSHA256=sha(path.read_bytes()))
if args.apply:
    for path,data in outputs.items(): path.write_bytes(data)
    (HERE/'published-subset.json').write_text(json.dumps(summary,indent=2)+'\n')
    (HERE/'technique-exclusions.json').write_text(json.dumps(excluded,indent=2)+'\n')
print(json.dumps(dict(applied=args.apply,summary=summary),indent=2))
