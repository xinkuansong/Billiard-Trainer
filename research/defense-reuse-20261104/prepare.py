"""Read-only, deterministic candidate sampling from the three bundled banks."""
from pathlib import Path
import gzip, hashlib, itertools, json, random, sys
ROOT=Path(__file__).resolve().parents[2]; HERE=Path(__file__).parent
OUT=ROOT/'output/defense-reuse-20261104'; OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import layouts
rng=random.Random(20261104); hashes={}; rows=[]
def read(p,compressed=False):
 b=p.read_bytes(); hashes[str(p.relative_to(ROOT))]=hashlib.sha256(b).hexdigest()
 return json.loads(gzip.decompress(b) if compressed else b)
bank=read(ROOT/'QiuJi/Resources/training-grid-bank.json')
# Reservoir by generation-angle band, never move a source ball.
groups=[[] for _ in range(4)]; counts=[0]*4
for lid,c,o,p,a in layouts(bank):
 k=min(3,int(a)//22);counts[k]+=1
 q=dict(sourceID=lid,source='accuracy',cue=c,positions=[o],originalAngle=a)
 if len(groups[k])<60:groups[k].append(q)
 else:
  j=rng.randrange(counts[k])
  if j<60:groups[k][j]=q
for q in sum(groups,[]):rows.append(dict(q,kind='one',numbers=[8],own=0,enemy=0))
root=ROOT/'QiuJi/Resources/TwoBallBank'; idx=read(root/'index.json')
for shard in rng.sample(idx['shards'],60):
 p=root/(shard.get('file') or shard['name']+'.jsonl.gz');raw=p.read_bytes()
 assert hashlib.sha256(raw).hexdigest()==shard['sha256'];hashes[str(p.relative_to(ROOT))]=shard['sha256']
 candidates=[json.loads(x) for x in gzip.decompress(raw).splitlines()]
 for row in rng.sample(candidates,min(3,len(candidates))):
  for c in rng.sample(row['questions'],min(2,len(row['questions']))):
   base=dict(source='two',sourceID=str(row['id'])+'/'+str(c['id']),cue=row['board']['cue'],positions=[row['board']['object'],c['p']],originalAngle=row['board']['angle'])
   for own in [0,1]:
    nums=[9,9];nums[own]=8
    rows.append(dict(base,kind='two_black',numbers=nums,own=own,enemy=1-own))
    nums=[8,8];nums[own]=1
    rows.append(dict(base,kind='two_own',numbers=nums,own=own,enemy=1-own))
root=ROOT/'QiuJi/Resources/ThreeBallBank';idx=read(root/'manifest.json')
for shard in rng.sample(idx['shards'],8):
 p=root/shard['file']; assert hashlib.sha256(p.read_bytes()).hexdigest()==shard['sha256']
 for row in rng.sample(read(p,True),20):
  base=dict(source='three',sourceID=row['id'],cue=row['board']['cue'],positions=[row['board']['object'],row['second'],row['third']],originalAngle=row['board']['angle'])
  for nums in itertools.permutations([1,9,8]):rows.append(dict(base,kind='three',numbers=nums,own=nums.index(1),enemy=nums.index(9)))
for i,q in enumerate(rows):q['id']=i
(HERE/'candidate-input.json').write_text(json.dumps(rows,separators=(',',':')))
(OUT/'bank-provenance.json').write_text(json.dumps(dict(seed=20261104,files=hashes,candidates=len(rows),sampling='Stratified reservoir for accuracy; deterministic random shards and rows for two/three, all role permutations. Not a full-bank scan.'),indent=2))
(HERE/'protocol.json').write_text(json.dumps(dict(scope='Opening-position defense candidates only; no validated safety stroke or combined 0-100 score',metric='Clean object-window mapped to cue aiming window; six pockets, static ball obstruction, no throw/spin or speed tolerance',selection='Lower cue-window tail with layout diversity; comfort shown separately, not used as a composite score'),indent=2))
print('Candidates',len(rows),'unique targets',len({tuple(p) for q in rows for p in q['positions']}))
