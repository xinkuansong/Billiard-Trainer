"""Only B/pocket decisions; never reject a pair with an existing direct-pot witness."""
from prepare import *
import struct,collections
def f32key(b,p):return (*[struct.unpack('f',struct.pack('f',v))[0] for v in b],p)
def main():
 raw=read(OUT/'geometry-proofs.json');lookup={f32key(p['object'],p['pocket']):p['key'] for p in raw};assert len(lookup)==len(raw)
 prior=ROOT/'output/two-ball-middle-filter-20261025';witnesses={};sources={}
 for receipt in read(prior/'parts-index.json'):
  path=prior/'proofs'/(receipt['stem']+'.jsonl.gz');assert sha(path)==receipt['proofsSHA256'];sources[str(path)]=receipt['proofsSHA256']
  for row in rows(path):
   for proof in row['middleProofs']:
    request=proof['request'];fk=f32key(request['object'],request['pocket'])
    if fk not in lookup:continue
    for i,t in enumerate(proof['trials']):
     if t['settled'] and t['targetPotted'] and t['route']=='direct-pot':
      assert any(e['kind']=='pocket' and e['ball']=='object' and e['pocketID']==f"pocket_{request['pocket']}" for e in t['events'])
      k=lookup[fk]
      if k not in witnesses:witnesses[k]=dict(source=str(path),sourceSHA256=receipt['proofsSHA256'],layoutID=row['id'],oldProofKey=proof['key'],trial=i,events=t['events'],cuePocketed=t['cuePocketed'])
      break
 dest=OUT/'native-validation';complete=read(dest/'complete.json');assert sha(dest/'proofs.json')==complete['proofsSHA256'];native={p['key']:p for p in read(dest/'proofs.json')};assert set(native)=={p['key'] for p in raw if not p['passed']}
 decisions=[];counts=collections.Counter()
 for p in raw:
  k=p['key'];reason='clean-ray' if p['passed'] else 'single-B-direct-pot' if native[k]['passed'] else 'existing-target-direct-pot' if k in witnesses else 'incomplete-retained' if any(not t['settled'] for t in native[k]['trials']) else 'blocked-ray-and-no-direct-pot-in-bounded-probes'
  keep=reason!='blocked-ray-and-no-direct-pot-in-bounded-probes';counts[reason]+=1
  decisions.append(dict(key=k,object=p['object'],pocket=p['pocket'],passed=keep,reason=reason,rayPassed=p['passed'],nativeProofKey=k if k in native else None,witnessKey=k if k in witnesses and not p['passed'] else None))
 write(OUT/'entry-decisions.json',decisions);write(OUT/'existing-pot-witnesses.json',witnesses);write(OUT/'witness-source-hashes.json',sources)
 m=read(OUT/'manifest.json');m['policy'].update(version='B-pocket-entry-v2',predicate='clean original ray OR sole-B direct pot OR existing target direct-pot witness; incomplete retained',nativeProbe='only B, fixed original direction, zero spin, .5..8 adaptive up to5; own-pocket jaw contact allowed; no cue/access/scratch condition',scope='B/pocket entry screen with bounded physical fallback; not mathematical all-parameter impossibility',previousPureRayRun='diagnostic-pure-ray/; rejected for over-filtering valid own-mouth contact');write(OUT/'manifest.json',m)
 write(OUT/'entry-audit.json',dict(passed=True,counts=dict(counts),allPairs=len(decisions),retainedPairs=sum(p['passed'] for p in decisions),deletedPairs=sum(not p['passed'] for p in decisions),noKnownDirectPotPairDeleted=all(p['passed'] or p['key'] not in witnesses for p in decisions),decisionSHA256=sha(OUT/'entry-decisions.json'),witnessSHA256=sha(OUT/'existing-pot-witnesses.json'),nativeProofsSHA256=sha(dest/'proofs.json')))
 print((OUT/'entry-audit.json').read_text())
if __name__=='__main__':main()
