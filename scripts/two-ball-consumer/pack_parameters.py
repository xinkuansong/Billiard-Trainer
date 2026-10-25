"""Build production parameters from the audited comfort85/execution full bank.
Usage: pack_parameters.py SOURCE DESTINATION REPORT (new destination only).
"""
import json,gzip,hashlib,sys
from pathlib import Path

def enc(x): return json.dumps(x,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
def sha(b): return hashlib.sha256(b).hexdigest()
def main():
 source,dest,report=map(Path,sys.argv[1:]); raw=(source/'index.json').read_bytes(); idx=json.loads(raw)
 assert idx['schema']=='two-ball-consumer-v2' and idx['policyVersion']=='comfort85-execution-v1'
 dest.mkdir(parents=True,exist_ok=False); shards=[];entries=[];counts=dict(layouts=0,questions=0,routes=0,recommendations=0)
 for part in idx['shards']:
  data=(source/(part['name']+'.jsonl.gz')).read_bytes();assert sha(data)==part['sha256'] and len(data)==part['bytes']
  rows=[]
  for line in gzip.decompress(data).splitlines():
   r=json.loads(line); lookup={x['comboIndex']:x for x in r['routes']}
   for c in r['candidates']:
    assert 0<len(c['top5'])<=5 and all(t['comfort']['totalScore']>=85 for t in c['top5'])
    keys=[(lookup[t['comboIndex']]['executionDifficulty']['effort'],t['sourceRecommendationRank']) for t in c['top5']];assert keys==sorted(keys)
   rows.append(dict(id=r['id'],board=r['board'],routes=[dict(id=x['comboIndex'],v=x['velocity'],sx=x['spinX'],sy=x['spinY'],dir=x['strikeDirection'],rails=[c['cushionID'] for c in x['trajectory2mm']['cushions']]) for x in r['routes']],questions=[dict(id=c['cellID'],p=c['position'],refs=[[t['comboIndex'],t['pocket']] for t in c['top5']]) for c in r['candidates']]))
   entries.append(dict(id=r['id'],shard=part['name'],line=len(rows)-1))
   counts['layouts']+=1;counts['questions']+=len(r['candidates']);counts['routes']+=len(r['routes']);counts['recommendations']+=sum(len(c['top5']) for c in r['candidates'])
  b=gzip.compress(b''.join(enc(r)+b'\n' for r in rows),compresslevel=9,mtime=0);(dest/(part['name']+'.jsonl.gz')).write_bytes(b);shards.append(dict(name=part['name'],sha256=sha(b),bytes=len(b)))
 assert counts=={k:idx['counts'][k] for k in counts}
 result=dict(schema='two-ball-consumer-parameters-v1',policyVersion='comfort85-parameters-v1',sourceIndexSHA256=sha(raw),physicsModel='planarReference',replayVersion='event-order-rdp2mm-v1',comfortVersion='comfort-d2-s3-a2-v1',executionVersion='execution-effort-v1',minimumComfort=85,geometry=idx['geometry'],counts=counts,shards=shards,layouts=entries)
 result['fingerprint']=sha(enc(result));b=enc(result);(dest/'index.json').write_bytes(b)
 report.write_text(json.dumps(dict(state='packed-needs-independent-audit',counts=counts,indexSHA256=sha(b),indexBytes=len(b),gzipBytes=sum(s['bytes'] for s in shards),totalBytes=len(b)+sum(s['bytes'] for s in shards)),indent=2)+'\n')
if __name__=='__main__':main()
