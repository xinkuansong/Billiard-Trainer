"""Uniformly retain at most three positions per fixed base after 2x2 thinning."""
from pathlib import Path
import copy, hashlib, json, random, shutil
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
PARENT=ROOT/'output/three-ball-block-sampling-20261027'
OUT=ROOT/'output'/HERE.name
SEED='three-ball-after-block-random3-20261027-v1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pick(identity, ids):
 digest=hashlib.sha256((SEED+'\0'+identity).encode()).digest()
 return sorted(random.Random(int.from_bytes(digest,'big')).sample(sorted(ids),min(3,len(ids))))
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 sources=['viewer-data.json','sampling.json','sampling-audit.json','completion.json']
 hashes={n:sha(PARENT/n) for n in sources}
 parent=json.loads((PARENT/'viewer-data.json').read_text());data=copy.deepcopy(parent);rows=[];selected=[]
 for d,old in zip(data['samples'],parent['samples']):
  before=old['sampling'];ids=before['selectedCellIDs'];chosen=pick(before['identity'],ids)
  assert len(chosen)==min(3,len(ids)) and len(set(chosen))==len(chosen) and set(chosen)<=set(ids)
  assert chosen==pick(before['identity'],list(reversed(ids)))
  if len(ids)<=3:assert chosen==sorted(ids)
  d['blockSampling']=copy.deepcopy(before)
  for c,oc in zip(d['candidates'],old['candidates']):
   c['blockSampled']=oc['sampled'];c['sampled']=c['id'] in chosen
   restored={k:v for k,v in c.items() if k!='blockSampled'};restored['sampled']=oc['sampled']
   assert restored==oc
  d['sampling']=dict(identity=before['identity'],before=len(ids),after=len(chosen),selectedCellIDs=chosen,chains=sum(len(c['chains']) for c in d['candidates'] if c['sampled']))
  rows.append(dict(sample=d['sample']['number'],**d['sampling']))
  selected.append(dict(sample=d['sample'],positions=[c for c in old['candidates'] if c['id'] in chosen]))
 data['blockSampling']=copy.deepcopy(parent['sampling'])
 data['sampling']=dict(seed=SEED,stage='uniform without replacement after 2x2 block sampling; one draw per base across pockets',before=sum(r['before'] for r in rows),after=sum(r['after'] for r in rows),chains=sum(r['chains'] for r in rows),sourceSHA256=hashes)
 def write(n,d):(OUT/n).write_text(json.dumps(d,ensure_ascii=False,indent=2,allow_nan=False))
 write('viewer-data.json',data);write('selected-positions.json',selected);write('sampling.json',dict(policy=data['sampling'],samples=rows))
 assert hashes=={n:sha(PARENT/n) for n in sources}
 write('sampling-audit.json',dict(passed=True,sourceSHA256=hashes,sourceUnchanged=True,uniformWithoutReplacement=True,capAndSubsetVerified=True,underThreeRetained=True,allCoordinatesRegionsAndChainsUnchanged=True,deterministicTraversalIndependent=True,physicsRerun=False))
 for n in ['audit.json','filter.json','flow-audit.json']:shutil.copy2(PARENT/n,OUT/n)
 (OUT/'index.html').write_text((HERE/'viewer.html').read_text().replace('/*__DATA__*/',json.dumps(data,ensure_ascii=False,separators=(',',':'),allow_nan=False)))
 print(json.dumps(rows,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
