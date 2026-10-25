from pathlib import Path
import gzip,json,hashlib,time,collections
R=Path(__file__).resolve().parents[2];S=R/'QiuJi/Resources/TwoBallBank';O=R/'output/two-ball-parameter-bank-20261026';D=O/'ParameterBank'
def load(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [json.loads(l) for l in gzip.decompress(p.read_bytes()).splitlines()]
def main():
 start=time.monotonic();idx=load(D/'index.json');orig=load(S/'index.json');assert idx['sourceIndexSHA256']==sha(S/'index.json');stats=collections.Counter();seen=set();entries=[]
 for sh,oldsh in zip(idx['shards'],orig['shards'],strict=True):
  assert sh['name']==oldsh['name'];p=D/(sh['name']+'.jsonl.gz');s=S/p.name;assert sha(p)==sh['sha256'] and p.stat().st_size==sh['bytes'];assert sha(s)==oldsh['sha256'];dr,sr=rows(p),rows(s);assert len(dr)==len(sr)
  for line,(a,b) in enumerate(zip(dr,sr)):
   assert set(a)=={'id','board','routes','questions'};assert a['id']==b['id'] and a['id'] not in seen;seen.add(a['id']);assert a['board']==b['board'];entries.append(dict(id=a['id'],shard=sh['name'],line=line));oldroutes={r['comboIndex']:r for r in b['routes']};newroutes={r['id']:r for r in a['routes']};assert set(oldroutes)==set(newroutes)
   for rid,r in newroutes.items():
    z=oldroutes[rid];assert set(r)=={'id','v','sx','sy','dir','rails'};assert (r['v'],r['sx'],r['sy'],r['dir'])==(z['velocity'],z['spinX'],z['spinY'],z['strikeDirection']);assert r['rails']==[e['cushionID'] for e in z['trajectory2mm']['cushions']]
   assert len(a['questions'])==len(b['candidates'])
   for q,c in zip(a['questions'],b['candidates']):
    assert set(q)=={'id','p','refs'} and q['id']==c['cellID'] and q['p']==c['position'];assert q['refs']==[[t['comboIndex'],t['pocket']] for t in c['top5']];assert 1<=len(q['refs'])<=5
    assert all(t['comfort']['totalScore']>=85 for t in c['top5']);assert all(x[0] in newroutes for x in q['refs']);stats['recommendations']+=len(q['refs']);stats['questions']+=1
   stats['layouts']+=1;stats['routes']+=len(newroutes)
 assert entries==idx['layouts'] and dict(stats)==idx['counts'];assert all(stats[k]==orig['counts'][k] for k in stats)
 result=dict(state='complete',auditPassed=True,counts=dict(stats),allParametersExact=True,allQuestionMembershipAndOrderExact=True,noTrajectoryOrScoreFields=True,allSourceAndPrototypeSHA256Passed=True,sourceIndexSHA256=sha(S/'index.json'),prototypeIndexSHA256=sha(D/'index.json'),seconds=time.monotonic()-start);(O/'audit.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
if __name__=='__main__':main()
