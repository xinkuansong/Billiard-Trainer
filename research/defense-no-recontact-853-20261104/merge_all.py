from pathlib import Path
import importlib.util,json
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'research/defense-no-recontact-522-20261104/bank.py'
spec=importlib.util.spec_from_file_location('bank',H);b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
base=b.OUT;second=ROOT/'output/defense-no-recontact-853-20261104/r1';dest=ROOT/'output/defense-no-recontact-1375-20261104/r1';dest.mkdir(parents=True,exist_ok=True)
_,original=b.load(b.OLD/'bank');_,clean=b.load(base/'filtered-bank');_,new1=b.load(base/'bank');_,new2=b.load(second/'bank')
for q in new1+new2:
 for r in q['references']:r['selectionProbePolicyVersion']=b.POLICY
allrows={q['id']:dict(q,references=[]) for q in original};allids=set(allrows)
for rows in (clean,new1,new2):
 for q in rows:
  assert q['id'] in allrows
  target=allrows[q['id']]
  assert all(target[k]==q[k] for k in ('cue','balls','ownBallNumber','opponentBallNumber','sourceFormationID'))
  refs={r['id']:r for r in target['references']}
  for r in q['references']:
   assert not b.forbidden(r['expected']['events'],q['ownBallNumber'])
   refs[r['id']]=r
  target['references']=list(refs.values())
ready=[q for q in allrows.values() if q['references']];pending=[q for q in allrows.values() if not q['references']]
assert {q['id'] for q in ready+pending}==allids and len(allids)==4340
coverage=b.read(b.OLD/'bank/coverage.json')
for c in coverage:
 if c['id'] in allrows:c.update(status='found' if allrows[c['id']]['references'] else 'pending-reference',referenceCount=len(allrows[c['id']]['references']))
b.write(dest/'pending-questions.json',pending)
b.write(dest/'question-inventory.json',[dict(id=q['id'],sampleID=q['sampleID'],kind=q['kind'],cue=q['cue'],balls=q['balls'],ownBallNumber=q['ownBallNumber'],opponentBallNumber=q['opponentBallNumber'],status='ready' if q['references'] else 'pending-reference') for q in allrows.values()])
idx=b.export(ready,coverage,dest/'bank',dict(researchedQuestions=1375,originalQuestionIDsPreserved=4340,pendingQuestions=len(pending),firstRun=b.read(base/'run-config.json')['fingerprint'],secondRun=b.read(second/'run-config.json')['fingerprint']))
b.write(dest/'summary.json',dict(complete=True,recomputed=1375,originalQuestions=4340,readyQuestions=len(ready),pendingQuestions=len(pending),references=idx['counts']['references'],deletedQuestionIDs=0,forbiddenReferences=0))
print((dest/'summary.json').read_text())
