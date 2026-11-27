"""Read-only census of the shipped defense banks; no shot re-simulation."""
from pathlib import Path
import collections, gzip, hashlib, itertools, json, math, statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/defense-region-pilot-20261105'
files = {}
for name in ['defense-practice-bank.json.gz', 'defense-free-bank.json.gz']:
    data = (ROOT / 'QiuJi/Resources' / name).read_bytes()
    raw = gzip.decompress(data)
    files[name] = {'compressedBytes': len(data), 'jsonBytes': len(raw),
                   'sha256': hashlib.sha256(data).hexdigest()}
bank = json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()))
free = json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-free-bank.json.gz').read_bytes()))
qs = bank['questions']; refs = [r for q in qs for r in q['references']]
count = lambda values: dict(sorted(collections.Counter(map(str, values)).items()))
def summary(values):
    a = sorted(values)
    return {'min': min(a), 'median': statistics.median(a), 'p90': a[math.floor(.9*(len(a)-1))], 'max': max(a)}
def events(r):
    return tuple((e['kind'],tuple(e['ballNumbers']),e.get('railIndex'),e.get('pocketIndex')) for e in r['expected']['events'])
def finals(r):
    potted=set(r['expected']['pocketedBallNumbers'])
    return {b['number']: b['position'] for b in r['expected']['finalBalls'] if b['number'] not in potted}
distances=[]; nearby=0; nearby_questions=0; same_pairs=0
for q in qs:
    near_here=False
    for r in q['references']:
        f=finals(r); n=q['opponentBallNumber']
        if n not in f: n=8
        distances.append(math.dist(f[0],f[n]))
    for a,b in itertools.combinations(q['references'],2):
        if events(a)!=events(b):continue
        same_pairs+=1
        fa,fb=finals(a),finals(b)
        if fa.keys()==fb.keys() and max(math.dist(fa[n],fb[n]) for n in fa)<=.05:
            nearby+=1;near_here=True
    nearby_questions+=near_here
result={'files':files,'sourceFingerprint':bank['sourceFingerprint'],'questions':len(qs),'references':len(refs),
        'questionsByKind':count(q['kind'] for q in qs),'freeQuestions':len(free),'freeByKind':count(q['kind'] for q in free),
        'referencesPerQuestion':count(len(q['references']) for q in qs),
        'spinX':count(r['parameters']['spinX'] for r in refs),'spinY':count(r['parameters']['spinY'] for r in refs),
        'speed':summary([r['parameters']['velocity'] for r in refs]),
        'totalRails':count(r['execution']['mainCushionCount'] for r in refs),
        'cueRails':count(r['execution']['mainCushionsByBall'].get('0',0) for r in refs),
        'totalTravelMeters':summary([r['execution']['totalTravelMeters'] for r in refs]),
        'finalCueOpponentDistanceMeters':summary(distances),
        'distanceAtLeast127cm':sum(d>=1.27 for d in distances),'distanceAtLeast180cm':sum(d>=1.8 for d in distances),
        'distanceAtLeast200cm':sum(d>=2 for d in distances),
        'legacyFullBlock':sum(r['effect']['fullDirectBlock'] for r in refs),
        'legacyNullScores':sum(r['effect']['score'] is None for r in refs),
        'legacyProbePassCounts':count(sum(p['qualifies'] for p in r['selectionProbes']) for r in refs),
        'sameOrderedEventsPairs':same_pairs,'sameEventsFinalsWithin5cmPairs':nearby,
        'questionsContainingSuchPairs':nearby_questions,
        'scope':'Stored metadata census only; 5 cm similarity is a diagnostic, not exact route identity or a rejection criterion.'}
(OUT/'bank-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps(result,ensure_ascii=False,indent=2))
