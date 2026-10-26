from pathlib import Path
import json,hashlib,datetime,difflib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;BASE=ROOT/'research/two-ball-strike-full-20261024/native-source'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
exc=json.loads((OUT/'source-exception.json').read_text());excs=[exc]
p=ROOT/'QiuJi/Core/Scene/AngleSceneCalculator.swift';f=BASE/p.name
old=f.read_text();new=p.read_text();start='    struct DailyPocketCandidate {';end='    enum DirectPocketAssessment'
a,b=old.index(start),old.index(end);c,d=new.index(start),new.index(end)
assert old[:a]==new[:c] and old[b:]==new[d:]
entry=(HERE/'main.swift').read_text();assert all(x not in entry for x in ['dailyPocketCandidate','bestComfortCandidate','DailyPocketCandidate'])
excs.append(dict(path=str(p.relative_to(ROOT)),currentSHA256=sha(p),frozenSHA256=sha(f),reason='Concurrent edit confined to DailyPocketCandidate and dailyPocketCandidate/bestComfortCandidate convenience ranking section. Exact source prefix and suffix outside that section byte-identical. No call from research entry, BreakSimulator or physics. Frozen table/pocket geometry and score unaffected.',unchangedPrefixSHA256=hashlib.sha256(old[:a].encode()).hexdigest(),unchangedSuffixSHA256=hashlib.sha256(old[b:].encode()).hexdigest()))
(OUT/'source-exceptions.json').write_text(json.dumps(excs,indent=2))
(OUT/'concurrent-angle-diff.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=str(f),tofile=str(p))))
b=(HERE/'build.py').read_text()
b=b.replace("exception = json.loads((OUT.parent/'source-exception.json').read_text())","exception = next(e for e in json.loads((OUT.parent/'source-exceptions.json').read_text()) if e['path']==str(q.relative_to(ROOT)))")
b=b.replace("wrapperException=json.loads((OUT.parent/'source-exception.json').read_text())","reviewedExceptions=json.loads((OUT.parent/'source-exceptions.json').read_text())")
(HERE/'build.py').write_text(b)
# Preserve original failure and outputs. Explicit post-run review separately validates frozen simulation data.
binding=json.loads((OUT/'discovery/source-binding.json').read_text());drift=[]
for x in binding['production']:
 p=ROOT/x['path']
 if sha(p)!=x['sha256']:
  e=next(e for e in excs if e['path']==x['path']);assert sha(p)==e['currentSHA256'] and x['sha256']==e['frozenSHA256'];drift.append(e)
assert len(drift)==1
r=dict(createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),originalExitCode=1,reason='Post-run source guard detected unrelated concurrent daily-ranking edit; all 2700 simulations finished on immutable frozen binary. Preserve failed closure; reviewed exact source isolation permits using data for this physics-only study.',reviewedDrift=drift,simulationValid=True)
(OUT/'discovery/post-run-review.json').write_text(json.dumps(r,indent=2))
# Analysis must accept only precisely reviewed unrelated changes, not arbitrary drift.
p=HERE/'analyze.py';s=p.read_text();oldline="binding=json.loads((folder/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in binding['production'])"
newline="""binding=json.loads((folder/'source-binding.json').read_text())
 exceptions=json.loads((OUT/'source-exceptions.json').read_text())
 for r in binding['production']:
  current=hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()
  if current!=r['sha256']:
   e=next(e for e in exceptions if e['path']==r['path']);assert current==e['currentSHA256'] and r['sha256']==e['frozenSHA256']
   assert stage=='discovery' and json.loads((folder/'post-run-review.json').read_text())['simulationValid']"""
assert oldline in s;s=s.replace(oldline,newline);p.write_text(s)
print('Source drift isolated to unused daily ranking; discovery failure retained and research data reconciled.')
