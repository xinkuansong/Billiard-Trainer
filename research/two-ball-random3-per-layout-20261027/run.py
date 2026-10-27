"""Create a standalone research subset: at most three existing B positions/layout."""
from pathlib import Path
import collections, gzip, hashlib, json, random, time
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'QiuJi/Resources/TwoBallBank'
OUT=ROOT/'output'/Path(__file__).resolve().parent.name
SEED='two-ball-second-position-max3-20261027-v1'
def digest(b):return hashlib.sha256(b).hexdigest()
def encode(v):return json.dumps(v,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
def draw(layout_id,ids):
 seed=int.from_bytes(hashlib.sha256((SEED+'\0'+layout_id).encode()).digest(),'big')
 return sorted(random.Random(seed).sample(sorted(ids),min(3,len(ids))))
def main():
 started=time.monotonic();OUT.mkdir(parents=True,exist_ok=True)
 raw_index=(SOURCE/'index.json').read_bytes();index=json.loads(raw_index)
 expected={e['id']:(e['shard'],e['line']) for e in index['layouts']}
 seen=set();hist=collections.Counter();retained_hist=collections.Counter();counts=collections.Counter();selections=[];row_hashes={};inputs={}
 with (OUT/'selected-bank.jsonl.gz').open('wb') as raw_out, gzip.GzipFile(filename='',mode='wb',fileobj=raw_out,mtime=0,compresslevel=6) as out:
  for shard in index['shards']:
   name=shard['name'];raw=(SOURCE/(name+'.jsonl.gz')).read_bytes()
   assert len(raw)==shard['bytes'] and digest(raw)==shard['sha256'],name
   inputs[name]=digest(raw)
   for line,rawrow in enumerate(gzip.decompress(raw).splitlines()):
    row=json.loads(rawrow);lid=row['id'];qs=row['questions'];routes=row['routes'];ids=[q['id'] for q in qs]
    assert lid not in seen and expected[lid]==(name,line)
    assert len(set(ids))==len(ids) and len({tuple(q['p']) for q in qs})==len(qs) and qs
    seen.add(lid);hist[len(qs)]+=1
    chosen=draw(lid,ids);wanted=set(chosen);questions=[q for q in qs if q['id'] in wanted]
    route_ids={ref[0] for q in questions for ref in q['refs']}
    kept_routes=[r for r in routes if r['id'] in route_ids]
    assert route_ids=={r['id'] for r in kept_routes}
    assert all(q['refs'] for q in questions)
    subset=dict(row,questions=questions,routes=kept_routes)
    out.write(encode(subset)+b'\n');row_hashes[lid]=digest(encode(subset))
    retained_hist[len(questions)]+=1
    counts.update(layouts=1,sourceQuestions=len(qs),sourceRoutes=len(routes),sourceRecommendations=sum(len(q['refs']) for q in qs),questions=len(questions),routes=len(kept_routes),recommendations=sum(len(q['refs']) for q in questions))
    selections.append(dict(id=lid,sourceShard=name,sourceLine=line,sourceCount=len(qs),selectedCellIDs=chosen))
 assert len(seen)==len(expected)==index['counts']['layouts']
 assert counts['sourceQuestions']==index['counts']['questions']
 assert counts['sourceRoutes']==index['counts']['routes']
 assert counts['sourceRecommendations']==index['counts']['recommendations']
 # Read output back against complete expected rows; verify every retained reference.
 reread=set();verified=collections.Counter()
 with gzip.open(OUT/'selected-bank.jsonl.gz','rt') as f:
  for line in f:
   row=json.loads(line);lid=row['id'];assert lid not in reread;reread.add(lid)
   assert digest(encode(row))==row_hashes[lid]
   qs=row['questions'];assert 1<=len(qs)<=3
   byid={r['id']:r for r in row['routes']}
   assert all(ref[0] in byid and 0<=ref[1]<6 for q in qs for ref in q['refs'])
   verified.update(layouts=1,questions=len(qs),routes=len(byid),recommendations=sum(len(q['refs']) for q in qs))
 assert reread==seen and all(verified[k]==counts[k] for k in verified)
 assert counts['questions']==sum(min(3,n)*c for n,c in hist.items())
 # Independent full parent pass: exact B/board/route preservation and draw reproducibility.
 selected_by_id={s['id']:s for s in selections}
 for shard in index['shards']:
  raw=(SOURCE/(shard['name']+'.jsonl.gz')).read_bytes();assert digest(raw)==inputs[shard['name']]
  for rawrow in gzip.decompress(raw).splitlines():
   row=json.loads(rawrow);s=selected_by_id[row['id']];chosen=s['selectedCellIDs'];qs=row['questions']
   assert chosen==draw(row['id'],list(reversed([q['id'] for q in qs])))
   if len(qs)<=3:assert set(chosen)=={q['id'] for q in qs}
   take=[q for q in qs if q['id'] in chosen]
   refs={ref[0] for q in take for ref in q['refs']}
   reconstructed=dict(row,questions=take,routes=[r for r in row['routes'] if r['id'] in refs])
   assert digest(encode(reconstructed))==row_hashes[row['id']]
 assert (SOURCE/'index.json').read_bytes()==raw_index
 def write(name,v):(OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
 write('selection.json',dict(seed=SEED,layouts=selections))
 summary=dict(status='complete',auditPassed=True,seed=SEED,counts=dict(counts),sourceQuestionCountHistogram=dict(sorted(hist.items())),retainedQuestionCountHistogram=dict(sorted(retained_hist.items())),retainedPercent=100*counts['questions']/counts['sourceQuestions'],elapsedSeconds=time.monotonic()-started,thirdBallGenerationStarted=False,productionMutation=False)
 write('summary.json',summary)
 write('manifest.json',dict(schema='two-ball-research-random3-v1',sourcePath=str(SOURCE),sourceIndexSHA256=digest(raw_index),sourceFingerprint=index['fingerprint'],sourceMetadata={k:v for k,v in index.items() if k not in ['layouts','shards']},sourceShardSHA256=inputs,seed=SEED,selection='per layout uniform B-position sampling without replacement, max3; all existing refs retained; unused routes removed',files={n:digest((OUT/n).read_bytes()) for n in ['selected-bank.jsonl.gz','selection.json','summary.json']}))
 write('audit.json',dict(passed=True,allSourceShardHashesMatched=True,allIndexedLayoutsCoveredOnce=True,uniqueBPositions=True,maxThreeAndUnderThreeAllRetained=True,allOutputRowsReadBack=True,allQuestionBoardRouteFieldsPreserved=True,allRouteReferencesResolve=True,sourceUnchanged=True,reproducibleWithReversedInput=True,counts=dict(verified),physicsRerun=False))
 print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
