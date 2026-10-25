from pathlib import Path
import json,gzip,collections,statistics
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-strike-sampled100-20261024'
s=json.loads((OUT/'summary.json').read_text());groups=collections.defaultdict(list);terms=collections.Counter();rows=0;layouts=0;missing=collections.Counter();rawbytes=0;compressed=0
# Fixed, spread-out shard sample, descriptive only, not an unbiased full-bank cost estimate.
indices=[round(i*1356/11) for i in range(12)]
for i in indices:
 p=OUT/'parts'/f'{i:05d}.jsonl.gz';compressed+=p.stat().st_size
 with gzip.open(p,'rt') as f:
  for line in f:
   rawbytes+=len(line.encode());d=json.loads(line);layouts+=1
   for r in d['rows']:
    rows+=1;groups[r['status']].append(r['wallMilliseconds'])
    if r['usableForPositionMatch']:
     terms[r['termination']]+=1
     for key in ['aimOffsetRadians','strikeDirection','spinX','spinY','velocity','events','cueStop']:
      if key not in r:missing[key]+=1
     assert not any(k in r for k in ['recorder','paths','cuePath','comparisonLine'])
     assert all(not any(k in e for k in ['position','x','z']) for e in r['events'])
alltime=sum(map(sum,groups.values()))
report=dict(full=dict(attempts=s['completedAttempts'],valid=s['status']['success'],elapsedSeconds=s['elapsedSeconds'],summedWorkerBatchWallSeconds=s['summedLayoutComputeSeconds'],averageBatchWallMSPerAttempt=s['summedLayoutComputeSeconds']/s['completedAttempts']*1000,throughput=s['completedAttempts']/s['elapsedSeconds'],averageActiveBatchIntervals=s['summedLayoutComputeSeconds']/s['elapsedSeconds']),sample=dict(shards=indices,layouts=layouts,attempts=rows,scope='12 spread-out saved shards; descriptive, not full-bank timing attribution',validTermination=dict(terms),missingReplayFields=dict(missing),rawBytes=rawbytes,gzipBytes=compressed,statuses={k:dict(count=len(v),meanMS=statistics.mean(v),medianMS=statistics.median(v),p95MS=sorted(v)[int(.95*(len(v)-1))],maxMS=max(v),shareOfSampleRowWallTime=sum(v)/alltime) for k,v in groups.items()}))
p=Path(__file__).with_name('timing-inspection.json');p.write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
