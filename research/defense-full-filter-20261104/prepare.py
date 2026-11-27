"""Stream every bundled board to bounded chunks; never modify source banks."""
from pathlib import Path
import gzip,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent;OUT=ROOT/'output/defense-full-filter-20261104'
OUT.mkdir(exist_ok=True);(OUT/'inputs').mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import layouts
sha=lambda b:hashlib.sha256(b).hexdigest()
files={};chunks=[];counts={};ordinal=0
def read(p):
 b=p.read_bytes();files[str(p.relative_to(ROOT))]=sha(b);return json.loads(b)
def write_chunk(kind,buf):
 if not buf:return
 name=f'inputs/{kind}-{sum(c["bank"]==kind for c in chunks):04d}.json'
 data=json.dumps(buf,separators=(',',':'),allow_nan=False).encode();(OUT/name).write_bytes(data)
 chunks.append(dict(file=name,bank=kind,rows=len(buf),evaluations=len(buf)*len(buf[0]['positions']),sha256=sha(data),first=buf[0]['ordinal'],last=buf[-1]['ordinal']))
def emit(kind,iterator):
 global ordinal
 buf=[];n=0
 for row in iterator:
  row['bank']=kind;row['ordinal']=ordinal;ordinal+=1;buf.append(row);n+=1
  if len(buf)==5000:write_chunk(kind,buf);buf=[]
 write_chunk(kind,buf);counts[kind]=n;print(kind,n,'boards',flush=True)
bank=read(ROOT/'QiuJi/Resources/training-grid-bank.json')
emit('one',(dict(sourceID=lid,cue=c,positions=[o],originalPocket=p,originalAngle=a) for lid,c,o,p,a in layouts(bank)))
assert counts['one']==sum(bank['counts'].values())
root=ROOT/'QiuJi/Resources/TwoBallBank';idx=read(root/'index.json')
def two():
 seen=set()
 for shard in idx['shards']:
  p=root/(shard.get('file') or shard['name']+'.jsonl.gz');b=p.read_bytes();assert sha(b)==shard['sha256'];files[str(p.relative_to(ROOT))]=sha(b)
  for row in map(json.loads,gzip.decompress(b).splitlines()):
   assert row['id'] not in seen;seen.add(row['id'])
   for q in row['questions']:
    yield dict(sourceID=str(row['id'])+'/'+str(q['id']),cue=row['board']['cue'],positions=[row['board']['object'],q['p']],originalPocket=row['board']['pocket'],originalAngle=row['board']['angle'])
 assert len(seen)==idx['counts']['layouts']
emit('two',two());assert counts['two']==idx['counts']['questions']
root=ROOT/'QiuJi/Resources/ThreeBallBank';idx=read(root/'manifest.json')
def three():
 seen=set()
 for shard in idx['shards']:
  p=root/shard['file'];b=p.read_bytes();assert sha(b)==shard['sha256'];files[str(p.relative_to(ROOT))]=sha(b)
  rows=json.loads(gzip.decompress(b));assert len(rows)==shard['count']
  for row in rows:
   assert row['id'] not in seen;seen.add(row['id'])
   yield dict(sourceID=row['id'],cue=row['board']['cue'],positions=[row['board']['object'],row['second'],row['third']],originalPocket=row['board']['pocket'],originalAngle=row['board']['angle'])
emit('three',three());assert counts['three']==idx['count']
manifest=dict(version=1,counts=counts,boards=ordinal,targetEvaluations=counts['one']+2*counts['two']+3*counts['three'],roleAssignments=counts['one']+4*counts['two']+6*counts['three'],sourceFiles=files,chunks=chunks)
(OUT/'input-manifest.json').write_text(json.dumps(manifest,indent=2))
policy=json.loads((ROOT/'output/defense-reuse-20261104/strict-r3/protocol.json').read_text());policy.update(scope='Full bundled banks, every target role, opening-position filter only',roleExpansion={'one':1,'two':4,'three':6},dedup='Exact coordinates and role-preserving X/Z mirrors; all aliases retained; no coordinate quantization')
(OUT/'protocol.json').write_text(json.dumps(policy,ensure_ascii=False,indent=2))
print({k:v for k,v in manifest.items() if k not in ['sourceFiles','chunks']},'chunks',len(chunks),'files',len(files))
