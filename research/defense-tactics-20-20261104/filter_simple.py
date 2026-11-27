"""Conservative atlas-only selection; retain original physics and discarded evidence."""
from pathlib import Path
import collections,hashlib,json,math
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/defense-tactics-20-20261104/r3'
OUT=SRC.parent/'r4-simple'
(OUT/'questions').mkdir(parents=True,exist_ok=True)
read=lambda p:json.loads(p.read_text())
policy=dict(scope='Existing 52 references only, no new solve or physics change',maxMainCushionsPerBall=1,maxMainCushionsTotal=2,mainCushionIndices=list(range(6)),removed=[],kept=[],sourceHashes={})
for name in ['samples.json','selection.json','summary.json','source-manifest.json','execution.json']:
 p=SRC/name;policy['sourceHashes'][name]=hashlib.sha256(p.read_bytes()).hexdigest();(OUT/name).write_bytes(p.read_bytes())
for p in sorted((SRC/'questions').glob('*.json')):
 d=read(p);retained=[];rejected=[]
 policy['sourceHashes']['questions/'+p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
 for i,r in enumerate(d['references']):
  banks=collections.Counter(e['ball'] for e in r['events'] if e['kind']=='cushion' and 0<=e.get('index',-1)<6)
  lengths={k:sum(math.dist(a,b) for a,b in zip(v,v[1:])) for k,v in r['paths'].items()}
  ex=dict(mainCushionsByBall=dict(banks),mainCushionCount=sum(banks.values()),travelMetersByBall=lengths,totalTravelMeters=sum(lengths.values()))
  entry=dict(sampleID=d['input']['sampleID'],referenceIndex=i,shot=r['shot'],tactics=r['tactics'],execution=ex)
  keep=max(banks.values(),default=0)<=1 and sum(banks.values())<=2
  if keep:
   r['execution']=ex;retained.append(r);policy['kept'].append(entry)
  else:rejected.append(entry);policy['removed'].append(entry)
 d['references']=retained
 d['referenceSelection']=dict(sourceReferenceCount=d['summary']['referenceCount'],removed=rejected)
 d['summary']['referenceCount']=len(retained)
 for row in d['summary']['coverage']:
  row['originalSearchStatus']=row['status']
  row['retainedSimpleReferences']=sum(row['tactic'] in r['tactics'] for r in retained)
  if row['status']!='not-applicable':row['status']='found' if row['retainedSimpleReferences'] else 'not-found'
 (OUT/'questions'/p.name).write_text(json.dumps(d,ensure_ascii=False))
assert len(policy['kept'])+len(policy['removed'])==52
assert any(x['sampleID']=='S03-04' and x['referenceIndex']==0 for x in policy['removed'])
assert any(x['sampleID']=='S03-03' and x['referenceIndex']==0 for x in policy['kept'])
(OUT/'reference-policy.json').write_text(json.dumps(policy,ensure_ascii=False,indent=2))
# Original summary is retained separately, avoiding a stale reference count in the new summary.
(OUT/'source-summary.json').write_bytes((SRC/'summary.json').read_bytes())
s=read(SRC/'summary.json');s['questions']=[read(p)['summary'] for p in sorted((OUT/'questions').glob('*.json'))];s['referenceSelectionScope']=policy['scope']
(OUT/'summary.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
for name,digest in policy['sourceHashes'].items():assert hashlib.sha256((SRC/name).read_bytes()).hexdigest()==digest
print(json.dumps(dict(kept=len(policy['kept']),removed=len(policy['removed']),userRejectedExampleExcluded=True,userAcceptedExampleRetained=True)))
