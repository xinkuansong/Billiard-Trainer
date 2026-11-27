from pathlib import Path
import json,hashlib,gzip,random
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OLD=ROOT/'output/defense-full-5698-20261104/r1';OUT=ROOT/'output/defense-no-recontact-522-20261104/r1'
def read(p):return json.loads(p.read_bytes())
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,sort_keys=True,separators=(',',':')))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
missing=set(read(OUT/'missing-question-ids.json'));samples=[q for q in read(OLD/'samples.json') if q['kind']+':'+q['formationID'] in missing];assert len(samples)==522
config=dict(workers=8,inputSHA256=sha(OUT/'missing-question-ids.json'),sourceSnapshotSHA256=sha(OLD/'source-snapshot.tar.gz'),algorithmSHA256={n:sha(HERE/n) for n in ['main.swift','Attack.swift','PipeWindow.swift','run.py','prepare.py','pack.py','bank.py']})
config['fingerprint']=hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest()
if (OUT/'run-config.json').exists():assert read(OUT/'run-config.json')==config
else:
 write(OUT/'run-config.json',config);write(OUT/'samples.json',samples)
 policy=read(OLD/'solve-policy.json');policy.update(forbidTargetMainRailCueRecontact=True,priorReferencesReplayed=0,scope='Research 522 emptied questions with eight independent processes; frozen original physics')
 write(OUT/'solve-policy.json',policy)
 random.Random(2026110499).shuffle(samples)
 for i in range(8):
  p=OUT/'workers'/f'{i:02d}';write(p/'samples.json',samples[i::8]);write(p/'seed-references.json',{});write(p/'run-config.json',config)
for p in OUT.glob('workers/*/questions/*.checkpoint.json'):
 cp=read(p);assert cp['fingerprint']==config['fingerprint'];raw=p.with_name(p.name.replace('.checkpoint.json','.json'));gz=raw.with_suffix('.json.gz');b=raw.read_bytes() if raw.exists() else gzip.decompress(gz.read_bytes());assert hashlib.sha256(b).hexdigest()==cp['resultSHA256']
 d=json.loads(b);assert d['input']==cp['input'] and d['summary']==cp['summary']
print('Prepared 522 / 8 workers')
