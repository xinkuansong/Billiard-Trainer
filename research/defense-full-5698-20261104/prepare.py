from pathlib import Path
import gzip,hashlib,json,random
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/defense-full-5698-20261104/r1';PILOT=ROOT/'output/defense-constrained-20-20261104/r1'
def read(p):return json.loads(p.read_text())
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':')))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pilot={q['kind']+':'+q['formationID']:q for q in read(PILOT/'samples.json')};samples=[];seeds={}
inputs={}
for ki,kind in enumerate(['one','two_black','two_own','three'],1):
 p=ROOT/'output/defense-selected-5698-20261104'/f'{kind}.jsonl.gz';inputs[kind]=sha(p)
 with gzip.open(p,'rt') as f:
  for i,q in enumerate(map(json.loads,f),1):
   key=kind+':'+q['formationID'];q['sampleID']=pilot[key]['sampleID'] if key in pilot else f'F{ki:02d}-{i:06d}'
   samples.append(q)
   if key in pilot:
    d=read(PILOT/'questions'/f'{q["sampleID"]}.json');seeds[q['sampleID']]=[r['shot'] for r in d['references']]
assert len(samples)==5698 and len({q['sampleID'] for q in samples})==5698
config=dict(version=1,workers=8,inputSHA256=inputs,algorithmSHA256={n:sha(HERE/n) for n in ['main.swift','Attack.swift','PipeWindow.swift','run.py','prepare.py']},packerSHA256=sha(ROOT/'scripts/defense-bank/pack.py'),sourceManifestSHA256=sha(PILOT/'source-manifest.json'),seedReferencesSHA256=hashlib.sha256(json.dumps(seeds,sort_keys=True).encode()).hexdigest())
config['fingerprint']=hashlib.sha256(json.dumps(config,sort_keys=True,separators=(',',':')).encode()).hexdigest()
if (OUT/'run-config.json').exists():assert read(OUT/'run-config.json')==config,'Immutable run mismatch; choose a new run directory'
else:
 write(OUT/'run-config.json',config);write(OUT/'samples.json',samples);write(OUT/'seed-references.json',seeds)
 policy=read(PILOT/'solve-policy.json');policy['priorReferencesReplayed']=sum(map(len,seeds.values()));policy['scope']='Full 5698 fresh search, eight processes, atomic per-question checkpoints, event-order legality'
 write(OUT/'solve-policy.json',policy)
 shuffled=list(samples);random.Random(2026110488).shuffle(shuffled)
 for i in range(8):
  d=OUT/'workers'/f'{i:02d}';part=shuffled[i::8];write(d/'samples.json',part);write(d/'seed-references.json',{q['sampleID']:seeds[q['sampleID']] for q in part if q['sampleID'] in seeds});write(d/'run-config.json',config)
# Resume checks require a complete matching record, not just a checkpoint marker.
for d in sorted((OUT/'workers').iterdir()):
 expected={q['sampleID']:q for q in read(d/'samples.json')}
 for cp in (d/'questions').glob('*.checkpoint.json'):
  v=read(cp);q=v['input'];assert v['fingerprint']==config['fingerprint'] and q==expected[q['sampleID']]
  p=d/'questions'/f'{q["sampleID"]}.json';g=p.with_suffix('.json.gz')
  raw=p.read_bytes() if p.exists() else gzip.decompress(g.read_bytes())
  assert hashlib.sha256(raw).hexdigest()==v['resultSHA256']
  result=json.loads(raw)
  assert result['input']==q and result['summary']==v['summary']
print(json.dumps(dict(output=str(OUT),inputs=len(samples),workers=8,priorReferences=sum(map(len,seeds.values())),fingerprint=config['fingerprint'])))
