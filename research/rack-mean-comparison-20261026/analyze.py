from pathlib import Path
import json,math,statistics,hashlib,gzip
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-mean-comparison-20261026'
folders=['rack-center-mechanism-20261026','rack-contact-factorial-20261026','rack-collision-counterfactual-20261026']
sources={x:ROOT/'output'/x for x in folders}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for folder in sources.values():
 binding=json.loads((folder/'source-binding.json').read_text())
 assert all(sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
old=json.loads((sources[folders[0]]/'derived.json').read_text())['rows'];factor=json.loads((sources[folders[1]]/'derived.json').read_text());counter=json.loads((sources[folders[2]]/'derived.json').read_text());groups={}
for r in factor+counter:groups.setdefault(r['key'],[]).append(r)
for group in groups.values():group.sort(key=lambda r:r['rackID']);assert len(group)==200
baseline=groups['250um_1e-07_forward'];ids=[r['rackID'] for r in baseline];assert all([r['rackID'] for r in v]==ids for v in groups.values())
assert not {r['id'] for r in old}&set(ids)
allbase=[r['index'] for r in old]+[r['index'] for r in baseline];assert len(allbase)==2200
rng=np.random.default_rng(202610260901);resamples=rng.integers(0,200,(20000,200))
def stats(vals):
 a=np.array(vals);mean=float(np.mean(a));assert abs(mean-statistics.fmean(vals))<1e-12
 return dict(n=len(vals),mean=mean,median=float(np.median(a)),sd=float(np.std(a,ddof=1)),p10=float(np.quantile(a,.1)),p90=float(np.quantile(a,.9)),meanSE=float(np.std(a,ddof=1)/np.sqrt(len(a))))
def compare(a,b):
 a=np.array(a);b=np.array(b);delta=a-b;boot=delta[resamples].mean(1)
 return dict(meanDelta=float(delta.mean()),relativeMeanChange=float(a.mean()/b.mean()-1),paired95CI=[float(v) for v in np.quantile(boot,[.025,.975])],family95CI=[float(v) for v in np.quantile(boot,[.05/19/2,1-.05/19/2])],improved=int(sum(delta>0)),worse=int(sum(delta<0)),exactSame=int(sum(delta==0)),pairedMedianDelta=float(np.median(delta)),p10Delta=float(np.quantile(delta,.1)),p90Delta=float(np.quantile(delta,.9)))
result={}
for k,g in groups.items():
 vals=[r['index'] for r in g];s=stats(vals);s['vsProduction']=compare(vals,[r['index'] for r in baseline]);result[k]=s
# Mechanism-specific comparisons retain exact same tolerance and registration.
mechanisms={}
for k,g in groups.items():
 if not k.startswith(('current_','narrow_')):continue
 original=('250um_1e-07_' if k.startswith('current') else '1um_1e-12_')+('reverse' if k.endswith('reverse') else 'forward')
 mechanisms[k]=dict(reference=original,**compare([r['index'] for r in g],[r['index'] for r in groups[original]]))
# Full raw scalar re-evaluation, independently from prior matrix-derived averages.
cal=json.loads((sources[folders[0]]/'calibration.json').read_text());L=cal['domain']['length'];count=0;checks={}
for name,folder in sources.items():
 if name==folders[0]:lookup={r['id']:r['index'] for r in old}
 else:lookup={(r['rackID'],r['key']):r['index'] for r in (factor if name==folders[1] else counter)}
 n=0
 for p in folder.glob('raw-*.jsonl.gz'):
  with gzip.open(p,'rt') as f:
   for line in f:
    r=json.loads(line);i=r['input'];assert r['status']=='settled'
    q=[v for name,v in r['board'].items() if name!='cueBall']
    score=statistics.fmean(min(math.dist(a,b)*L for j,b in enumerate(q) if j!=k) for k,a in enumerate(q))/cal['reference'][str(len(q))]['expectedMeanM']
    if name==folders[0]:key=i['rackID']
    elif name==folders[1]:key=(i['rackID'],f"{i['contactEpsilon']*1e6:g}um_{i['tieEpsilon']:g}_{'reverse' if i['reverseRegistration'] else 'forward'}")
    else:key=(i['rackID'],f"{i['tag']}_{'reverse' if i['reverseRegistration'] else 'forward'}")
    assert abs(score-lookup[key])<1e-12,(name,key,score);n+=1
 checks[name]=n;count+=n
assert count==6000
summary=dict(primary='Mean of existing calibrated dispersion score, greater is more spread; keep score formula unchanged. Threshold1.20 secondary only.',populationScope='Native simulation of production source, center cue at L/4,Z0, aim actual apex, power9.75, spin0; not telemetry or all gameplay.',productionBaseline2200=stats(allbase),productionOld2000=stats([r['index'] for r in old]),pairedBaseline200=stats([r['index'] for r in baseline]),comparisons=result,mechanismContrasts=mechanisms,method='200 paired rack units, 20000 paired bootstrap; individual95 and familywise95 Bonferroni19. Exploratory re-analysis of existing data, not fresh confirmatory validation.',verification=dict(rawScalarRecalculations=checks,total=6000,allSettled=True,productionHashesMatch=True),sourceHashes={str((folder/'derived.json').relative_to(ROOT)):sha(folder/'derived.json') for folder in sources.values()})
(OUT/'analysis.json').write_text(json.dumps(summary,indent=2))
print('BASE',summary['productionBaseline2200']);print('PAIRED',summary['pairedBaseline200'])
for k,s in result.items():print(k,s['mean'],s['vsProduction'])
print('MECHANISMS',mechanisms)
