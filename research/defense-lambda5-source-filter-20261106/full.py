"""All-source sampled-potential pass. Immutable binary identity, bounded waves,
versioned checkpoints, no trajectory search and no production bank replacement."""
from pathlib import Path
import sqlite3,json,hashlib,gzip,time,sys,math,os,shutil,subprocess
from controller import run_batch,atomic,OUT

def audit(row,expected):
 assert row['id']==expected['id'] and row['target']==expected['target'] and row['blockers']==expected['blockers']
 assert row['kind']==expected['kind'] and row['scoringVersion']=='defense-target-pipe-cut-lambda5-v9'
 score=row['maximumSampled'];assert math.isfinite(score) and -1<=score<=100
 assert row['visited']<=1250 and row['fullEvaluations']+row['pruned']==row['validVisited']
 assert row['reachedGlobalUpperBound']==(row['visited']<1250 and score==100) or row['visited']==1250
 if score<0:assert row['validVisited']==0;return
 effect=row['effect'];assert effect['score']==score and not effect.get('unavailableReason') and not effect.get('failure')
 assert math.dist(row['bestCue'],row['target'])>=.30-1e-8
 if effect.get('fullDirectBlock') or effect.get('potContactsBlocked'):assert score==100
 else:
  route=effect.get('pipeRoute');angle=route['cutDegrees'] if route else 0
  if route:
   t=row['target'];c=row['bestCue'];a=route['aim'];dx,dz=a[0]-t[0],a[1]-t[1];n=math.hypot(dx,dz);ux,uz=dx/n,dz/n
   # Swift Float ball radius has this exact diameter in production.
   import struct
   radius=struct.unpack('f',struct.pack('f',.028575))[0];diameter=struct.unpack('f',struct.pack('f',2*radius))[0]
   vx,vz=t[0]-diameter*ux-c[0],t[1]-diameter*uz-c[1]
   actual=math.degrees(math.atan2(abs(vx*uz-vz*ux),vx*ux+vz*uz))
   assert abs(actual-angle)<1e-8
  expected_score=100*math.sqrt((1-effect['comfort']/100)/(1+5*effect['targetPipeToleranceDegrees']*math.cos(math.radians(angle))**2))
  assert abs(expected_score-score)<1e-7

def main():
 uid,binary=sys.argv[1:3];identity=json.loads((OUT/'run-identity.json').read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 assert sha(binary)==identity['binarySHA256']
 source=sqlite3.connect('file:'+str(OUT/'inputs.sqlite3')+'?mode=ro',uri=True)
 results=sqlite3.connect(OUT/'region-results.sqlite3');results.execute('PRAGMA journal_mode=WAL');results.execute('CREATE TABLE IF NOT EXISTS results(id TEXT PRIMARY KEY, kind TEXT, maximum REAL, estimated INTEGER, payload TEXT)');results.execute('CREATE TABLE IF NOT EXISTS identity(id TEXT PRIMARY KEY)')
 existing=results.execute('SELECT id FROM identity').fetchall()
 if existing:assert existing==[(identity['id'],)]
 else:results.execute('INSERT INTO identity VALUES(?)',(identity['id'],));results.commit()
 done={r[0] for r in results.execute('SELECT id FROM results')};initial=len(done)
 total=source.execute('SELECT COUNT(*) FROM maps').fetchone()[0];cursor=source.execute('SELECT id,target,blockers,kind FROM maps ORDER BY id')
 start=time.time();wave=0;archives=OUT/'full-archives';archives.mkdir(exist_ok=True)
 subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  while True:
   rows=cursor.fetchmany(2048)
   if not rows:break
   inputs=[dict(id=r[0],target=json.loads(r[1]),blockers=json.loads(r[2]),kind=r[3]) for r in rows if r[0] not in done]
   wave+=1
   if not inputs:continue
   if shutil.disk_usage(OUT).free<8*1024**3:raise RuntimeError('Under 8GiB available; checkpoints preserved')
   name=f'full-wave-{wave:05d}';begin=time.time();values=run_batch(name,inputs,uid,binary)
   lookup={q['id']:q for q in inputs}
   for r in values:audit(r,lookup[r['id']])
   raw=json.dumps(dict(identity=identity['id'],rows=values),separators=(',',':')).encode()
   path=archives/(name+'.json.gz');tmp=path.with_suffix('.tmp');tmp.write_bytes(gzip.compress(raw,compresslevel=6,mtime=0));assert gzip.decompress(tmp.read_bytes())==raw;tmp.replace(path)
   for r in values:results.execute('INSERT INTO results VALUES(?,?,?,?,?)',(r['id'],r['kind'],r['maximumSampled'],int(r.get('estimatedMaximum',False)),json.dumps(r,separators=(',',':'))));done.add(r['id'])
   results.commit()
   elapsed=time.time()-start;rate=(len(done)-initial)/elapsed
   counts=[dict(kind=k,threshold=t,all=a,confirmed=c) for t in [70,75,80,85,90,95] for k,a,c in results.execute('SELECT kind,COUNT(*),SUM(estimated=0) FROM results WHERE maximum>=? GROUP BY kind',(t,))]
   atomic(OUT/'status.json',dict(state='running',stage='source-region-potential',identity=identity['id'],completedMaps=len(done),totalMaps=total,newMaps=len(done)-initial,elapsedSeconds=elapsed,mapsPerSecond=rate,estimatedRemainingSeconds=(total-len(done))/rate,updatedAt=time.time(),lastWave=name,lastWaveSeconds=time.time()-begin,bands=counts,trajectorySearchStarted=False))
   print('FILTER',len(done),'/',total,'maps',round(rate,2),'maps/s',flush=True)
   # Each raw file is retained verbatim in the checked archive before reclamation.
   for worker in (OUT/name).glob('worker-*'):
    for p in (worker/'results').glob('*.json'):p.unlink()
    (worker/'results').rmdir()
   atomic(OUT/name/'archive.json',dict(file=str(path),sha256=sha(path),rows=len(values)))
  assert len(done)==total
  results.execute("ATTACH DATABASE ? AS inputs",(str(OUT/'inputs.sqlite3'),))
  counts=[]
  for t in [70,75,80,85,90,95]:
   for k,n,c in results.execute('SELECT a.kind,COUNT(*),SUM(r.estimated=0) FROM inputs.roles a JOIN results r ON a.map=r.id WHERE r.maximum>=? GROUP BY a.kind',(t,)):
    counts.append(dict(kind=k,threshold=t,all=n,confirmed=c))
  totalRoles=results.execute('SELECT COUNT(*) FROM inputs.roles a JOIN results r ON a.map=r.id').fetchone()[0]
  assert totalRoles==1331922
  atomic(OUT/'summary.json',dict(complete=True,identity=identity['id'],maps=total,roles=totalRoles,roleBands=counts,scope='Exact maximum over valid 50x25 sample centres; no continuous or reachability guarantee. Below-band roles remain candidates for dynamic own-ball blocking; no trajectory generation or production replacement.'))
  atomic(OUT/'status.json',dict(state='complete',stage='source-region-potential',completedMaps=total,totalMaps=total,roles=totalRoles,trajectorySearchStarted=False))
 finally:
  results.close();source.close();subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
