from pathlib import Path
import json,hashlib,zipfile,urllib.request
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-best-100-20261026';a=json.loads((OUT/'atlas.json').read_text())
assert len(a['cases'])==100 and [c['index'] for c in a['cases']]==list(range(1,101))
assert len({c['seed'] for c in a['cases']})==100
files=['index.html','atlas.json','100-break-results.zip']+[f'boards/{i:03d}.png' for i in range(1,101)]+[f'overviews/{i:02d}.jpg' for i in range(1,11)]
for f in files:
 with urllib.request.urlopen('http://127.0.0.1:60595/'+f) as r:assert r.status==200 and r.read()==(OUT/f).read_bytes()
for p in (OUT/'boards').glob('*.png'):
 with Image.open(p) as im:assert im.size==(1200,760);im.verify()
with zipfile.ZipFile(OUT/'100-break-results.zip') as z:
 assert z.testzip() is None
 assert len([n for n in z.namelist() if n.startswith('boards/')])==100
 for n in z.namelist():assert z.read(n)==(OUT/n).read_bytes()
result=dict(httpVerified=len(files),pngCount=100,zipVerified=True,browserVerified=['first case','next','case100 thumbnail and boundary','before/after','candidate/baseline','typed jump back to1','visual screenshot'],sourceReview='post-generation-source-review.json',localServer='http://127.0.0.1:60595/')
(OUT/'gallery-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
manifest={str(p.relative_to(OUT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.rglob('*') if p.is_file() and p.name!='manifest.json'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
