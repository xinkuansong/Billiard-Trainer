"""Bind both runs into a review collection; never rewrite original results."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'output/defense-two-expand-20261103'
OUT=BASE/'review';OUT.mkdir(exist_ok=True)
assert json.loads((BASE/'geometry.json').read_text())==json.loads((BASE/'r2/geometry.json').read_text())
rows=[];mapping={}
for source in [BASE/'r2/questions.json',BASE/'questions.json']:
    for q in json.loads(source.read_text()):
        if source.parent==BASE and q['family']!='openBank':continue
        if source.parent==BASE:
            def geometry_signature(row):
                cue=next(k for k in row['positions'] if k not in [row['ownKey'],row['enemyKey']])
                return [row['positions'][k] for k in [cue,row['ownKey'],row['enemyKey']]]
            # Do not inflate the review count with the same geometric opening under new ball numbers.
            if any(geometry_signature(old)==geometry_signature(q) for old in rows):continue
        original_id=q['id']
        if source.parent==BASE:q['id']=q['id'].replace('D2O-','D2R-')
        assert q['id'] not in mapping
        rows.append(q)
        mapping[q['id']]=dict(file=str(source.relative_to(ROOT)),originalID=original_id,
            sha256=hashlib.sha256(source.read_bytes()).hexdigest())
assert any(q['family']=='openTable' and q['branch']=='A' for q in rows)
assert any(q['family']=='openTable' and q['branch']=='B' for q in rows)
(OUT/'questions.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
(OUT/'source-map.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2))
(OUT/'geometry.json').write_bytes((BASE/'r2/geometry.json').read_bytes())
print(json.dumps(dict(questions=len(rows),out=str(OUT)),ensure_ascii=False))
