"""Use existing solution terminal records only; never re-solve or simulate shots."""
from pathlib import Path
import collections, gzip, hashlib, json, random
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/defense-expanded-regression-20261105'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(20261105)
bank = ROOT / 'QiuJi/Resources/defense-practice-bank.json.gz'
practice = json.load(gzip.open(bank))['questions']
rows = []
for kind in ['one', 'two_black', 'two_own', 'three']:
    for q in rng.sample([q for q in practice if q['kind'] == kind], 200):
        ref = rng.choice(q['references'])
        rows.append(dict(id=q['id']+':'+ref['id'],source=dict(q,references=[]),expected=ref['expected']))
assert len(rows)==800 and len({r['id'] for r in rows})==800
(OUT/'fixtures.json').write_text(json.dumps(rows,separators=(',',':')))
(OUT/'sampling.json').write_text(json.dumps(dict(seed=20261105,solutions=len(rows),
    availableSolutions=sum(len(q['references']) for q in practice),
    kinds=dict(collections.Counter(r['source']['kind'] for r in rows)),
    input='Existing solution expected finalBalls/events/pocketedBallNumbers; no shot simulation',
    bankSHA256=hashlib.sha256(bank.read_bytes()).hexdigest()),indent=2))
print((OUT/'sampling.json').read_text())
