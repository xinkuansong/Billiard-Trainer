"""Export checked research references into parameter-only defense bank v1."""
from pathlib import Path
import argparse, collections, gzip, hashlib, json, math, struct

SCHEMA='defense-parameters-v1'
POLICY='pure-defense-cut60-rails1-total2-no-pocket-contact-no-object-contact-v4'
KINDS=('one','two_black','two_own','three')
def encoded(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads(gzip.decompress(p.read_bytes()) if p.suffix=='.gz' else p.read_bytes())
def write(p,x):p.write_bytes(encoded(x)+b'\n')
def number(key):return 0 if key=='cueBall' else int(key.removeprefix('_'))
def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
def validate_reference(q,r):
 assert not r['cornerWitnesses']
 assert r['metrics']['fullBlock'] or 1e-6<r['cueWidth']<=.008 and r['comfort']<10
 fc=r['firstContact'];assert 0<=fc['cutDegrees']<=60
 c=list(map(f32,q['cue']));t=list(map(f32,q['positions'][q['own']]))
 u=r['shot']['direction'];n=math.hypot(*u);u=[v/n for v in u]
 ratio=abs((t[0]-c[0])*u[1]-(t[1]-c[1])*u[0])/(2*f32(.028575))
 assert abs(math.degrees(math.asin(ratio))-fc['cutDegrees'])<1e-8
 events=r['events'];i=next(i for i,e in enumerate(events) if e['kind']=='ballBall')
 assert all(e.get('index') in range(6) for e in events if e['kind']=='cushion'),'pocket-contact'
 assert all('cueBall' in e['balls'] for e in events if e['kind']=='ballBall'),'object-object-contact'
 own='_'+str(q['numbers'][q['own']]);assert set(events[i]['balls'])=={'cueBall',own}
 assert not any(e['kind']=='cushion' for e in events[:i])
 assert any(e['kind'] in ('cushion','pocket') for e in events[i+1:])
 assert not set(r['pocketed']) & {'cueBall',own,'_8'}
 banks=collections.Counter(e['ball'] for e in events if e['kind']=='cushion' and e['index'] in range(6))
 assert sum(banks.values())<=2 and all(v<=1 for v in banks.values())
 assert dict(banks)==r['execution']['mainCushionsByBall']
 assert sum(banks.values())==r['execution']['mainCushionCount']
 return banks

def question(d):
 q=d['input'];refs=[]
 for r in d['references']:
  banks=validate_reference(q,r);s=r['shot'];parameters=dict(direction=s['direction'],velocity=s['speed'],spinX=s['spinX'],spinY=s['spinY'])
  events=[]
  for e in r['events']:
   v=dict(kind=e['kind'],timeSeconds=e['time'],ballNumbers=[number(k) for k in e['balls']] if e['kind']=='ballBall' else [number(e['ball'])])
   if e['kind']=='cushion':v['railIndex']=e['index']
   if e['kind']=='pocket':v['pocketIndex']=e['pocket']
   events.append(v)
  probes=[dict(angleDeltaDegrees=p['angleDeltaDegrees'],speedScale=p['speedScale'],status=p['status'],qualifies=p.get('qualifies',False),tactics=p.get('tactics',[])) for p in r['perturbations']]
  refs.append(dict(id=sha(encoded(parameters)),parameters=parameters,tactics=r['tactics'],
   effect=dict(fullDirectBlock=bool(r['metrics']['fullBlock']),score=100 if r['metrics']['fullBlock'] else None,opponentBallNumber=number(r['opponentKey']),cueToleranceDegrees=r['cueWidth'],comfort=r['comfort']),
   execution=dict(firstContactCutDegrees=r['firstContact']['cutDegrees'],projectedThicknessFraction=r['firstContact']['projectedThicknessFraction'],mainCushionCount=sum(banks.values()),mainCushionsByBall={str(number(k)):v for k,v in banks.items()},totalTravelMeters=r['execution']['totalTravelMeters']),
   selectionProbes=probes,expected=dict(finalBalls=[dict(number=number(k),position=v) for k,v in sorted(r['finalPositions'].items())],pocketedBallNumbers=sorted(number(k) for k in r['pocketed']),events=events)))
 refs.sort(key=lambda r:(-sum(p['qualifies'] for p in r['selectionProbes']),-r['effect']['fullDirectBlock'],r['execution']['totalTravelMeters'],r['id']))
 assert len({r['id'] for r in refs})==len(refs)
 return dict(id=q['kind']+':'+q['formationID'],sourceFormationID=q['formationID'],sampleID=q['sampleID'],kind=q['kind'],cue=q['cue'],balls=[dict(number=n,position=p) for n,p in zip(q['numbers'],q['positions'])],ownBallNumber=q['numbers'][q['own']],opponentBallNumber=q['numbers'][q['enemy']],references=refs)

def audit(root,originals=None):
 idx=read(root/'index.json');assert idx['schema']==SCHEMA
 payload=dict(idx);fingerprint=payload.pop('fingerprint');assert sha(encoded(payload))==fingerprint
 rows={};refs=0
 for shard in idx['shards']:
  b=(root/(shard['name']+'.jsonl.gz')).read_bytes();assert sha(b)==shard['sha256'] and len(b)==shard['bytes']
  lines=[json.loads(line) for line in gzip.decompress(b).splitlines()]
  for line,row in enumerate(lines):
   assert row['id'] not in rows;rows[row['id']]=(shard['name'],line,row);refs+=len(row['references'])
   assert row['references'];assert len({b['number'] for b in row['balls']})==len(row['balls'])
   assert row['ownBallNumber'] in [b['number'] for b in row['balls']]
   for r in row['references']:
    if 'no-object-contact' in idx.get('policyVersion',''):
     assert all(0 in e['ballNumbers'] for e in r['expected']['events'] if e['kind']=='ballBall'),'object-object-contact'
    if 'no-pocket-contact' in idx.get('policyVersion',''):
     assert all(e.get('railIndex') in range(6) for e in r['expected']['events'] if e['kind']=='cushion'),'pocket-contact'
    assert sha(encoded(r['parameters']))==r['id']
    assert 'paths' not in r and 0<=r['execution']['firstContactCutDegrees']<=60
    assert r['execution']['mainCushionCount']<=2
 for entry in idx['questions']:
  name,line,row=rows[entry['id']];assert entry['shard']==name and entry['line']==line
  if originals is not None:assert row==question(originals[row['sampleID']])
 assert len(rows)==len(idx['questions'])==idx['counts']['questions'] and refs==idx['counts']['references']
 return dict(passed=True,questions=len(rows),references=refs,fingerprint=fingerprint,bytes=sum(p.stat().st_size for p in root.iterdir() if p.is_file()))

def pack(source,out):
 samples=read(source/'samples.json');out.mkdir(parents=True,exist_ok=True)
 assert not (out/'index.json').exists(),'Use a new output directory; published banks are immutable'
 originals={};rows=[];status=[];source_hashes={}
 for q in samples:
  p=source/'questions'/(q['sampleID']+'.json')
  if not p.exists():p=p.with_suffix('.json.gz')
  d=read(p);assert d['input']==q;originals[q['sampleID']]=d;source_hashes[q['sampleID']]=sha(p.read_bytes())
  row=question(d)
  status.append(dict(id=row['id'],sampleID=q['sampleID'],kind=q['kind'],status='found' if row['references'] else 'inaccessible' if d['summary']['candidateCount']==0 else 'not-found',referenceCount=len(row['references'])))
  if row['references']:rows.append(row)
 idx=dict(schema=SCHEMA,policyVersion=POLICY,physicsModel='planarReference',assessmentVersion='clean-cue-window-and-comfort-with-pocket-quarantine-v1',coordinateSystem='scenekit-xz-metres-y-up',geometry=dict(length=2.54,width=1.27,radius=.028575),sourceFingerprints={n:sha((source/n).read_bytes()) for n in ('samples.json','source-manifest.json','asset-manifest.json','research-sources.json','solve-policy.json')},counts=dict(inputs=len(samples),questions=len(rows),references=sum(len(q['references']) for q in rows)),shards=[],questions=[])
 for kind in KINDS:
  selected=[r for r in rows if r['kind']==kind]
  for start in range(0,len(selected),100):
   name=f'{kind}-{start//100:04d}';part=selected[start:start+100];b=gzip.compress(b''.join(encoded(r)+b'\n' for r in part),mtime=0)
   (out/(name+'.jsonl.gz')).write_bytes(b);idx['shards'].append(dict(name=name,sha256=sha(b),bytes=len(b)))
   idx['questions'] += [dict(id=r['id'],kind=kind,shard=name,line=i) for i,r in enumerate(part)]
 idx['fingerprint']=sha(encoded(idx));write(out/'index.json',idx)
 write(out/'coverage.json',status);write(out/'source-record-sha256.json',source_hashes)
 for n in ('source-manifest.json','asset-manifest.json','research-sources.json','solve-policy.json'):(out/n).write_bytes((source/n).read_bytes())
 write(out/'example-question.json',rows[0]);result=audit(out,originals);write(out/'audit.json',result);print(json.dumps(result))

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('source',type=Path);ap.add_argument('out',type=Path);a=ap.parse_args();pack(a.source,a.out)
