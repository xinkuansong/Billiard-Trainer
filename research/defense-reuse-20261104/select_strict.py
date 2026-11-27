"""Conservative review gate anchored to user-accepted 03-1, not calibrated difficulty."""
from pathlib import Path
from collections import Counter
import hashlib,json,math,shutil
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'output/defense-reuse-20261104';OUT=BASE/'strict-r3'
OUT.mkdir(exist_ok=True)
rows=json.loads((BASE/'evaluated.json').read_text());old=json.loads((BASE/'samples.json').read_text())
anchor=next(q for q in old if q['sampleID']=='03-1')
W=anchor['ownAttack']['best']['cueWidth'];C=anchor['ownAttack']['best']['comfort']['total']
def width(q):return q['ownAttack']['best']['cueWidth']
def comfort(q):return max(o.get('comfort',{}).get('total',0) for o in q['ownAttack']['options'])
def accepts(q):return 1e-6<width(q)<=W and comfort(q)<=C
def sig(q):return min(tuple(round(v,3) for p in [[q['cue'][0]*sx,q['cue'][1]*sz]]+sorted([[x*sx,z*sz] for x,z in q['positions']]) for v in p) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
assert accepts(anchor)
negative=[q for q in old if q['sampleID'] in ['03-2','03-3']]
assert len(negative)==2 and all(not accepts(q) for q in negative)
used={sig(anchor)};selected=[];summary={}
for kind,tag in [('one','01'),('two_black','02'),('two_own','03'),('three','04')]:
 pool=[q for q in rows if q['kind']==kind and accepts(q)];chosen=[]
 if kind=='two_own':chosen=[dict(anchor)]
 while len(chosen)<5:
  available=[q for q in pool if sig(q) not in used]
  if not available:break
  def rank(q):
   # Favour examples close to the accepted positive, then spatial diversity.
   closeness=abs(math.log(width(q)/W))+abs(math.log(max(comfort(q),1e-10)/C))*.20
   diversity=min((math.dist(q['cue'],v['cue'])+math.dist(q['positions'][q['own']],v['positions'][v['own']]) for v in chosen),default=2)
   return closeness-.35*min(diversity,2)
  q=min(available,key=rank);used.add(sig(q));chosen.append(dict(q))
 for i,q in enumerate(chosen):
  q['sampleID']=f'S{tag}-{i+1}';q['isAcceptedReference']=q['id']==anchor['id'];q['maxPocketComfort']=comfort(q)
  q['gate']={'cueWidthLimit':W,'comfortLimit':C};selected.append(q)
 summary[kind]={'candidates':sum(q['kind']==kind for q in rows),'qualified':len(pool),'shown':len(chosen),'missing':5-len(chosen),'selected':[q['sampleID'] for q in chosen]}
assert len({sig(q) for q in selected})==len(selected)
protocol={'policy':'accepted-03-1-conservative-review-v1','cueWidthLimitDegrees':W,'maxRepresentativeComfortLimit':C,'referenceID':anchor['id'],'referenceOldSampleID':'03-1','referenceSourceID':anchor['sourceID'],'referenceRoleNumbers':anchor['numbers'],'rule':'Both six-pocket maximum cue window and maximum comfort among the six stored representative routes must be no higher than accepted 03-1; positive window >1e-6 degree numerical floor. Missing quota stays empty. Not a calibrated human threshold, continuous comfort optimum, or defense-solution proof.','evaluationSHA256':hashlib.sha256((BASE/'evaluated.json').read_bytes()).hexdigest(),'controls':[{'oldID':q['sampleID'],'id':q['id'],'accepted':accepts(q),'cueWidth':width(q),'maxRepresentativeComfort':comfort(q)} for q in [anchor]+negative]}
for name in ['geometry.json','bank-provenance.json','candidate-input.json','summary.json']:
 shutil.copy2(BASE/name,OUT/name)
(OUT/'selected-input.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2))
(OUT/'selection-input.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
(OUT/'protocol.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2));print('limits',W,C)
