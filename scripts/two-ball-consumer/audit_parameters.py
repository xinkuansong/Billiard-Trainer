"""Independent exact source/parameter field, order, reference and SHA audit."""
import json,gzip,hashlib,sys
from pathlib import Path
source,dest,report=map(Path,sys.argv[1:]);s=json.loads((source/'index.json').read_bytes());d=json.loads((dest/'index.json').read_bytes())
assert hashlib.sha256((source/'index.json').read_bytes()).hexdigest()==d['sourceIndexSHA256']
assert d['schema']=='two-ball-consumer-parameters-v1' and d['geometry']==s['geometry']
assert [(e['id'],e['shard'],e['line']) for e in s['layouts']]==[(e['id'],e['shard'],e['line']) for e in d['layouts']]
counts=dict(layouts=0,questions=0,recommendations=0,routes=0)
assert len(s['shards'])==len(d['shards'])
for a,b in zip(s['shards'],d['shards']):
 assert a['name']==b['name']; aa=(source/(a['name']+'.jsonl.gz')).read_bytes();bb=(dest/(b['name']+'.jsonl.gz')).read_bytes()
 for meta,data in [(a,aa),(b,bb)]:assert len(data)==meta['bytes'] and hashlib.sha256(data).hexdigest()==meta['sha256']
 old=list(map(json.loads,gzip.decompress(aa).splitlines()));new=list(map(json.loads,gzip.decompress(bb).splitlines()));assert len(old)==len(new)
 for x,y in zip(old,new):
  assert set(y)=={'id','board','routes','questions'} and x['id']==y['id'] and x['board']==y['board']
  assert len(x['routes'])==len(y['routes']) and len(x['candidates'])==len(y['questions'])
  for r,p in zip(x['routes'],y['routes']):
   assert set(p)=={'id','v','sx','sy','dir','rails'}
   for oldkey,newkey in [('comboIndex','id'),('velocity','v'),('spinX','sx'),('spinY','sy'),('strikeDirection','dir')]:assert r[oldkey]==p[newkey]
   assert p['rails']==[c['cushionID'] for c in r['trajectory2mm']['cushions']]
  for c,q in zip(x['candidates'],y['questions']):
   assert set(q)=={'id','p','refs'} and c['cellID']==q['id'] and c['position']==q['p']
   assert q['refs']==[[t['comboIndex'],t['pocket']] for t in c['top5']]
   counts['recommendations']+=len(q['refs'])
  counts['layouts']+=1;counts['questions']+=len(y['questions']);counts['routes']+=len(y['routes'])
assert counts==d['counts']=={k:s['counts'][k] for k in counts}
assert len(set(e['id'] for e in d['layouts']))==counts['layouts']
report.write_text(json.dumps(dict(state='complete',auditPassed=True,counts=counts,allFieldsExact=True,allReferencesAndOrderExact=True,allSourceAndDestinationSHAPassed=True,sourceIndexSHA256=d['sourceIndexSHA256'],indexSHA256=hashlib.sha256((dest/'index.json').read_bytes()).hexdigest()),indent=2)+'\n');print(report.read_text())
