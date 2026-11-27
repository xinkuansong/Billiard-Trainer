"""Offline fixed reflections, followed by role-aware 20x20 occupied-cell dedup."""
from pathlib import Path
import collections,copy,gzip,hashlib,json,math
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-grid-mirror-20261105'
SEED='defense-fixed-mirror-20261105-v1'
KINDS=('one','two_black','two_own','three')
def enc(x):return json.dumps(x,ensure_ascii=False,separators=(',',':'),sort_keys=True,allow_nan=False).encode()
def digest(x):return hashlib.sha256(enc(x)).hexdigest()
def write(name,x): (OUT/name).write_bytes(enc(x)+b'\n')
def mirror_for(q):return [(1,1),(-1,1),(1,-1),(-1,-1)][int(digest([SEED,q['kind'],q['sourceFormationID']])[:16],16)%4]
def cell(p):
 assert len(p)==2 and all(math.isfinite(v) for v in p)
 assert -1.27<=p[0]<=1.27 and -.635<=p[1]<=.635,p
 return (min(19,math.floor((p[0]+1.27)/2.54*20)),min(19,math.floor((p[1]+.635)/1.27*20)))
def key(q):return (q['kind'],cell(q['cue']),tuple((b['number'],cell(b['position'])) for b in sorted(q['balls'],key=lambda b:b['number'])))
def quality(q):
 if not q['references']:return (1,0,0,0,q['id'])
 choices=[(-sum(p.get('qualifies',False) for p in r['selectionProbes']),r['execution']['mainCushionCount'],r['execution']['totalTravelMeters']) for r in q['references']]
 return (0,*min(choices),q['id'])
def transform(q):
 q=copy.deepcopy(q);sx,sz=mirror_for(q)
 def pt(p):return [0.0 if p[0]==0 else sx*p[0],0.0 if p[1]==0 else sz*p[1]]
 old=q['id'];q['cue']=pt(q['cue'])
 for b in q['balls']:b['position']=pt(b['position'])
 q['id']=q['kind']+':'+digest([q['kind'],q['cue'],sorted(q['balls'],key=lambda b:b['number']),q['ownBallNumber'],q['opponentBallNumber']])
 for r in q['references']:
  r['id']=digest([r['id'],sx,sz,SEED]);r['parameters']['direction']=pt(r['parameters']['direction']);r['parameters']['spinX']*=sx*sz
  for b in r['expected']['finalBalls']:b['position']=pt(b['position'])
  for probe in r['selectionProbes']:probe['angleDeltaDegrees']*=sx*sz
 return q,dict(oldID=old,newID=q['id'],kind=q['kind'],sourceFormationID=q['sourceFormationID'],sx=sx,sz=sz)
def main():
 OUT.mkdir(parents=True,exist_ok=True);before=OUT/'before';before.mkdir(exist_ok=True)
 for name in ['defense-practice-bank.json.gz','defense-free-bank.json.gz']:
  dst=before/name;src=ROOT/'QiuJi/Resources'/name
  if not dst.exists():dst.write_bytes(src.read_bytes())
 oldbank=json.loads(gzip.decompress((before/'defense-practice-bank.json.gz').read_bytes()));oldfree=json.loads(gzip.decompress((before/'defense-free-bank.json.gz').read_bytes()))
 refs={q['id']:q for q in oldbank['questions']};assert len(refs)==4234 and len(oldfree)==59000
 assert set(refs)<=set(q['id'] for q in oldfree)
 groups=collections.defaultdict(list);ledger=[];transformed={}
 for free in oldfree:
  q=refs.get(free['id'],free)
  if q['references']:assert all(q[f]==free[f] for f in ['cue','balls','ownBallNumber','opponentBallNumber','sourceFormationID'])
  q,meta=transform(q);ledger.append(meta);transformed[q['id']]=q;groups[key(q)].append(q)
 chosen=sorted((min(g,key=quality) for g in groups.values()),key=lambda q:(KINDS.index(q['kind']),q['id']))
 keep={q['id'] for q in chosen}
 mapping={q['id']:min(g,key=quality)['id'] for g in groups.values() for q in g}
 for meta in ledger:meta.update(kept=meta['newID'] in keep,representativeID=mapping[meta['newID']])
 trajectory=[q for q in chosen if q['references']]
 free=[dict(q,references=[]) for q in chosen]
 assert len({key(q) for q in free})==len(free)
 assert len({q['id'] for q in free})==len(free)
 assert all(q['references'] for q in trajectory)
 write('trajectory-candidate.json',trajectory);write('free-candidate.json',free);write('mirror-and-dedup-ledger.json',ledger)
 def count(rows):return dict(collections.Counter(q['kind'] for q in rows))
 def regions(rows):return {k:dict(collections.Counter(('X+' if b['position'][0]>=0 else 'X-')+('Z+' if b['position'][1]>=0 else 'Z-') for q in rows if q['kind']==k for b in q['balls'] if b['number']==q['ownBallNumber'])) for k in KINDS}
 report=dict(seed=SEED,grid=[20,20],cellMetres=[.127,.0635],dedup='after fixed reflection; actual orientation, all numbered balls plus cue; per kind',freeBefore=count(oldfree),freeAfter=count(free),trajectoryBefore=count(oldbank['questions']),trajectoryAfter=count(trajectory),references=sum(len(q['references']) for q in trajectory),targetRegions=regions(free),sourceSHA256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in before.glob('*.gz')})
 write('selection.json',report);print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
