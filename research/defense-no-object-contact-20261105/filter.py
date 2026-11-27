"""Remove object-object-contact references, preserving every retained reference verbatim."""
from pathlib import Path
import collections,copy,gzip,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-no-object-contact-20261105'
sys.path.insert(0,str(ROOT/'scripts/defense-bank'));from pack import audit,encoded,sha
src=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz';raw=src.read_bytes();old=json.loads(gzip.decompress(raw))
assert sha(raw)=='64c0e63bc48018aa386a7621991a3a994636c7ae48933bc57401af518033c004'
assert not (OUT/'bank').exists(),'Immutable output exists'
(OUT/'before'/src.name).write_bytes(raw)
free=ROOT/'QiuJi/Resources/defense-free-bank.json.gz';freeSHA=sha(free.read_bytes())
rows=[];removed=[];coverage=[];affected=collections.Counter();dropped=collections.Counter()
for original in old['questions']:
 q=copy.deepcopy(original);keep=[]
 for r in q['references']:
  bad=[e for e in r['expected']['events'] if e['kind']=='ballBall' and 0 not in e['ballNumbers']]
  if bad:removed.append(dict(questionID=q['id'],kind=q['kind'],referenceID=r['id'],events=bad))
  else:keep.append(r)
 if len(keep)!=len(q['references']):affected[q['kind']]+=1
 q['references']=keep
 if keep:rows.append(q)
 else:dropped[q['kind']]+=1
 coverage.append(dict(id=q['id'],kind=q['kind'],referenceCount=len(keep),status='found' if keep else 'removed-no-object-contact-reference'))
bank=OUT/'bank';bank.mkdir()
idx=json.loads((ROOT/'output/defense-no-pocket-20261105/bank/index.json').read_text())
assert idx['fingerprint']==old['sourceFingerprint'];idx.pop('fingerprint')
idx.update(policyVersion='pure-defense-cut60-rails1-total2-no-target-rail-recontact-no-pocket-contact-no-object-contact-v4',counts=dict(inputs=len(old['questions']),questions=len(rows),references=sum(len(q['references']) for q in rows)),shards=[],questions=[],revisionProvenance=dict(sourceSHA256=sha(raw),sourceFingerprint=old['sourceFingerprint'],operation='Reject every reference containing object-object collisions (neither ball is the cue); retained payloads unchanged'))
for kind in ['one','two_black','two_own','three']:
 selected=[q for q in rows if q['kind']==kind]
 for start in range(0,len(selected),100):
  name=f'{kind}-{start//100:04d}';part=selected[start:start+100];data=gzip.compress(b''.join(encoded(q)+b'\n' for q in part),mtime=0);(bank/(name+'.jsonl.gz')).write_bytes(data)
  idx['shards'].append(dict(name=name,sha256=sha(data),bytes=len(data)));idx['questions'] += [dict(id=q['id'],kind=kind,shard=name,line=i) for i,q in enumerate(part)]
idx['fingerprint']=sha(encoded(idx))
for name,value in [('index.json',idx),('coverage.json',coverage)]: (bank/name).write_bytes(encoded(value)+b'\n')
a=audit(bank);(bank/'audit.json').write_bytes(encoded(a)+b'\n')
payload=dict(schema=old['schema'],sourceFingerprint=idx['fingerprint'],questions=rows);stage=OUT/'app-package';stage.mkdir();newraw=gzip.compress(encoded(payload),mtime=0);(stage/src.name).write_bytes(newraw)
newbyid={q['id']:q for q in rows};oldbyid={q['id']:q for q in old['questions']}
for q in rows:
 prev=oldbyid[q['id']];assert {k:v for k,v in q.items() if k!='references'}=={k:v for k,v in prev.items() if k!='references'}
 oldrefs={r['id']:r for r in prev['references']}
 for r in q['references']:assert r==oldrefs[r['id']]
report=dict(beforeQuestions=len(old['questions']),beforeReferences=sum(len(q['references']) for q in old['questions']),questions=len(rows),references=sum(len(q['references']) for q in rows),removedReferences=len(removed),removedQuestions=len(old['questions'])-len(rows),affectedQuestions=dict(affected),removedQuestionsByKind=dict(dropped),counts=dict(collections.Counter(q['kind'] for q in rows)),sourceSHA256=sha(raw),outputSHA256=sha(newraw),sourceFingerprint=idx['fingerprint'],oldSourceFingerprint=old['sourceFingerprint'],freeSHA256=freeSHA,retainedPayloadsUnchanged=True)
for name,value in [('report.json',report),('removed-references.json',removed)]: (OUT/name).write_bytes(encoded(value)+b'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
