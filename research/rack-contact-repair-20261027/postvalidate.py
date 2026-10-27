from pathlib import Path
import json,hashlib,gzip
O=Path('output/rack-contact-repair-20261027');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
before=json.load(open(O/'production-before.json'));changed=[p for p,h in before.items() if sha(p)!=h]
assert set(changed)=={'QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift','QiuJi/Core/Components/BTShotPageChrome.swift'},changed
bindings=[json.load(open(O/(label+'-source-binding.json'))) for label in ['production','repair']]
assert bindings[0]['production']==bindings[1]['production']
assert bindings[0]['objects']==bindings[1]['objects']
assert all(sha(r['path'])==r['sha256'] for r in bindings[0]['production'])
old={};new={}
for source,idx in [(O/'attempt-input-reporting-r4/raw.jsonl.gz',old),(O/'raw.jsonl.gz',new)]:
 for line in gzip.open(source,'rt'):
  r=json.loads(line)
  if r['input']['experiment']=='production' and r['input']['condition']=='original' and r['input']['rackID']<20000:idx[r['input']['rackID']]={k:r[k] for k in ['board','contacts','duration']}
assert len(new)==200 and old==new
close=json.load(open(O/'closure.json'));assert not close['success'] and close['total']==1402 and close['shutdownExitCode']==0
assert json.load(open(O/'worker-closure.json'))=={'production':0,'repair':0}
result=dict(nativeRunsComplete=1402,workerExitCodes={'production':0,'repair':0},originalWholeWorkspaceMonitorPassed=False,originalFailureRetained=True,changedSources=changed,changedSourcesClassification='Concurrent UI source edits, not performed by this task; frozen worker objects identical in both arms; outside physics/rack source bindings',allPhysicsAndRackBindingsUnchanged=True,bindingCount=len(bindings[0]['production']),sameFrozenObjects=True,repeatedCurrentToolchainProductionExact=200,scopeReviewPassed=True)
(O/'post-run-validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
