"""Read-only parameter-bank prototype; no production resource writes."""
from pathlib import Path
import json,gzip,hashlib,random,time,heapq,collections
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'QiuJi/Resources/TwoBallBank';OUT=ROOT/'output/two-ball-parameter-bank-20261026';BANK=OUT/'ParameterBank'
def enc(x):return json.dumps(x,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
def sha(b):return hashlib.sha256(b).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def main():
 start=time.monotonic();assert not BANK.exists();BANK.mkdir()
 raw=(SOURCE/'index.json').read_bytes();index=json.loads(raw);counts=collections.Counter();entries=[];shards=[];randoms=[];diagnostic={};rank=0
 # Fixed hash bottom-128 questions, plus deterministic extremes; not selected by replay success.
 for n,part in enumerate(index['shards']):
  b=(SOURCE/(part['name']+'.jsonl.gz')).read_bytes();assert sha(b)==part['sha256'] and len(b)==part['bytes'];rows=[json.loads(l) for l in gzip.decompress(b).splitlines()];out=[]
  for row in rows:
   compact={'id':row['id'],'board':row['board'],'routes':[{'id':r['comboIndex'],'v':r['velocity'],'sx':r['spinX'],'sy':r['spinY'],'dir':r['strikeDirection'],'rails':[c['cushionID'] for c in r['trajectory2mm']['cushions']]} for r in row['routes']], 'questions':[{'id':c['cellID'],'p':c['position'],'refs':[[t['comboIndex'],t['pocket']] for t in c['top5']]} for c in row['candidates']]}
   entries.append({'id':row['id'],'shard':part['name'],'line':len(out)});out.append(compact)
   counts['layouts']+=1;counts['questions']+=len(compact['questions']);counts['routes']+=len(compact['routes']);counts['recommendations']+=sum(len(q['refs']) for q in compact['questions'])
   routes={r['comboIndex']:r for r in row['routes']};cs={r['id']:r for r in compact['routes']}
   for q,c in zip(compact['questions'],row['candidates']):
    key=f"{row['id']}#{q['id']}";priority=int(sha(('param-replay-20261026:'+key).encode()),16)
    item={'key':key,'shard':part['name'],'layoutID':row['id'],'cellID':q['id']}
    if len(randoms)<128:heapq.heappush(randoms,(-priority,key,item))
    elif priority < -randoms[0][0]:heapq.heapreplace(randoms,(-priority,key,item))
    for t in c['top5']:
     r=routes[t['comboIndex']];cf=t['comfort'];metrics={'longestPath':r['executionDifficulty']['lengthMeters'],'mostRails':r['cueMainRailsAfterContact'],'largestSide':abs(r['spinX']),'strongestDraw':-r['spinY'],'strongestFollow':r['spinY'],'fastest':r['velocity'],'slowest':-r['velocity'],'closestRail':-cf['gapMeters'],'closest85':-cf['totalScore'],'largestCut':cf['angleDegrees']}
     for cat,val in metrics.items():
      if cat not in diagnostic or val>diagnostic[cat][0]:diagnostic[cat]=(val,item)
     for cat,ok in [('zeroRail',r['cueMainRailsAfterContact']==0),('middlePocket',t['pocket'] in (4,5)),('cornerPocket',t['pocket']<4),('optimized',t['refinementStatus']=='optimizedQualified')]:
      if ok and (cat not in diagnostic or priority<diagnostic[cat][0]):diagnostic[cat]=(priority,item)
  payload=gzip.compress(b''.join(enc(r)+b'\n' for r in out),compresslevel=9,mtime=0);(BANK/(part['name']+'.jsonl.gz')).write_bytes(payload);shards.append({'name':part['name'],'bytes':len(payload),'sha256':sha(payload)})
  if n%250==0:print('pack',n,flush=True)
 idx={'schema':'two-ball-parameters-prototype-v1','prototypeOnly':True,'sourceIndexSHA256':sha(raw),'sourcePolicyVersion':index['policyVersion'],'physicsModel':'planarReference','coordinates':'meter-XZ; Y up; source doubles preserved, native Float conversion unchanged','routeFields':{'id':'layout-local comboIndex','v':'m/s','sx':'side tip','sy':'vertical tip','dir':'saved strike direction XZ','rails':'ordered post-contact main cushion IDs'},'questionFields':{'id':'original cellID','p':'B position XZ','refs':'ordered [routeID,secondPocket] pairs; preserve approved ascending order'},'geometry':index['geometry'],'counts':dict(counts),'shards':shards,'layouts':entries}
 (BANK/'index.json').write_bytes(enc(idx));assert all(counts[k]==index['counts'][k] for k in counts)
 sample={x[2]['key']:{**x[2],'cohorts':['random128']} for x in randoms}
 for cat,(_,item) in diagnostic.items():sample.setdefault(item['key'],{**item,'cohorts':[]})['cohorts'].append(cat)
 # Reference-only audit data separate from the parameter package and simulator input.
 cases=[];loaded={}
 for item in sorted(sample.values(),key=lambda x:x['key']):
  name=item['shard'];rr=loaded.setdefault(name,None)
  if rr is None:rr=[json.loads(l) for l in gzip.decompress((SOURCE/(name+'.jsonl.gz')).read_bytes()).splitlines()];loaded[name]=rr
  row=next(r for r in rr if r['id']==item['layoutID']);c=next(c for c in row['candidates'] if c['cellID']==item['cellID']);ids={t['comboIndex'] for t in c['top5']};cases.append({**item,'board':row['board'],'candidate':c,'routes':[r for r in row['routes'] if r['comboIndex'] in ids]})
 write(OUT/'reference-cases.json',cases);write(OUT/'pack.json',{'state':'packed-needs-audit',**dict(counts),'shards':len(shards),'gzipBytes':sum(p['bytes'] for p in shards),'indexBytes':(BANK/'index.json').stat().st_size,'totalBytes':sum(p['bytes'] for p in shards)+(BANK/'index.json').stat().st_size,'sourceTotalBytes':sum(s['bytes'] for s in index['shards'])+len(raw),'sourceIndexSHA256':sha(raw),'benchmarkQuestions':len(cases),'benchmarkRecommendations':sum(len(c['candidate']['top5']) for c in cases),'seconds':time.monotonic()-start})
 print((OUT/'pack.json').read_text())
if __name__=='__main__':main()
