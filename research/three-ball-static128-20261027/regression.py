"""Check the revised static selector against the prior five fixed-region pass sets."""
import json,time
from concurrent.futures import ProcessPoolExecutor
import run as B

def main():
 start=time.monotonic();old=B.ROOT/'output/three-ball-placement-pilot-20261026';parent=B.ROOT/'output/three-ball-middle-filter-20261027'
 f=json.loads((parent/'filter.json').read_text());samples=[]
 for fs in f['samples']:
  raw=json.loads((old/f"sample-{fs['number']}.json").read_text());s=raw['sample'];s['stops']=[dict(rank=b['rank'],routeID=b['parameter']['id'],pocket=b['pocket2'],position=b['result']['stop']) for b in raw['baselines']]
  s['candidates']=[dict(c,nativePlacementLegal=raw['candidates'][c['id']]['nativePlacementLegal']) for c in fs['positions']];samples.append(s)
 results=[B.process(s) for s in samples]
 evidence=[]
 for r,fs in zip(results,f['samples']):
  for g in r['groups']:
   oldgroup=next(g0 for g0 in f['groups'] if g0['sample']==r['sample']['number'] and g0['pocket']==g['pocket'])
   expected=[c['candidate'] for c in oldgroup['results'] if c['status']=='bounded_pass'];actual=[c['candidate'] for c in g['checks'] if c['status']=='bounded_pass'];assert actual==expected
  expected={c['id'] for c in fs['positions'] if c['status']=='region_pass'}
  actual={c['candidate'] for g in r['groups'] for c in g['checks'] if c['status']=='bounded_pass'};assert actual==expected
  evidence.append(dict(sample=r['sample']['number'],positions=len(actual),perPocketPassIDsUnchanged=True))
 B.write(B.OUT/'five-region-regression.json',dict(passed=True,samples=evidence,seconds=time.monotonic()-start,excludedFrom128Benchmark=True,noShotReplay=True))
 print(evidence)
if __name__=='__main__':main()
