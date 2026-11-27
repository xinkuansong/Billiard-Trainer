"""Select original layouts only; no solver, coordinate edits or fresh score claims."""
from pathlib import Path
import gzip, hashlib, json, math

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-fixed-opponent-examples-20261105'
source=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz'
raw=source.read_bytes();bank=json.loads(gzip.decompress(raw));all_q=[q for q in bank['questions'] if q['kind']=='two_black']
R=.028575
def positions(q):return {0:q['cue'],**{b['number']:b['position'] for b in q['balls']}}
def static_refs(q):
    p=positions(q);kept=[]
    for r in q['references']:
        e=r['expected'];f={b['number']:b['position'] for b in e['finalBalls']}
        if 9 in f and 9 not in e['pocketedBallNumbers'] and math.dist(p[9],f[9])<1e-6 and not any(9 in event['ballNumbers'] for event in e['events']):
            kept.append(r)
    return kept
eligible=[q for q in all_q if q['ownBallNumber']==8 and q['opponentBallNumber']==9 and static_refs(q)]
def long_gap(q):return .635-abs(positions(q)[9][1])-R
def short_gap(q):return 1.27-abs(positions(q)[9][0])-R
def corner_distance(q):return min(math.dist(positions(q)[9],[x,z]) for x in [-1.27,1.27] for z in [-.635,.635])
specs=[('A','对方9号在台中',[-.25,.08],lambda q:abs(positions(q)[9][0])<.45 and abs(positions(q)[9][1])<.18),
       ('B','对方9号靠长库',[.55,.58],lambda q:long_gap(q)<.05 and abs(positions(q)[9][0])<.95),
       ('C','对方9号靠短库',[-1.18,-.12],lambda q:short_gap(q)<.08 and abs(positions(q)[9][1])<.35),
       ('D','8号与9号相邻',[1.0,.1],lambda q:.16<=math.dist(positions(q)[8],positions(q)[9])<=.40)]
selected=[];used=set()
for label,title,anchor,predicate in specs:
    candidates=[]
    for q in eligible:
        p=positions(q)
        if q['id'] in used or not predicate(q):continue
        if min(math.dist(p[a],p[b]) for a,b in [(0,8),(0,9),(8,9)])<.16:continue
        if not .35<=math.dist(p[0],p[8])<=1.8:continue
        candidates.append(q)
    assert candidates,(label,title)
    q=min(candidates,key=lambda q:(math.dist(positions(q)[9],anchor)+.12*abs(math.dist(positions(q)[0],positions(q)[8])-.85),q['id']))
    used.add(q['id']);p=positions(q);ref=static_refs(q)[0]
    selected.append({'label':label,'title':title,'question':q,'staticOpponentReferenceID':ref['id'],
                     'measurements':{'cueTo8Meters':math.dist(p[0],p[8]),'ball8To9Meters':math.dist(p[8],p[9]),
                                     'opponentLongRailNoseGapMeters':long_gap(q),'opponentShortRailNoseGapMeters':short_gap(q),
                                     'opponentCornerIntersectionDistanceMeters':corner_distance(q)}})
    for a,b in [(0,8),(0,9),(8,9)]:assert math.dist(p[a],p[b])>=2*R
    assert all(abs(x)<=1.27-R+1e-6 and abs(z)<=.635-R+1e-6 for x,z in p.values())
result={'source':str(source.relative_to(ROOT)),'sourceSHA256':hashlib.sha256(raw).hexdigest(),
        'twoBlackQuestionCount':len(all_q),'withRecordedStaticOpponentReferenceCount':len(eligible),
        'selection':'Four distinct opponent-position cases selected deliberately for discussion; not random sampling or a bank policy change.',
        'coordinates':'Original world XZ metres; landscape +X right, +Z down; R=0.028575 m.',
        'scope':'Initial layouts only. Opponent immobility checked from stored reference events/finals, not newly simulated.',
        'examples':selected}
(OUT/'selected.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
for s in selected:print(s['label'],s['title'],s['question']['id'],json.dumps(positions(s['question'])),s['measurements'])
