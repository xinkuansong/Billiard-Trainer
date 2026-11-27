"""Install verified staged banks and narrowly synchronize loader/test expectations."""
import hashlib,json,re,shutil
from pathlib import Path
from prepare import OUT,ROOT

def main():
 stage=OUT/'app-package';report=json.loads((stage/'defense-practice-provenance.json').read_bytes());selection=json.loads((OUT/'selection.json').read_bytes())
 assert json.loads((OUT/'qualified-replay.json').read_bytes())['passed']
 for name,oldsha in selection['sourceSHA256'].items():
  p=ROOT/'QiuJi/Resources'/name
  assert hashlib.sha256(p.read_bytes()).hexdigest()==oldsha,('Production bank changed during validation',name)
  assert hashlib.sha256((stage/name).read_bytes()).hexdigest()==report['outputSHA256'][name]
 p=ROOT/'QiuJi/Features/DefensePractice/DefenseQuestionPreparer.swift';s=p.read_text();before=OUT/'before';(before/p.name).write_text(s)
 trajectorySHA=report['outputSHA256']['defense-practice-bank.json.gz'];freeSHA=report['outputSHA256']['defense-free-bank.json.gz']
 oldfp='defense-full4234-free59000-v2-6310a129-3d9b9311';newfp=f"defense-grid20-fixedmirror-v3-{report['referenceQuestions']}-{report['freeQuestions']}-{trajectorySHA[:8]}-{freeSHA[:8]}"
 replacements={oldfp:newfp,selection['sourceSHA256']['defense-practice-bank.json.gz']:trajectorySHA,selection['sourceSHA256']['defense-free-bank.json.gz']:freeSHA,'8ade37155415125b2e59f50b9550802e9c70d7192fcd795db4cc7e3f85872565':report['sourceFingerprint']}
 for old,new in replacements.items():assert s.count(old)==1,old;s=s.replace(old,new)
 tests=ROOT/'QiuJiTests/DefensePracticeTests.swift';t=tests.read_text();(before/tests.name).write_text(t)
 replacements={'trajectory.count,4234':f"trajectory.count,{report['referenceQuestions']}",'references).count,10191':f"references).count,{report['references']}",'free.count,59000':f"free.count,{report['freeQuestions']}",'["one":1001,"two_black":1040,"two_own":1050,"three":1143]':'['+','.join('\"'+k+'\":'+str(v) for k,v in json.loads((OUT/'qualified-replay.json').read_bytes())['counts'].items())+']'}
 for old,new in replacements.items():assert t.count(old)==1,old;t=t.replace(old,new)
 # No changes to runtime selection, scores, user-shot rules or history payloads.
 for name in selection['sourceSHA256']:
  dst=ROOT/'QiuJi/Resources'/name;tmp=dst.with_suffix('.new');tmp.write_bytes((stage/name).read_bytes());tmp.replace(dst)
 p.write_text(s);tests.write_text(t)
 (OUT/'publication.json').write_text(json.dumps(dict(published=True,fingerprint=newfp,**report),ensure_ascii=False,indent=2)+'\n')
 print('Published',report['referenceQuestions'],report['references'],report['freeQuestions'],newfp)
if __name__=='__main__':main()
