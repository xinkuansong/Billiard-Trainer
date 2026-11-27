"""Re-index every source layout/role. No old defense-bank eligibility is reused."""
from pathlib import Path
import gzip,json,hashlib,itertools,sqlite3,struct,random,time
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
OUT.mkdir(parents=True,exist_ok=True);db=OUT/'inputs.sqlite3'
if db.exists():raise SystemExit('Existing immutable input database; inspect manifest instead of overwriting')
con=sqlite3.connect(db);con.executescript('''CREATE TABLE boards(id TEXT PRIMARY KEY, kind TEXT, cue TEXT, positions TEXT);
CREATE TABLE maps(id TEXT PRIMARY KEY, target TEXT, blockers TEXT, kind TEXT);
CREATE TABLE roles(id TEXT PRIMARY KEY, board TEXT, own INTEGER, opponent INTEGER, static INTEGER, map TEXT, kind TEXT);
CREATE INDEX roles_map ON roles(map);''')
files={};counts={};started=time.time()
def read(p):
 b=p.read_bytes();files[str(p.relative_to(ROOT))]=hashlib.sha256(b).hexdigest();return b
def f32(p):return [struct.unpack('f',struct.pack('f',x))[0] for x in p]
def add(kind,sid,cue,points):
 bid=kind+':'+str(sid);con.execute('INSERT INTO boards VALUES(?,?,?,?)',(bid,kind,json.dumps(cue),json.dumps(points)))
 assignments=[(own,enemy,-1,k) for own,enemy in itertools.permutations(range(2)) for k in ['two_black','two_own']] if kind=='two' else [(a,b,c,'three') for a,b,c in itertools.permutations(range(3))]
 for own,enemy,static,k in assignments:
  t=f32(points[enemy]);b=[] if static<0 else [f32(points[static])]
  key=json.dumps([t,b],separators=(',',':'));mid=hashlib.sha256(key.encode()).hexdigest()[:32]
  con.execute('INSERT OR IGNORE INTO maps VALUES(?,?,?,?)',(mid,json.dumps(t),json.dumps(b),'two' if static<0 else 'three'))
  rid=bid+f':{k}:{own}:{enemy}'
  con.execute('INSERT INTO roles VALUES(?,?,?,?,?,?,?)',(rid,bid,own,enemy,static,mid,k))
 counts[kind]=counts.get(kind,0)+1
R=ROOT/'QiuJi/Resources/TwoBallBank';idx=json.loads(read(R/'index.json'))
for shard in idx['shards']:
 p=R/(shard.get('file') or shard['name']+'.jsonl.gz');b=read(p);assert hashlib.sha256(b).hexdigest()==shard['sha256']
 for row in map(json.loads,gzip.decompress(b).splitlines()):
  for q in row['questions']:add('two',str(row['id'])+'/'+str(q['id']),row['board']['cue'],[row['board']['object'],q['p']])
 con.commit()
assert counts['two']==idx['counts']['questions']
R=ROOT/'QiuJi/Resources/ThreeBallBank';idx=json.loads(read(R/'manifest.json'))
for shard in idx['shards']:
 p=R/shard['file'];b=read(p);assert hashlib.sha256(b).hexdigest()==shard['sha256']
 for row in json.loads(gzip.decompress(b)):add('three',row['id'],row['board']['cue'],[row['board']['object'],row['second'],row['third']])
 con.commit()
assert counts['three']==idx['count']
roles=dict(con.execute('SELECT kind,COUNT(*) FROM roles GROUP BY kind'));maps=dict(con.execute('SELECT kind,COUNT(*) FROM maps GROUP BY kind'))
rng=random.Random(2026110609);samples=[]
for kind in ['two','three']:
 ids=[r[0] for r in con.execute('SELECT id FROM maps WHERE kind=? ORDER BY id',(kind,))];rng.shuffle(ids)
 for mid in ids[:12]:
  row=con.execute('SELECT id,target,blockers,kind FROM maps WHERE id=?',(mid,)).fetchone()
  samples.append(dict(id=row[0],target=json.loads(row[1]),blockers=json.loads(row[2]),kind=row[3]))
(OUT/'pilot-inputs.json').write_text(json.dumps(samples,indent=2));con.close()
manifest=dict(version='lambda5-source-regions-v1',counts=counts,roles=roles,maps=maps,sourceFiles=files,databaseSHA256=hashlib.sha256(db.read_bytes()).hexdigest(),seconds=time.time()-started,scope='All raw TwoBallBank and ThreeBallBank positions and role assignments. Own ball omitted from fixed-opponent region map. Low intrinsic potential remains pending dynamic blocking search, not globally rejected.',coordinatePolicy='Keep source board doubles verbatim; cache map key uses identical Float conversion as production; no grid snapping, mirrors or perturbation of target balls.')
(OUT/'input-manifest.json').write_text(json.dumps(manifest,indent=2));print({k:v for k,v in manifest.items() if k!='sourceFiles'},flush=True)
