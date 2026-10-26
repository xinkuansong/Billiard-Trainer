from pathlib import Path
import json,gzip,math,hashlib,statistics
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-contact-factorial-20261026'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protocol=json.loads((OUT/'protocol.json').read_text());analysis=json.loads((OUT/'analysis.json').read_text());derived=json.loads((OUT/'derived.json').read_text());lookup={(r['rackID'],r['key']):r for r in derived};rows={};n=0;maxEnergyError=0;maxGapError=0;firstSurface=1e10
cal=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text());L=cal['domain']['length'];R=cal['domain']['radius']
for path in OUT.glob('raw-*.jsonl.gz'):
 with gzip.open(path,'rt') as f:
  for line in f:
   r=json.loads(line);i=r['input'];key=f"{i['contactEpsilon']*1e6:g}um_{i['tieEpsilon']:g}_{'reverse' if i['reverseRegistration'] else 'forward'}";d=lookup[i['rackID'],key];rows[i['rackID'],key]=r;n+=1
   q=[v for name,v in r['board'].items() if name!='cueBall'];score=statistics.mean(min(math.dist(a,b)*L for j,b in enumerate(q) if k!=j) for k,a in enumerate(q))/cal['reference'][str(len(q))]['expectedMeanM'];assert abs(score-d['index'])<1e-12
   st=r['samples'][1]['states'][1:];energies=[sum(v*v for v in b['v']) for b in st];total=sum(energies)
   es=sum(energies[k] for k in [4,7,8])/total;maxEnergyError=max(maxEnergyError,abs(es-d['interiorShare']));assert abs(es-d['interiorShare'])<1e-12
   gap=statistics.mean(min(math.dist(st[k]['p'],b['p']) for j,b in enumerate(st) if k!=j)-2*R for k in [4,7,8])*1000;maxGapError=max(maxGapError,abs(gap-d['internalGapMM']));assert abs(gap-d['internalGapMM'])<1e-9
   assert r['duration']>=r['t0']+.005
   for e in r['contacts']:
    if e['kind']!='ball':firstSurface=min(firstSurface,e['t'])
assert n==2400 and firstSurface>.02
oldSeeds={r['seed'] for r in json.loads((ROOT/'output/rack-center-mechanism-20261026/racks.json').read_text())};newSeeds={r['seed'] for r in protocol['racks']};assert not oldSeeds&newSeeds and len(newSeeds)==200
# Recompiled default must exactly reproduce all prior forward/reverse control records.
audit=json.loads((OUT/'preflight/baseline-audit.json').read_text());old=json.loads((ROOT/'output/rack-center-order-control-20261026/raw.json').read_text());assert len(audit)==len(old)==24
for a,b in zip(audit,old):
 for field in ['rack','cue','direction','power','status','board','samples','contacts']:assert a[field]==b[field]
# Preserve source modifications exactly; the production caller copy is identical.
binding=json.loads((OUT/'source-binding.json').read_text())
assert all(sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
assert binding['changes']['EventDrivenEngine.swift']['originalSHA']==binding['changes']['EventDrivenEngine.swift']['researchSHA']
closure=json.loads((OUT/'closure.json').read_text());assert closure['success'] and closure['shutdownExitCode']==0 and all(w['exitCode']==0 for w in closure['workers'])
replays=[]
for p in OUT.glob('worker-*/replays.json'):replays+=json.loads(p.read_text())
assert len(replays)==12 and all(x['passed'] for x in replays)
tie=[]
for e in [250,10,1]:
 for order in ['forward','reverse']:
  a=f'{e}um_1e-07_{order}';b=f'{e}um_1e-12_{order}'
  tie.append(dict(epsilonUM=e,order=order,exactBoards=sum(rows[r['rackID'],a]['board']==rows[r['rackID'],b]['board'] for r in protocol['racks']),exact5ms=sum(rows[r['rackID'],a]['samples'][1]==rows[r['rackID'],b]['samples'][1] for r in protocol['racks']),passFlips=sum(lookup[r['rackID'],a]['success']!=lookup[r['rackID'],b]['success'] for r in protocol['racks'])))
result=dict(passed=True,records=n,baselineReplays=24,newVariantReplays=12,freshSeeds=200,scalarScoreAnd5msMetrics=True,maxEnergyShareError=maxEnergyError,maxGapMMError=maxGapError,earliestOtherSurfaceMS=firstSurface*1000,productionSourceUnchanged=True,tieEffects=tie,closure=True,rawHashes={p.name:sha(p) for p in OUT.glob('raw-*.jsonl.gz')})
(OUT/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
