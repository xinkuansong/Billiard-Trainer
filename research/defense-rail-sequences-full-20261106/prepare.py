"""Freeze the authorized full free-bank pool without changing any coordinates."""
from pathlib import Path
import gzip,json,hashlib,random,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
BASE=ROOT/'research/defense-85-validation-20261106'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':')))
qs=json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-free-bank.json.gz').read_bytes()))
qs=[{**q,'references':[]} for q in qs if q['kind']!='one'];assert len(qs)==57575
policy={'version':'defense-per-ball-rail-sequences-v2','sourceFreeBankSHA256':sha(ROOT/'QiuJi/Resources/defense-free-bank.json.gz'),'sourceTrajectorySHA256':sha(ROOT/'QiuJi/Resources/defense-practice-bank.json.gz'),'count':len(qs),'workers':8,'primaryScore':80,'potentialScore':85,'allowBlockingFallback':True,'minimumSolutions':2,'maximumRetainedSolutions':6,'minimumCueOpponentDistance':.30,'cutDegrees':[15,30,45,60],'probeAngles':[-.1,.1],'probeSpeedScales':[.95,1.05],'ownPotential':'positive-confirmed-window-not-below-initial-provisional','diversity':'different ordered main-rail sequence of cue OR own target, independently; no endpoint or interleaving distinction','fixedNonOwnBalls':True,'referenceRestrictions':['main-cushions-only','no-object-object-contact','no-own-cushion-then-cue-recontact'],'publication':'independent new-schema candidate package, no production replacement'}
if (OUT/'policy.json').exists():assert json.loads((OUT/'policy.json').read_text())==policy,'Immutable policy differs'
write(OUT/'policy.json',policy);write(OUT/'inputs.json',qs)
# Known ten-case inputs plus actual production-reference cases and free-only cases per kind.
known=json.loads((ROOT/'output/defense-85-validation-20261106/scenario.json').read_text())['cases']
lookup={q['id']:q for q in qs};pilot={c['question']['id']:lookup[c['question']['id']] for c in known}
old=json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()))['questions'];oldids={q['id'] for q in old}
rng=random.Random(2026110601)
for kind in ['two_own','three']:
 a=[q for q in qs if q['kind']==kind and q['id'] in oldids];rng.shuffle(a)
 for q in a[:10]:pilot[q['id']]=q
for kind in ['two_black','two_own','three']:
 a=[q for q in qs if q['kind']==kind and q['id'] not in oldids];rng.shuffle(a)
 for q in a[:2]:pilot[q['id']]=q
write(OUT/'pilot-inputs.json',list(pilot.values()))
# Persist identities, not a hard-coded output count or zero-filled old metrics.
write(OUT/'input-audit.json',{'passed':True,'counts':{k:sum(q['kind']==k for q in qs) for k in ['two_black','two_own','three']},'uniqueIDs':len(set(q['id'] for q in qs)),'pilotCount':len(pilot),'inputSHA256':sha(OUT/'inputs.json')})
print('Prepared',len(qs),'full inputs and',len(pilot),'pilot cases')
