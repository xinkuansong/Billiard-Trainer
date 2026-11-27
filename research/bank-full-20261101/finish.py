from pathlib import Path
import json,gzip,hashlib,collections,copy,sys,math
import audit
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-full-20261101'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def identity(r):
 keys=[]
 for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)]:
  c=[r['cue'][0]*sx,r['cue'][1]*sz];o=[r['target'][0]*sx,r['target'][1]*sz]
  pk=g['pockets'][r['pocket']]['center'];pp=[pk[0]*sx,pk[1]*sz]
  pocket=min(range(6),key=lambda p:math.dist(g['pockets'][p]['center'],pp))
  walls=[1-w if w<2 and sx<0 else 5-w if w>=2 and sz<0 else w for w in r['walls']]
  keys.append((tuple(x.hex() for x in c+o),pocket,tuple(walls)))
 return min(keys)
g=json.loads((OUT/'geometry.json').read_text());tree={r['id']:r for r in json.loads((OUT/'route-tree.json').read_text())};binding=json.loads((OUT/'generation-identity.json').read_text())
assert all(sha(OUT/k)==v for k,v in binding.items())
seen=set();ids=[];duplicates=[];counts=collections.Counter();hist=collections.Counter();funnel=collections.Counter();receipts=[];sample=[];negatives=[];ranges=collections.defaultdict(list)
for i,route in enumerate(tree.values()):
 p=OUT/'routes'/f'{i:03d}.json.gz';receipt=json.loads((OUT/'routes'/f'{i:03d}.receipt.json').read_text())
 assert receipt['sha256']==sha(p) and receipt['identity']==binding and receipt['routeID']==route['id']
 with gzip.open(p,'rt') as f:packet=json.load(f)
 rows=packet['rows'];audit.check(rows,g,packet['verification'],tree,packet['summary']);receipts.append(receipt)
 for point in packet['summary']['targets']:hist[point['kept']]+=1;funnel.update(point['counts'])
 if rows and not negatives:
  for name in ['wrong-count','wrong-route','easy-direct','fake-score','wrong-quota']:
   bad=copy.deepcopy(rows);summary=copy.deepcopy(packet['summary'])
   if name=='wrong-count':bad[0]['n']=9
   elif name=='wrong-route':bad[0]['parentRouteID']='bad'
   elif name=='easy-direct':bad[0]['bestDirect']['cut']=44
   elif name=='fake-score':bad[0]['bankComfort']['total']+=1
   else:summary['targets'][0]['counts']['sampled']=127
   try:audit.check(bad,g,packet['verification'],tree,summary)
   except AssertionError:negatives.append(name)
   else:raise AssertionError('negative accepted '+name)
 for r in rows:
  key=identity(r)
  if key in seen:duplicates.append(r['id']);continue
  seen.add(key);ids.append(r['id']);counts[f"{r['n']}-{r['type']}"]+=1
  for k in ['cueTargetDistance','space','cut']:ranges[k].append(r['bankComfort'][k])
  if r['type']=='middle':ranges['middleEntry'].append(r['entryAngleMin'])
  group=(r['n'],r['type'],r['distanceBand'])
  # Representative review set, max 2 per cushion/pocket/distance group (36 total).
  if sum((x['n'],x['type'],x['distanceBand'])==group for x in sample)<2:sample.append(r)
assert len(receipts)==len(tree) and sum(hist.values())==len(tree)*12
assert funnel['sampled']==len(tree)*12*128
nativeCount=sum(r['selected'] for r in receipts)
manifest={'state':'complete','workers':8,'routes':len(tree),'routeCounts':dict(collections.Counter(len(r['reverseWalls']) for r in tree.values())),'selectedBeforeDedup':nativeCount,'selected':len(ids),'counts':dict(counts),'retainedIDs':ids,'duplicateIDs':duplicates,'dedup':'exact canonical ball coordinates + pocket + rail sequence under four axis reflections; no near-duplicate threshold','targetKeptHistogram':dict(hist),'funnel':dict(funnel),'physicalReplays':2*nativeCount,'independentAudit':True,'negativeCasesRejected':negatives,'ranges':{k:[min(v),max(v)] for k,v in ranges.items()},'identity':binding,'lowerCushionAlternativesChecked':False,'perturbationChecked':False}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(OUT/'review-sample.json').write_text(json.dumps(sample,separators=(',',':')))
status=json.loads((OUT/'status.json').read_text());status.update(state='complete',selected=len(ids),auditPassed=True);(OUT/'status.json').write_text(json.dumps(status,indent=2))
print('COMPLETE',json.dumps({k:v for k,v in manifest.items() if k not in ['retainedIDs','identity','duplicateIDs']},ensure_ascii=False))
